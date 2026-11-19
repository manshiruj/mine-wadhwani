"""Train the coal spontaneous-heating grade model used by the Risk Monitor agent.

Data (no public raw dataset exists, see ml/README.md):
  data/lab_rows.csv          76 real temperature-programmed oxidation rows (Guo et al. 2019 Tables 1-4,
                             Zhang & Chen 2025 Table A1): coal temperature vs O2, CO, CO2, C2H4.
  data/field_validation.csv  10 labelled field rows (Zhang & Chen 2025 Table 2, Longgu mine) - sanity check only.
Labels: hazard grade from coal temperature bands of Pei et al. 2024 (Fire 7:107, Table 2):
  0 <50 C, 1 50-60, 2 60-100, 3 100-120, 4 120-230, 5 >=230 (no lab rows above 180 C -> grade 5 is rule-engine only).
Training set: the real rows plus synthetic rows interpolated along each coal's measured curve, with sensor noise,
air dilution (absolute gases only; ratios are dilution-invariant) and random sensor dropout (missing features).

Run:  ml/.venv/bin/python ml/train.py      -> writes src/ml/heating_model.json
"""
import csv
import json
import math
import random
from datetime import date
from pathlib import Path

import numpy as np
from sklearn.ensemble import HistGradientBoostingClassifier

ROOT = Path(__file__).parent
OUT = ROOT.parent / "src" / "ml" / "heating_model.json"
FEATURES = ["coal_temp_c", "log_co", "co_co2", "graham", "o2_deficit", "c2h4_present"]
BANDS = [50, 60, 100, 120, 230]  # Pei et al. 2024, Table 2
AIR_O2 = 20.93
NAN = float("nan")
rng = random.Random(42)


def grade(temp_c):
    return sum(temp_c >= b for b in BANDS)


def features(temp_c=None, co_ppm=None, co2_ppm=None, o2_pct=None, c2h4_ppm=None):
    """Must match src/ml/heating_model.js -> featureVector()."""
    co_ok = co_ppm is not None
    return [
        temp_c if temp_c is not None else NAN,
        math.log1p(max(co_ppm, 0)) if co_ok else NAN,
        co_ppm / co2_ppm if co_ok and co2_ppm else NAN,
        100 * (co_ppm / 1e4) / max(AIR_O2 - o2_pct, 0.05) if co_ok and o2_pct is not None else NAN,
        max(AIR_O2 - o2_pct, 0) if o2_pct is not None else NAN,
        (1.0 if c2h4_ppm > 0.5 else 0.0) if c2h4_ppm is not None else NAN,
    ]


def load(path):
    with open(ROOT / path) as fh:
        return list(csv.DictReader(fh))


lab = load("data/lab_rows.csv")
curves = {}
for r in lab:
    curves.setdefault(r["coal"], []).append({k: float(v) for k, v in r.items() if k not in ("source", "coal")})
for c in curves.values():
    c.sort(key=lambda r: r["temp_c"])


def interp(curve, t, key, log=True):
    for a, b in zip(curve, curve[1:]):
        if a["temp_c"] <= t <= b["temp_c"]:
            w = (t - a["temp_c"]) / (b["temp_c"] - a["temp_c"])
            if log:
                return math.expm1(math.log1p(a[key]) * (1 - w) + math.log1p(b[key]) * w)
            return a[key] * (1 - w) + b[key] * w
    return curve[-1][key]


def synth(curve, n):
    X, y = [], []
    for _ in range(n):
        t = rng.uniform(curve[0]["temp_c"], curve[-1]["temp_c"])
        co = interp(curve, t, "co_ppm") * math.exp(rng.gauss(0, 0.2))
        co2 = interp(curve, t, "co2_ppm") * math.exp(rng.gauss(0, 0.2))
        o2 = interp(curve, t, "o2_pct", log=False)
        o2_def = max(AIR_O2 - o2, 0) * math.exp(rng.gauss(0, 0.1))
        c2h4 = interp(curve, t, "c2h4_ppm")
        # Mine air dilutes absolute concentrations (ratios unaffected): scale CO and O2 deficit together.
        d = math.exp(rng.uniform(math.log(0.02), 0)) if rng.random() < 0.6 else 1.0
        graham = 100 * (co / 1e4) / max(o2_def, 0.05)
        f = [t, math.log1p(co * d), co / co2, graham, o2_def * d, 1.0 if c2h4 > 0.5 else 0.0]
        # Sensor dropout: coal temperature often unknown; O2 / C2H4 rarely measured on surface monitors.
        drop = {0: 0.6, 1: 0.15, 2: 0.3, 3: 0.5, 4: 0.5, 5: 0.6}
        f = [NAN if rng.random() < drop[i] else v for i, v in enumerate(f)]
        if math.isnan(f[1]):  # no CO -> no CO-based ratios
            f[2] = f[3] = NAN
        X.append(f)
        y.append(grade(t))
    return X, y


