import { chatJSON } from "../Utils/llm.js";
import { predictGrade, MODEL_INFO } from "../ml/heating_model.js";
import { SITE_PROCEDURES } from "./site_procedures.js";
import { RiskMonitorModel, RiskReadingModel, RiskAssessmentModel } from "../Models/risk_monitor.model.js";
import AlertModel from "../Models/alert.model.js";
import { aqiGet, toSensorMap } from "../Controller/aqm.controller.js";
import { track, setAgentStatus } from "./agent_registry.js";

export const LEVELS = ["Safe", "Low", "Moderate", "High", "Severe", "Critical"];
// Coal temperature grade bands, Pei et al. 2024 (Fire 7:107, Table 2).
const TEMP_BANDS = [
  { min: 230, grade: 5, severity: "critical" },
  { min: 120, grade: 4, severity: "severe" },
  { min: 100, grade: 3, severity: "high" },
  { min: 60, grade: 2, severity: "warning" },
];
// Site CO action levels (ppm). Defaults follow the Longgu field rows in Zhang & Chen 2025 (Table 2): ~100-130 ppm
// labelled High, ~190-230 Severe. They are NOT regulatory limits; set the mine's own TARP values via env.
const CO_HIGH = Number(process.env.RISK_CO_HIGH_PPM || 100);
const CO_SEVERE = Number(process.env.RISK_CO_SEVERE_PPM || 190);
const CO_RISE_PPM_PER_H = 10;
const TEMP_RISE_C_PER_H = 2;
const STALE_MIN = 30;

const has = (v) => v !== null && v !== undefined && Number.isFinite(Number(v));

/** The app's original Risk Analytics heuristic (risk_analysis_screen.dart), kept as the baseline index. */
export const baselineIndex = ({ coal_temp_c, humidity_pct, o2_pct, co_ppm, fines_pct = 15, coal_grade = "G7" }) => {
  if (!has(coal_temp_c)) return null;
  const gw = { G1: 0.05, G2: 0.08, G3: 0.1, G4: 0.18, G5: 0.22, G6: 0.26, G7: 0.34, G8: 0.38, G9: 0.42, G10: 0.58, G11: 0.64, G12: 0.7, G13: 0.85, G14: 1 }[coal_grade] ?? 0.5;
  const c = (v) => Math.min(1, Math.max(0, v));
  const s = gw * 35 + c((coal_temp_c - 10) / 50) * 20 + c((100 - (has(humidity_pct) ? humidity_pct : 50)) / 100) * 15 +
    c((has(co_ppm) ? co_ppm : 0) / 500) * 15 + c((21 - (has(o2_pct) ? o2_pct : 20.9)) / 21) * 10 + c(fines_pct / 100) * 5;
  return Math.round(Math.min(100, s) * 10) / 10;
};

/** Least-squares trend of `key` over readings (taken_at, value) -> slope per hour + 6 h projection. */
export const trend = (history, key, horizonH = 6) => {
  const pts = history.filter((r) => has(r[key])).map((r) => [new Date(r.taken_at).getTime() / 3.6e6, Number(r[key])]);
  if (pts.length < 3) return null;
  const n = pts.length;
  const mx = pts.reduce((a, p) => a + p[0], 0) / n;
  const my = pts.reduce((a, p) => a + p[1], 0) / n;
  const sxx = pts.reduce((a, p) => a + (p[0] - mx) ** 2, 0);
  if (sxx === 0) return null;
  const slope = pts.reduce((a, p) => a + (p[0] - mx) * (p[1] - my), 0) / sxx;
  const lastT = Math.max(...pts.map((p) => p[0]));
  const ssTot = pts.reduce((a, p) => a + (p[1] - my) ** 2, 0);
  const ssRes = pts.reduce((a, p) => a + (p[1] - (my + slope * (p[0] - mx))) ** 2, 0);
  return {
    slope_per_h: Math.round(slope * 100) / 100,
    projected: Math.round((my + slope * (lastT + horizonH - mx)) * 10) / 10,
    horizon_h: horizonH,
    points: n,
    r2: ssTot > 0 ? Math.round((1 - ssRes / ssTot) * 100) / 100 : null,
  };
};

