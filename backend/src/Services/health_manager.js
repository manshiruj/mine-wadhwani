import { chatJSON } from "../Utils/llm.js";

// Limits mirror the app's HealthThresholds (frontend/lib/data/models/health_assessment/health_assessment_model.dart).
export const LIMITS = {
  pm25: { max: 100, unit: "µg/m³", label: "PM2.5" },
  co: { max: 50, unit: "ppm", label: "CO", critical: true },
  co2: { max: 5000, unit: "ppm", label: "CO2" },
  h2s: { max: 5, unit: "ppm", label: "H2S", critical: true },
  methane: { max: 0.75, unit: "%", label: "Methane", critical: true },
  temperature: { max: 35, unit: "°C", label: "Temperature" },
  noise: { max: 90, unit: "dB", label: "Noise" },
};
const HR = { min: 50, max: 140 };
const SPO2_MIN = 90;
const PPE_MIN = 80;

// App field label -> parameter key ("PM2.5 (µg/m³)" -> pm25, "CO2 (ppm)" -> co2, "Methane (%)" -> methane ...)
const AQM_KEYS = [
  [/^pm\s*2\.?5/i, "pm25"],
  [/^co2/i, "co2"],
  [/^co\b/i, "co"],
  [/^h2s/i, "h2s"],
  [/^(methane|ch4)/i, "methane"],
  [/^temp/i, "temperature"],
  [/^noise/i, "noise"],
];
const num = (v) => {
  const n = parseFloat(String(v ?? "").replace(/[^0-9.\-]/g, ""));
  return Number.isFinite(n) ? n : null;
};

// Exceedance ratio -> 0..1 sub-score: <=60% of limit = 0, at limit = 0.7, >=150% = 1.
const ratioScore = (r) => (r <= 0.6 ? 0 : r <= 1 ? ((r - 0.6) / 0.4) * 0.7 : Math.min(1, 0.7 + ((r - 1) / 0.5) * 0.3));

export const levelOf = (score) => (score >= 75 ? "Critical" : score >= 50 ? "High" : score >= 25 ? "Moderate" : "Low");

/** Deterministic health risk score (0-100) from AQM, drone PPE and smartwatch inputs. */
export const scoreHealth = ({ aqm = {}, ppe = {}, workers = [] } = {}) => {
  const findings = [];
  const missing = [];
  let criticalHit = false;

  // Air quality
  const air = {};
  for (const [label, raw] of Object.entries(aqm)) {
    const key = AQM_KEYS.find(([re]) => re.test(label.trim()))?.[1];
    const v = num(raw);
    if (key && v !== null) air[key] = v;
  }
  let airScore = 0;
  for (const [key, v] of Object.entries(air)) {
    const lim = LIMITS[key];
    const s = ratioScore(v / lim.max);
    airScore = Math.max(airScore, s);
    if (v > lim.max) {
      findings.push({ source: "AQM", parameter: lim.label, value: v, unit: lim.unit, limit: lim.max, severity: lim.critical ? "critical" : "high" });
      if (lim.critical) criticalHit = true;
    }
  }
  if (Object.keys(aqm).length && !Object.keys(air).length) missing.push("AQM values could not be read");
  for (const k of ["co", "methane", "h2s"]) if (Object.keys(air).length && air[k] === undefined) missing.push(`${LIMITS[k].label} not measured`);

  // PPE (drone)
  let ppeScore = 0;
  const compliance = num(ppe["PPE Compliance (%)"] ?? ppe.compliance);
  if (compliance !== null) {
    ppeScore = Math.max(0, Math.min(1, (100 - compliance) / 50)); // 50% compliance = 1
    if (compliance < PPE_MIN) findings.push({ source: "PPE", parameter: "PPE compliance", value: compliance, unit: "%", limit: PPE_MIN, severity: "high" });
  }
  const hazards = String(ppe["Hazard Tags"] ?? ppe.hazards ?? "").trim();
  if (hazards) {
    ppeScore = Math.max(ppeScore, 0.5);
    findings.push({ source: "PPE", parameter: "Hazards seen", value: hazards, severity: "high" });
  }

  // Workers (smartwatch)
  let workerScore = 0;
  let flaggedWorkers = 0;
  for (const w of workers) {
    const hr = num(w.heartRate);
    const spo2 = num(w.spo2);
    let wScore = 0;
    if (hr !== null && (hr < HR.min || hr > HR.max)) {
      wScore = Math.max(wScore, 0.6);
      findings.push({ source: "Smartwatch", parameter: `${w.name || "Worker"} heart rate`, value: hr, unit: "bpm", limit: `${HR.min}-${HR.max}`, severity: "high" });
    }
    if (spo2 !== null && spo2 < SPO2_MIN) {
      const severe = spo2 < 85;
      wScore = Math.max(wScore, severe ? 1 : 0.75);
      if (severe) criticalHit = true;
      findings.push({ source: "Smartwatch", parameter: `${w.name || "Worker"} SpO2`, value: spo2, unit: "%", limit: SPO2_MIN, severity: severe ? "critical" : "high" });
    }
    if (wScore > 0) flaggedWorkers++;
    workerScore = Math.max(workerScore, wScore);
  }

  // Weighted blend, then floors so one dangerous reading is never averaged away.
  const parts = [
    [airScore, 0.45, Object.keys(air).length > 0],
    [ppeScore, 0.25, compliance !== null || !!hazards],
    [workerScore, 0.3, workers.length > 0],
  ].filter(([, , present]) => present);
  const wsum = parts.reduce((a, [, w]) => a + w, 0) || 1;
  let score = (parts.reduce((a, [s, w]) => a + s * w, 0) / wsum) * 100;
  const maxPart = Math.max(0, ...parts.map(([s]) => s));
  score = Math.max(score, maxPart * 70); // worst single input sets a floor
  // "Critical" is reserved for critical hazards (toxic/flammable gas over limit, SpO2 < 85%).
  score = criticalHit ? Math.max(score, 75) : Math.min(score, 74);
  score = Math.round(Math.min(100, score));

  return {
    score,
    level: levelOf(score),
    components: {
      air: Math.round(airScore * 100),
      ppe: Math.round(ppeScore * 100),
      workers: Math.round(workerScore * 100),
    },
    findings,
    missing,
    flaggedWorkers,
    inputs: { air, ppeCompliance: compliance, hazards: hazards || null, workerCount: workers.length },
  };
};

