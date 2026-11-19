// Runtime for the gradient-boosted coal heating-grade model trained in ml/train.py (exported to heating_model.json).
import fs from "node:fs";

const MODEL = JSON.parse(fs.readFileSync(new URL("./heating_model.json", import.meta.url), "utf8"));
const AIR_O2 = 20.93;
export const FEATURES = MODEL.features;
export const MODEL_INFO = { name: MODEL.name, version: MODEL.version, training: MODEL.training };

/** Same features as ml/train.py -> features(). Missing inputs become NaN (the model handles them). */
export const featureVector = ({ coal_temp_c, co_ppm, co2_ppm, o2_pct, c2h4_ppm } = {}) => {
  const has = (v) => v !== null && v !== undefined && Number.isFinite(Number(v));
  const co = has(co_ppm) ? Number(co_ppm) : null;
  return [
    has(coal_temp_c) ? Number(coal_temp_c) : NaN,
    co !== null ? Math.log1p(Math.max(co, 0)) : NaN,
    co !== null && has(co2_ppm) && Number(co2_ppm) > 0 ? co / Number(co2_ppm) : NaN,
    co !== null && has(o2_pct) ? (100 * (co / 1e4)) / Math.max(AIR_O2 - Number(o2_pct), 0.05) : NaN,
    has(o2_pct) ? Math.max(AIR_O2 - Number(o2_pct), 0) : NaN,
    has(c2h4_ppm) ? (Number(c2h4_ppm) > 0.5 ? 1 : 0) : NaN,
  ];
};

const leafValue = (t, x) => {
  let i = 0;
  while (!t.leaf[i]) {
    const v = x[t.feature[i]];
    i = Number.isNaN(v) ? (t.missing_left[i] ? t.left[i] : t.right[i]) : v <= t.threshold[i] ? t.left[i] : t.right[i];
  }
  return t.value[i];
};

/** Class probabilities for grades MODEL.classes. */
export const predictProba = (x) => {
  const raw = [...MODEL.baseline];
  for (const perIter of MODEL.trees) perIter.forEach((t, k) => (raw[k] += leafValue(t, x)));
  const m = Math.max(...raw);
  const e = raw.map((r) => Math.exp(r - m));
  const s = e.reduce((a, b) => a + b, 0);
  return e.map((v) => v / s);
};

const expectedGrade = (p) => p.reduce((a, pk, k) => a + pk * MODEL.classes[k], 0);

/**
 * Exact Shapley values of each available feature on the expected grade,
 * using "feature missing" as the baseline (the model was trained with random sensor dropout).
 */
export const shapContributions = (x) => {
  const present = x.map((v, i) => (Number.isNaN(v) ? -1 : i)).filter((i) => i >= 0);
  const n = present.length;
  const value = (mask) => {
    const xs = x.map((v, i) => (present.includes(i) && mask & (1 << present.indexOf(i)) ? v : NaN));
    return expectedGrade(predictProba(xs));
  };
  const cache = new Map();
  const v = (mask) => (cache.has(mask) ? cache.get(mask) : (cache.set(mask, value(mask)), cache.get(mask)));
  const fact = (k) => (k <= 1 ? 1 : k * fact(k - 1));
  const out = {};
  present.forEach((fi, j) => {
    let phi = 0;
    for (let mask = 0; mask < 1 << n; mask++) {
      if (mask & (1 << j)) continue;
      const size = mask.toString(2).replace(/0/g, "").length;
      phi += ((fact(size) * fact(n - size - 1)) / fact(n)) * (v(mask | (1 << j)) - v(mask));
    }
    out[FEATURES[fi]] = Math.round(phi * 1000) / 1000;
  });
  return { baseline_grade: Math.round(v(0) * 100) / 100, contributions: out };
};

/** Model prediction for one reading. */
export const predictGrade = (reading) => {
  const x = featureVector(reading);
  const proba = predictProba(x);
  const k = proba.indexOf(Math.max(...proba));
  return {
    grade: MODEL.classes[k],
    confidence: Math.round(proba[k] * 1000) / 1000,
    expected_grade: Math.round(expectedGrade(proba) * 100) / 100,
    probabilities: Object.fromEntries(MODEL.classes.map((c, i) => [c, Math.round(proba[i] * 1000) / 1000])),
    features_used: FEATURES.filter((_, i) => !Number.isNaN(x[i])),
    ...shapContributions(x),
  };
};

export const selfCheck = () =>
  MODEL.self_check.map(({ x, proba }) => {
    const got = predictProba(x.map((v) => (v === null ? NaN : v)));
    return Math.max(...got.map((g, i) => Math.abs(g - proba[i])));
  });