/** Independent safety rule engine. Its alerts can only raise the level, never lower it. */
export const safetyRules = (r, trends = {}) => {
  const alerts = [];
  if (has(r.coal_temp_c)) {
    const band = TEMP_BANDS.find((b) => r.coal_temp_c >= b.min);
    if (band) alerts.push({ rule: "coal_temperature_band", severity: band.severity, floor_grade: band.grade, message: `Coal temperature ${r.coal_temp_c} °C is in hazard grade ${band.grade} band (≥ ${band.min} °C).` });
  }
  if (has(r.c2h4_ppm) && r.c2h4_ppm > 0.5) {
    alerts.push({ rule: "ethylene_detected", severity: "high", floor_grade: 3, message: `C2H4 detected (${r.c2h4_ppm} ppm): indicates advanced coal oxidation / pyrolysis.` });
  }
  if (has(r.co_ppm) && r.co_ppm >= CO_SEVERE) {
    alerts.push({ rule: "co_action_level_severe", severity: "severe", floor_grade: 4, message: `CO ${r.co_ppm} ppm ≥ site severe action level ${CO_SEVERE} ppm.` });
  } else if (has(r.co_ppm) && r.co_ppm >= CO_HIGH) {
    alerts.push({ rule: "co_action_level_high", severity: "high", floor_grade: 3, message: `CO ${r.co_ppm} ppm ≥ site high action level ${CO_HIGH} ppm.` });
  }
  if (trends.co_ppm && trends.co_ppm.slope_per_h >= CO_RISE_PPM_PER_H) {
    alerts.push({ rule: "co_rising", severity: "warning", floor_grade: 2, message: `CO rising ${trends.co_ppm.slope_per_h} ppm/h over ${trends.co_ppm.points} readings.` });
  }
  if (trends.coal_temp_c && trends.coal_temp_c.slope_per_h >= TEMP_RISE_C_PER_H) {
    alerts.push({ rule: "coal_temperature_rising", severity: "warning", floor_grade: 2, message: `Coal temperature rising ${trends.coal_temp_c.slope_per_h} °C/h.` });
  }
  return alerts;
};

export const dataQuality = (r, now = new Date()) => {
  const w = [];
  if (!has(r.coal_temp_c)) w.push("No coal temperature reading: grade is estimated from gases only.");
  if (!has(r.co_ppm)) w.push("CO not measured: the strongest heating indicator is unavailable.");
  if (!has(r.o2_pct)) w.push("O2 not measured: Graham's ratio (CO/ΔO2) cannot be computed.");
  if (!has(r.c2h4_ppm)) w.push("C2H4 not measured: advanced-stage (pyrolysis) signal unavailable.");
  if (r.aqm_taken_at && now - new Date(r.aqm_taken_at) > STALE_MIN * 60e3) w.push(`AQM reading is older than ${STALE_MIN} minutes (device may be offline).`);
  if (r.manual_taken_at && now - new Date(r.manual_taken_at) > 12 * 3600e3) w.push("Latest manual coal temperature is older than 12 hours.");
  return w;
};

