# Coal spontaneous-heating grade model

Used by the Risk Monitor agent (`src/Services/risk_monitor.js`) through `src/ml/heating_model.js`.

## Data
No public raw dataset for coal spontaneous heating exists (checked: PMC6698773, Appl. Sci. 15:3756, Fire 7:107, PMC8526955 — the last is methane sensor data, not heating).

- `data/lab_rows.csv` — 76 real temperature-programmed oxidation rows typed from the papers:
  Guo et al. 2019, *Data in Brief* 25:104304, Tables 1-4 (lignite, anthracite, 2 long-flame coals, 30-170 °C) and
  Zhang & Chen 2025, *Appl. Sci.* 15:3756, Table A1 (one coal, 30-180 °C).
- `data/field_validation.csv` — 10 labelled field rows, Zhang & Chen 2025 Table 2 (Longgu mine). Sanity check only.
- Labels: hazard grade from coal temperature, Pei et al. 2024, *Fire* 7:107, Table 2 (50 / 60 / 100 / 120 / 230 °C).

## Method
Synthetic rows are interpolated along each coal's measured gas-temperature curve with lognormal sensor noise, random air dilution of absolute gas values (ratios are dilution-invariant) and random sensor dropout, so the model works when some sensors are missing. Model: scikit-learn `HistGradientBoostingClassifier`, exported to JSON and evaluated in Node (checked to 1e-6 against scikit-learn). Contributions are exact Shapley values with "feature missing" as the baseline.

## Validation (gas readings only, coal temperature hidden, leave one coal out)
54 % exact grade, 84 % within one grade. Field rows: Safe → grade 0, Low → 0-2, High → 2, Severe → 3 (correct ordering). No training data above 180 °C, so grade 5 comes from the rule engine only.

## Limitations
Lab concentrations come from 1 kg of coal in 30-120 mL/min of air; ambient mine air is far more diluted, so absolute gas levels transfer poorly (ratio features and coal temperature transfer best). Treat outputs as screening, confirm with inspection, and retrain on the mine's own readings.

## Retrain
```bash
python3 -m venv ml/.venv && ml/.venv/bin/pip install -r ml/requirements.txt
ml/.venv/bin/python ml/train.py   # writes src/ml/heating_model.json
npm test                          # includes the Node vs scikit-learn self-check
```