const SYSTEM = `# Role: Mine Worker Health & Exposure Advisor
You support shift supervisors in Indian mines. You receive a health risk assessment that was ALREADY computed by a deterministic rule engine from AQM (air quality), drone PPE detection and smartwatch (heart rate, SpO2) readings.

## Rules
- Never change the supplied score or level, and never downgrade a finding.
- Do not infer an area is safe because a parameter was not measured; list missing measurements.
- Do not invent limits; use only the limits in the input.
- For critical findings (toxic/flammable gas over limit, SpO2 below 85%), the first action is to withdraw people from the area, ventilate, and inform the mine manager per the mine's emergency procedure.
- Recommend withdrawing or evacuating workers ONLY when the level is Critical. For High, recommend controls (ventilation, dust suppression, rest/medical check for flagged workers, PPE enforcement) and informing the Safety Officer.
- Name who should act (Shift Supervisor, Mine Manager, Safety Officer, Medical Officer, Ventilation Officer).
- Write all text in LANGUAGE.

## Output JSON
{"summary": string (2-3 sentences),
 "key_risks": [string] (max 4, most serious first),
 "actions": [{"action": string, "owner": string, "urgency": "immediate"|"this shift"|"routine"}] (max 6),
 "worker_advice": [string] (max 3, plain advice for the workers),
 "data_gaps": [string],
 "human_review_required": boolean}`;

const fallbackAdvice = (r) => ({
  summary: `Health risk ${r.level} (${r.score}/100) from ${r.findings.length} flagged reading(s).`,
  key_risks: r.findings.slice(0, 4).map((f) => `${f.parameter}: ${f.value}${f.unit ? " " + f.unit : ""}${f.limit !== undefined ? ` (limit ${f.limit})` : ""}`),
  actions: r.findings.some((f) => f.severity === "critical")
    ? [{ action: "Withdraw workers from the area, improve ventilation and inform the mine manager.", owner: "Shift Supervisor", urgency: "immediate" }]
    : r.findings.length
      ? [{ action: "Review the flagged readings and correct them before work continues.", owner: "Shift Supervisor", urgency: "this shift" }]
      : [],
  worker_advice: [],
  data_gaps: r.missing,
  human_review_required: r.score >= 50,
});

/** Health Manager agent: deterministic score + LLM explanation/suggestions (never alters the score). */
export const runHealthManager = async (input, language = "English") => {
  const r = scoreHealth(input);
  const ai = await chatJSON(SYSTEM.replace("LANGUAGE", language), {
    location: { mine: input.mine_name, area: input.area, zone: input.zone, shift: input.shift },
    assessment: { score: r.score, level: r.level, components: r.components, findings: r.findings, missing_measurements: r.missing },
    raw_inputs: { aqm: input.aqm, ppe: input.ppe, workers: input.workers },
  });
  const advice = ai && Array.isArray(ai.actions) ? ai : fallbackAdvice(r);
  return {
    ...r,
    advice: {
      summary: String(advice.summary ?? ""),
      key_risks: (advice.key_risks ?? []).slice(0, 4).map(String),
      actions: (advice.actions ?? []).slice(0, 6),
      worker_advice: (advice.worker_advice ?? []).slice(0, 3).map(String),
      data_gaps: (advice.data_gaps ?? r.missing).map(String),
      human_review_required: Boolean(advice.human_review_required) || r.score >= 50,
    },
    aiGenerated: Boolean(ai && Array.isArray(ai.actions)),
  };
};