/** Deterministic assessment: ML grade + safety rules + forecast (no LLM). */
export const assessReading = (monitor, current, history = []) => {
  const ml = predictGrade(current);
  const trends = { co_ppm: trend(history, "co_ppm"), coal_temp_c: trend(history, "coal_temp_c") };
  const alerts = safetyRules(current, trends);
  const floor = Math.max(0, ...alerts.map((a) => a.floor_grade));
  const grade = Math.max(ml.grade, floor);

  let forecast = null;
  if (trends.co_ppm || trends.coal_temp_c) {
    const projected = {
      ...current,
      co_ppm: trends.co_ppm ? Math.max(0, trends.co_ppm.projected) : current.co_ppm,
      coal_temp_c: trends.coal_temp_c ? trends.coal_temp_c.projected : current.coal_temp_c,
    };
    const pg = Math.max(predictGrade(projected).grade, Math.max(0, ...safetyRules(projected).map((a) => a.floor_grade)));
    forecast = { horizon_h: 6, trends, projected_values: { co_ppm: projected.co_ppm, coal_temp_c: projected.coal_temp_c }, projected_grade: pg, projected_level: LEVELS[pg] };
  }

  return {
    measured: current,
    baseline_index: baselineIndex({ ...current, fines_pct: monitor.fines_pct, coal_grade: monitor.coal_grade }),
    ml: { ...ml, model: { name: MODEL_INFO.name, version: MODEL_INFO.version, validation: MODEL_INFO.training.validation_leave_one_coal_out_gas_only } },
    forecast,
    safety_alerts: alerts,
    data_quality: dataQuality(current),
    grade,
    level: LEVELS[grade],
    risk_index: Math.round(Math.max((ml.expected_grade / 5) * 100, (floor / 5) * 100)),
  };
};

const SYSTEM = `# System Role: Coal Mine Spontaneous Heating Risk Explanation Assistant
You are an industrial safety decision-support assistant for coal mine spontaneous heating and fire risk.
You explain structured results produced by (a) a validated machine-learning heating-grade model, (b) an independently maintained safety rule engine and (c) a trend forecast. You do NOT calculate, round or modify any score, grade or level.

## Input (JSON)
environment, location, measured (sensor values with units and timestamps), data_quality, baseline_index (legacy heuristic, 0-100),
ml (grade 0-5, confidence, class probabilities, features_used, SHAP-style contributions to the expected grade, model validation),
forecast (6 h trend projection), safety_alerts (rule engine), final (grade, level, risk_index), approved_procedures [{id, text}].

## Grades
0 Safe (<50 °C), 1 Low (50-60), 2 Moderate (60-100), 3 High (100-120), 4 Severe (120-230), 5 Critical (≥230): coal-temperature bands of the hazard scale.

## Responsibilities
1. Explain the current risk assessment and what the final level means here.
2. Name the most important contributing factors using the SHAP contributions. They are measured against baseline_grade (the model's average prediction when no data is available): a negative value means "lower than that average", NOT "safe".
3. Explain abnormal values and trends; keep current observations separate from forecast values.
4. List missing or unreliable measurements and how they limit confidence.
5. Summarise model uncertainty (confidence, probability spread, validation accuracy).
6. Recommend actions ONLY from approved_procedures, citing their id; order by urgency.
7. State when human inspection or expert review is required, and why.

## Environment awareness
Distinguish underground goaf, active underground workings and surface coal stockpiles. Identical readings do not mean the same thing in different environments (e.g. surface air dilutes gases, so low ambient CO at a stockpile does not rule out a hot spot inside the pile).

## Safety constraints
- Never change the supplied score, grade or level; never downgrade or omit a safety alert.
- Never infer an area is safe from an absence of abnormal readings.
- Never treat an anomaly or model output as proof of spontaneous combustion; it indicates risk that needs checking.
- Never invent regulatory thresholds, readings or procedures; never fabricate missing values.
- Never recommend ignoring an alert.
- Use concise technical language. Write all text in LANGUAGE.

## Output (JSON only)
{"summary": string,
 "risk_interpretation": string,
 "measured_facts": [string],
 "model_inferences": [string],
 "unknowns": [string],
 "main_contributing_factors": [{"factor": string, "effect": "raises"|"lowers", "evidence": string}],
 "sensor_trends": [string],
 "forecast_interpretation": string,
 "data_quality_warnings": [string],
 "active_safety_alerts": [string],
 "recommended_actions": [{"procedure_id": string, "action": string, "priority": "immediate"|"this shift"|"routine"}],
 "human_review_required": boolean,
 "human_review_reason": string}`;

