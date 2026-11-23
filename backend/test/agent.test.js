import { test } from "node:test";
import assert from "node:assert/strict";
import { nextShift, ruleSeverity, nonCompliantItems } from "../src/Services/shift_agent.js";
import { summarize } from "../src/Services/dashboard.js";
import { parseJsonReply } from "../src/Utils/llm.js";

test("nextShift wraps shift 3 to next day's shift 1", () => {
  assert.equal(nextShift(1, "2026-11-10").toShift, 2);
  const r = nextShift(3, "2026-11-10T10:00:00Z");
  assert.equal(r.toShift, 1);
  assert.equal(r.date.toISOString().slice(0, 10), "2026-11-11");
});

test("ruleSeverity floors gas/fire to critical", () => {
  assert.equal(ruleSeverity("Methane level above limit"), "critical");
  assert.equal(ruleSeverity("Crack on bench edge"), "high");
  assert.equal(ruleSeverity("Signboard faded"), "medium");
});

test("nonCompliantItems picks only NO answers", () => {
  const items = nonCompliantItems([{ answer: "NO" }, { answer: "yes" }, { answer: "no " }, { answer: "NA" }, {}]);
  assert.equal(items.length, 2);
});

test("summarize computes compliance per mine/shift and overdue actions", () => {
  const ins = [
    { mine_name: "A", shift: 1, date: "2026-11-09", checklistData: [{ answer: "YES" }, { answer: "NO" }] },
    { mine_name: "A", shift: 2, date: "2026-11-10", checklistData: [{ answer: "YES" }, { answer: "NA" }] },
    { mine_name: "B", shift: 1, date: "2026-11-10", checklistData: [{ answer: "NO" }] },
  ];
  const now = new Date("2026-11-10T12:00:00Z");
  const acts = [
    { mine_name: "B", status: "open", dueAt: "2026-11-10T00:00:00Z" },
    { mine_name: "A", status: "open", dueAt: "2026-11-12T00:00:00Z" },
  ];
  const s = summarize(ins, acts, now);
  assert.equal(s.totals.inspections, 3);
  assert.equal(s.totals.compliance, 50); // 2 YES / 4 YES+NO
  assert.equal(s.totals.overdueActions, 1);
  assert.equal(s.mines[0].mine_name, "B"); // worst first
  assert.equal(s.mines[0].compliance, 0);
  assert.equal(s.shifts.find((x) => x.shift === 2).compliance, 100);
  assert.equal(s.trend.length, 2);
});

test("parseJsonReply tolerates code fences and prose", () => {
  assert.deepEqual(parseJsonReply('Sure:\n```json\n{"a":1}\n```'), { a: 1 });
  assert.equal(parseJsonReply("no json"), null);
});

import { scoreHealth } from "../src/Services/health_manager.js";

test("health: clean readings are Low", () => {
  const r = scoreHealth({ aqm: { "PM2.5 (µg/m³)": "30", "CO (ppm)": "5" }, ppe: { "PPE Compliance (%)": "100" }, workers: [{ name: "A", heartRate: "80", spo2: "98" }] });
  assert.equal(r.level, "Low");
  assert.equal(r.findings.length, 0);
});

test("health: methane over limit is at least Critical floor (75)", () => {
  const r = scoreHealth({ aqm: { "Methane (%)": "1.2", "PM2.5 (µg/m³)": "20" } });
  assert.ok(r.score >= 75);
  assert.equal(r.level, "Critical");
  assert.equal(r.findings[0].parameter, "Methane");
});

test("health: low PPE and one low-SpO2 worker raise score; missing gases reported", () => {
  const r = scoreHealth({ aqm: { "PM2.5 (µg/m³)": "60" }, ppe: { "PPE Compliance (%)": "60" }, workers: [{ name: "B", heartRate: "90", spo2: "88" }] });
  assert.ok(r.score >= 50, `score ${r.score}`);
  assert.equal(r.flaggedWorkers, 1);
  assert.ok(r.missing.includes("CO not measured"));
});

test("health: many moderate exceedances stay High, not Critical", () => {
  const r = scoreHealth({ aqm: { "PM2.5 (µg/m³)": "140", "Temperature (°C)": "37" }, ppe: { "PPE Compliance (%)": "67" }, workers: [{ name: "S", heartRate: "146", spo2: "89" }] });
  assert.equal(r.level, "High");
});

import { selfCheck, predictGrade } from "../src/ml/heating_model.js";