def dataset(coals, n_per_coal=3000):
    X, y = [], []
    for name in coals:
        c = curves[name]
        sx, sy = synth(c, n_per_coal)
        X += sx
        y += sy
        for r in c:  # real rows: full features and gas-only
            X.append(features(r["temp_c"], r["co_ppm"], r["co2_ppm"], r["o2_pct"], r["c2h4_ppm"]))
            X.append(features(None, r["co_ppm"], r["co2_ppm"], r["o2_pct"], r["c2h4_ppm"]))
            y += [grade(r["temp_c"])] * 2
    return np.array(X, dtype=float), np.array(y)


def model():
    return HistGradientBoostingClassifier(max_iter=120, learning_rate=0.1, max_depth=4,
                                          min_samples_leaf=20, l2_regularization=1.0, random_state=0)


# ── Leave-one-coal-out validation on the REAL rows, gas only (coal temperature hidden) ──
loco = {}
for held in curves:
    X, y = dataset([c for c in curves if c != held])
    m = model().fit(X, y)
    rows = curves[held]
    Xt = np.array([features(None, r["co_ppm"], r["co2_ppm"], r["o2_pct"], r["c2h4_ppm"]) for r in rows])
    yt = np.array([grade(r["temp_c"]) for r in rows])
    p = m.predict(Xt)
    loco[held] = {"n": len(rows), "exact": float((p == yt).mean()), "within_one_grade": float((abs(p - yt) <= 1).mean())}
all_n = sum(v["n"] for v in loco.values())
summary = {
    "exact": sum(v["exact"] * v["n"] for v in loco.values()) / all_n,
    "within_one_grade": sum(v["within_one_grade"] * v["n"] for v in loco.values()) / all_n,
}

# ── Final model on all coals ──
X, y = dataset(list(curves))
m = model().fit(X, y)

# Field sanity check (Longgu mine, labelled by the paper's own clustering - different scale, ordering only).
field = load("data/field_validation.csv")
Xf = np.array([features(None, float(r["co_ppm"]), float(r["co2_ppm"]), float(r["o2_pct"]), float(r["c2h4_ppm"])) for r in field])
field_pred = [{"level": r["level"], "predicted_grade": int(g)} for r, g in zip(field, m.predict(Xf))]

# ── Export trees for the Node runtime ──
def export_tree(pred):
    n = pred.nodes
    return {
        "value": [float(v) for v in n["value"]],
        "feature": [int(v) for v in n["feature_idx"]],
        # JSON has no Infinity: an "always go left" split threshold becomes a huge finite number.
        "threshold": [float(v) if math.isfinite(v) else math.copysign(1e300, v) for v in n["num_threshold"]],
        "missing_left": [int(v) for v in n["missing_go_to_left"]],
        "left": [int(v) for v in n["left"]],
        "right": [int(v) for v in n["right"]],
        "leaf": [int(v) for v in n["is_leaf"]],
    }

samples = [
    features(None, 2, 600, None, None),
    features(None, 150, 2500, 17.5, 0),
    features(None, 900, 9000, 14, 0),
    features(None, 5000, 70000, 6, 25),
    features(85, None, None, None, None),
    features(None, None, 5000, None, None),
]
out = {
    "name": "coal_spontaneous_heating_grade",
    "version": date.today().isoformat(),
    "features": FEATURES,
    "classes": [int(c) for c in m.classes_],
    "grade_bands_c": BANDS,
    "baseline": [float(v) for v in np.ravel(m._baseline_prediction)],
    "trees": [[export_tree(p) for p in per_iter] for per_iter in m._predictors],
    "training": {
        "lab_rows": len(lab),
        "coals": list(curves),
        "synthetic_rows": len(y) - 2 * len(lab),
        "sources": [
            "Guo et al. 2019, Data in Brief 25:104304 (Tables 1-4)",
            "Zhang & Chen 2025, Appl. Sci. 15:3756 (Table A1; Table 2 used for sanity check)",
            "Pei et al. 2024, Fire 7:107 (grade temperature bands, Table 2)",
        ],
        "validation_leave_one_coal_out_gas_only": {"per_coal": loco, **summary},
        "field_sanity_check": field_pred,
        "limitations": "Lab-derived; ambient gas levels differ from lab. No training data above 180 C (grade 5 is rule-engine only). Retrain on site data when available.",
    },
    "self_check": [{"x": [None if math.isnan(v) else v for v in s], "proba": [float(v) for v in m.predict_proba(np.array([s]))[0]]} for s in samples],
}
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(json.dumps(out, allow_nan=False))
print(f"wrote {OUT} ({OUT.stat().st_size // 1024} KB)")
print("leave-one-coal-out (gas only):", {k: f"{v['exact']:.2f}/{v['within_one_grade']:.2f}" for k, v in loco.items()},
      f"overall exact {summary['exact']:.2f}, within one grade {summary['within_one_grade']:.2f}")
print("field sanity:", [(f['level'], f['predicted_grade']) for f in field_pred])