/** LLM explanation of a deterministic assessment, post-checked against the safety constraints. */
export const explainAssessment = async (monitor, a, language = "English") => {
  const procedures = SITE_PROCEDURES[monitor.environment] ?? SITE_PROCEDURES.surface_stockpile;
  const ai = await chatJSON(
    SYSTEM.replace("LANGUAGE", language),
    {
      environment: monitor.environment,
      location: { mine: monitor.mine_name, zone: monitor.zone, coal_grade: monitor.coal_grade },
      measured: a.measured,
      data_quality: a.data_quality,
      baseline_index: a.baseline_index,
      ml: { grade: a.ml.grade, confidence: a.ml.confidence, probabilities: a.ml.probabilities, expected_grade: a.ml.expected_grade, baseline_grade: a.ml.baseline_grade, features_used: a.ml.features_used, contributions: a.ml.contributions, validation: a.ml.model.validation },
      forecast: a.forecast,
      safety_alerts: a.safety_alerts,
      final: { grade: a.grade, level: a.level, risk_index: a.risk_index },
      approved_procedures: procedures,
    },
    { maxTokens: 2500 },
  );
  const ids = new Set(procedures.map((p) => p.id));
  const fallback = {
    summary: `${monitor.zone}: ${a.level} (grade ${a.grade}, risk index ${a.risk_index}).`,
    risk_interpretation: "",
    recommended_actions: a.grade >= 3 ? procedures.slice(0, 2).map((p) => ({ procedure_id: p.id, action: p.text, priority: "immediate" })) : [],
  };
  const out = ai && typeof ai.summary === "string" ? ai : fallback;
  // Post-checks: the rule engine's own alert texts are authoritative (never reworded or dropped);
  // actions only from approved procedures; review forced when needed.
  out.active_safety_alerts = a.safety_alerts.map((x) => x.message);
  out.recommended_actions = (out.recommended_actions ?? []).filter((x) => ids.has(x?.procedure_id));
  out.data_quality_warnings = a.data_quality; // system-detected gaps are authoritative (avoid reworded duplicates)
  const mustReview = a.grade >= 3 || a.safety_alerts.length > 0 || a.ml.confidence < 0.5;
  out.human_review_required = Boolean(out.human_review_required) || mustReview;
  return { explanation: out, aiGenerated: out !== fallback };
};

// ── Agent loop ────────────────────────────────────────────────────────────────

const AQM_FIELDS = [
  [/^co2/, "co2_ppm"],
  [/^co$/, "co_ppm"],
  [/^temp$/, "ambient_temp_c"],
  [/^hum$/, "humidity_pct"], // not "Humi B"
  [/^pm25/, "pm25"],
];

/** Pull the latest reading of every configured aqi.in device. */
const pollAqm = async (monitors) => {
  const withDevice = monitors.filter((m) => m.device_serial);
  if (!withDevice.length || !process.env.AQI_EMAIL) return 0;
  const json = await aqiGet("GetAllUserDevices");
  let added = 0;
  for (const m of withDevice) {
    const d = (json.data ?? []).find((x) => x.serialNo === m.device_serial);
    if (!d) continue;
    const reading = { monitor: m._id, source: "aqm", taken_at: new Date() };
    for (const [name, s] of Object.entries(toSensorMap(d.realtime))) {
      const key = name.toLowerCase().replace(/\s/g, "").split("(")[0];
      if (/fer/i.test(name)) continue; // Fahrenheit twin
      const f = AQM_FIELDS.find(([re]) => re.test(key))?.[1];
      // First sensor wins: "Temp(cel)" comes before the uncalibrated "Temp(orignal)".
      if (f && reading[f] === undefined && Number.isFinite(Number(s.value))) reading[f] = Number(s.value);
    }
    await RiskReadingModel.create(reading);
    added++;
  }
  return added;
};

