import CorrectiveActionModel from "../Models/corrective_action.model.js";
import HandoverModel from "../Models/handover.model.js";
import AlertModel from "../Models/alert.model.js";

// Fixed knowledge the assistant needs about this app (kept in sync with the Flutter code).
export const APP_KNOWLEDGE = `
ABOUT THE APP (Wadhwani / AIMSURE mine digital inspection):
- Supervisors run shift inspections (3 shifts/day) for areas like Haul Road and Stockpile. Answers are YES (compliant), NO (non-compliant) or NA.
- Every NO answer automatically becomes a Corrective Action with severity, owner and due time: critical 4h, high 12h, medium 24h, low 72h.
  Gas/methane/CO/H2S/fire/explosion/collapse/inrush/flood/electrocution/brake failure words force "critical"; slope/bench/crack/berm/dust/PPE/blast/water/gradient force at least "high".
  Overdue open actions are escalated to the mine admin every 15 minutes and raise an alert.
- After a submit, an AI shift handover note is written for the next shift; the incoming supervisor signs it off (the outgoing one cannot).
- Health assessment: AQM readings (PM2.5, CO, CO2, H2S, methane, temperature, noise) and drone PPE detection (Roboflow model: Hardhat / Safety Vest / Mask and their NO- classes). Flags raise alerts.
- Admin dashboard: compliance % = YES / (YES + NO), per mine, per shift and daily trend.

RISK ANALYTICS (spontaneous heating risk index, 0-100) as computed in the app:
  score = 35*gradeWeight + 20*tNorm + 15*rhNorm + 15*coNorm + 10*o2Norm + 5*finesNorm   (clamped 0-100)
  gradeWeight by coal grade: G1 0.05, G2 0.08, G3 0.10, G4 0.18, G5 0.22, G6 0.26, G7 0.34, G8 0.38, G9 0.42, G10 0.58, G11 0.64, G12 0.70, G13 0.85, G14 1.00 (lower-rank coal heats more easily)
  tNorm = (T°C - 10)/50, rhNorm = (100 - RH%)/100 (drier = riskier), coNorm = CO/500 (the screen labels CO in ppb), o2Norm = (21 - O2%)/21, finesNorm = fines%/100; each clamped 0-1.
  Bands: <17 Low, 17-34 Low to Moderate, 34-50 Moderate, 50-67 Moderately High, 67-84 High, >=84 Very High.
  It is a weighted heuristic index for screening, not a calibrated physical model.
`;

// Live, scoped data snapshot for the assistant (small: keeps free-tier token limits).
export const liveContext = async (scope) => {
  const [actions, handovers, alerts] = await Promise.all([
    CorrectiveActionModel.find({ ...scope, status: "open" })
      .sort({ dueAt: 1 })
      .limit(15)
      .select("mine_name area severity questionText issue action owner dueAt escalated")
      .lean(),
    HandoverModel.find(scope)
      .sort({ createdAt: -1 })
      .limit(3)
      .select("mine_name area fromShift toShift summary critical acknowledged createdAt")
      .lean(),
    AlertModel.find(scope).sort({ createdAt: -1 }).limit(5).select("mine_name type severity title createdAt").lean(),
  ]);
  const now = new Date();
  return JSON.stringify({
    open_actions: actions.map((a) => ({ ...a, _id: undefined, overdue: a.dueAt && a.dueAt < now })),
    recent_handovers: handovers.map((h) => ({ ...h, _id: undefined })),
    recent_alerts: alerts.map((a) => ({ ...a, _id: undefined })),
  });
};