test("ML: Node runtime matches scikit-learn probabilities", () => {
  for (const err of selfCheck()) assert.ok(err < 1e-6, `max abs diff ${err}`);
});

test("ML: higher CO / O2 deficit gives higher grade; Shapley sums to prediction", () => {
  const low = predictGrade({ co_ppm: 2, co2_ppm: 600 });
  const high = predictGrade({ co_ppm: 900, co2_ppm: 9000, o2_pct: 14 });
  assert.ok(high.expected_grade > low.expected_grade);
  const sum = Object.values(high.contributions).reduce((a, b) => a + b, 0);
  assert.ok(Math.abs(high.baseline_grade + sum - high.expected_grade) < 0.02);
});

import { safetyRules, trend, assessReading, baselineIndex } from "../src/Services/risk_monitor.js";

test("risk: rule engine floors grade from coal temperature, C2H4 and CO", () => {
  assert.equal(Math.max(...safetyRules({ coal_temp_c: 125 }).map((a) => a.floor_grade)), 4);
  assert.ok(safetyRules({ c2h4_ppm: 3 }).some((a) => a.rule === "ethylene_detected"));
  assert.ok(safetyRules({ co_ppm: 150 }).some((a) => a.rule === "co_action_level_high"));
  assert.equal(safetyRules({ coal_temp_c: 30, co_ppm: 5 }).length, 0);
});

test("risk: trend slope per hour and 6 h projection", () => {
  const t0 = Date.UTC(2026, 10, 17, 0);
  const h = [0, 1, 2, 3].map((i) => ({ taken_at: new Date(t0 + i * 3600e3), co_ppm: 10 + 20 * i }));
  const tr = trend(h, "co_ppm");
  assert.equal(tr.slope_per_h, 20);
  assert.equal(tr.projected, 70 + 120);
  assert.equal(trend(h.slice(0, 2), "co_ppm"), null); // too few points
});

test("risk: final grade is never below the rule-engine floor; rising CO raises forecast", () => {
  const t0 = Date.UTC(2026, 10, 17, 0);
  const hist = [0, 1, 2, 3].map((i) => ({ taken_at: new Date(t0 + i * 3600e3), co_ppm: 20 + 15 * i }));
  const a = assessReading({ coal_grade: "G7", fines_pct: 15 }, { coal_temp_c: 105, co_ppm: 65, co2_ppm: 2000 }, hist);
  assert.ok(a.grade >= 3, `grade ${a.grade}`);
  assert.ok(a.safety_alerts.some((x) => x.rule === "co_rising"));
  assert.ok(a.forecast.projected_values.co_ppm > 65);
  assert.equal(baselineIndex({ coal_temp_c: 38, humidity_pct: 13, o2_pct: 20.9, co_ppm: 140, fines_pct: 15, coal_grade: "G7" }), 41.1);
});

import { explainAssessment } from "../src/Services/risk_monitor.js";

test("risk: reported safety alerts are exactly the rule engine's alerts (no duplicates)", async () => {
  const saved = process.env.LLM_API_KEY;
  delete process.env.LLM_API_KEY; // fallback path, no network
  const a = assessReading({ coal_grade: "G7", fines_pct: 15, environment: "surface_stockpile" }, { coal_temp_c: 71, co_ppm: 60, co2_ppm: 2400 }, []);
  const { explanation } = await explainAssessment({ environment: "surface_stockpile", zone: "Z", mine_name: "M" }, a);
  assert.deepEqual(explanation.active_safety_alerts, a.safety_alerts.map((x) => x.message));
  assert.deepEqual(explanation.data_quality_warnings, a.data_quality);
  process.env.LLM_API_KEY = saved;
});

test("toSensorMap: ppb -> ppm, negative gas dropped, first duplicate wins", async () => {
  const { toSensorMap } = await import("../src/Controller/aqm.controller.js");
  const m = toSensorMap([
    { sensorid: 33, sensorname: "CO(ppb)", sensorvalue: 656, unit: "ppb" },
    { sensorid: 27, sensorname: "H2S(ppm)", sensorvalue: -27.566, unit: "ppm" },
    { sensorid: 11, sensorname: "Temp(cel)", sensorvalue: 38, unit: "°C" },
    { sensorid: 104, sensorname: "Temp(cel)", sensorvalue: 29.8, unit: "°C" },
  ]);
  assert.deepEqual(m["CO(ppm)"], { id: 33, value: 0.656, unit: "ppm" });
  assert.equal(m["H2S(ppm)"], undefined);
  assert.equal(m["Temp(cel)"].value, 38);
});