/** Current picture for a monitor: latest AQM gases (≤ 30 min) + latest manual values (≤ 12 h). */
const currentReading = async (monitor) => {
  const recent = await RiskReadingModel.find({ monitor: monitor._id, taken_at: { $gte: new Date(Date.now() - 24 * 3600e3) } })
    .sort({ taken_at: -1 })
    .lean();
  if (!recent.length) return null;
  const aqm = recent.find((r) => r.source === "aqm");
  const manual = recent.find((r) => r.source === "manual");
  const cur = {};
  for (const src of [aqm, manual]) {
    if (!src) continue;
    for (const k of ["coal_temp_c", "co_ppm", "co2_ppm", "o2_pct", "c2h4_ppm", "ambient_temp_c", "humidity_pct", "pm25"]) {
      if (has(src[k]) && !has(cur[k])) cur[k] = src[k];
    }
  }
  // Manual readings override AQM when newer (e.g. a probe CO reading at the pile face).
  if (manual && (!aqm || manual.taken_at > aqm.taken_at)) {
    for (const k of ["co_ppm", "co2_ppm", "o2_pct", "c2h4_ppm"]) if (has(manual[k])) cur[k] = manual[k];
  }
  cur.aqm_taken_at = aqm?.taken_at;
  cur.manual_taken_at = manual?.taken_at;
  return { current: cur, history: [...recent].reverse() };
};

/** Assess one monitor; explain with the LLM when the level changed, the risk is High+, or the last explanation is old. */
export const assessMonitor = async (monitor, { language = "English", force = false } = {}) => {
  const snap = await currentReading(monitor);
  if (!snap) return null;
  const a = assessReading(monitor, snap.current, snap.history);
  const prev = await RiskAssessmentModel.findOne({ monitor: monitor._id }).sort({ createdAt: -1 }).lean();
  const stale = !prev || Date.now() - new Date(prev.createdAt) > 3 * 3600e3;
  let explanation = prev?.explanation;
  let aiGenerated = prev?.aiGenerated ?? false;
  if (force || stale || !prev || prev.grade !== a.grade || a.grade >= 3) {
    ({ explanation, aiGenerated } = await explainAssessment(monitor, a, language));
  }
  const doc = await RiskAssessmentModel.create({
    monitor: monitor._id, mine_name: monitor.mine_name, zone: monitor.zone, environment: monitor.environment,
    ...a, explanation, aiGenerated,
  });
  if (a.grade >= 3 && (!prev || prev.grade < a.grade)) {
    await AlertModel.create({
      mine_name: monitor.mine_name,
      type: "risk_monitor",
      severity: a.grade >= 4 ? "critical" : "high",
      title: `Heating risk ${a.level} at ${monitor.zone} (grade ${a.grade})`,
      message: `${explanation?.summary ?? ""} ${(explanation?.recommended_actions ?? [])[0]?.action ?? ""}`.trim(),
      refId: doc._id,
    });
  }
  return doc;
};

/** One monitoring cycle across all active monitors (runs on a timer from index.js). */
export const runRiskMonitorCycle = () =>
  track(
    "risk_monitor",
    async () => {
      const monitors = await RiskMonitorModel.find({ active: true }).lean();
      if (!monitors.length) {
        setAgentStatus("risk_monitor", "idle", "No monitored zones configured yet.");
        return { monitors: 0 };
      }
      let polled = 0;
      try {
        polled = await pollAqm(monitors);
      } catch (e) {
        console.error("Risk monitor AQM poll failed:", e.message);
      }
      let assessed = 0;
      let high = 0;
      for (const m of monitors) {
        const doc = await assessMonitor(m);
        if (doc) {
          assessed++;
          if (doc.grade >= 3) high++;
        }
      }
      return { monitors: monitors.length, polled, assessed, high };
    },
    (r) => (r.monitors ? `${r.assessed}/${r.monitors} zones assessed, ${r.polled} AQM readings, ${r.high} at High or above` : "No monitored zones configured yet."),
  );
