import { chatJSON } from "../Utils/llm.js";
import HandoverModel from "../Models/handover.model.js";
import CorrectiveActionModel from "../Models/corrective_action.model.js";
import AlertModel from "../Models/alert.model.js";

const DUE_HOURS = { critical: 4, high: 12, medium: 24, low: 72 };
const SEVERITIES = Object.keys(DUE_HOURS);
// Rule-based floor so critical hazards are caught even when the AI is off or wrong.
const CRITICAL_WORDS = /gas|methane|ch4|\bco\b|h2s|fire|explos|collapse|slope fail|landslide|inrush|flood|electrocut|live wire|brake fail/i;
const HIGH_WORDS = /gradient|speed|slope|bench|crack|edge|berm|parapet|brake|ventilat|dust|ppe|helmet|guard|blast|overhang|water/i;

export const nextShift = (shift, date) => {
  const toShift = (Number(shift) % 3) + 1;
  const d = new Date(date);
  if (toShift === 1) d.setDate(d.getDate() + 1);
  return { toShift, date: d };
};

export const ruleSeverity = (text = "") =>
  CRITICAL_WORDS.test(text) ? "critical" : HIGH_WORDS.test(text) ? "high" : "medium";

const maxSeverity = (a, b) =>
  SEVERITIES.indexOf(a) < SEVERITIES.indexOf(b) ? a : b; // list is ordered critical -> low

export const nonCompliantItems = (checklistData = []) =>
  checklistData.filter((q) => String(q.answer || "").trim().toUpperCase() === "NO");

const SYSTEM = `You are a mine safety shift-handover assistant for Indian mines (DGMS regulations: Mines Act 1952, MMR 1961, CMR 2017).
Given a completed shift inspection, write a concise handover for the incoming supervisor and triage each non-compliant item.
JSON shape:
{"summary": string (3-5 sentences),
 "critical": [string] (most urgent hazards, max 5),
 "watch_next": [string] (what the next shift must check, max 5),
 "items": [{"code": string, "severity": "critical"|"high"|"medium"|"low", "action": string (concrete corrective step), "owner": string (role, e.g. "Shift Supervisor", "Mine Manager", "Safety Officer", "Electrical Engineer")}]}
Use only facts from the input. Write all text values in LANGUAGE.`;

// Runs after an inspection is submitted (completed=true): creates corrective actions, alerts and the handover.
export const runShiftAgent = async (inspection, user, language = "English") => {
  const items = nonCompliantItems(inspection.checklistData);
  const carried = await CorrectiveActionModel.find({
    mine_name: inspection.mine_name,
    status: "open",
    inspectionId: { $ne: inspection._id },
  })
    .sort({ dueAt: 1 })
    .limit(20)
    .lean();

  const ai = await chatJSON(SYSTEM.replace("LANGUAGE", language), {
    mine: inspection.mine_name,
    area: inspection.area,
    inspection_type: inspection.Inspection_type,
    shift: inspection.shift,
    questions_answered: inspection.checklistData.length,
    observations: inspection.observations,
    non_compliant: items.map((q) => ({
      code: q.questionCode,
      question: q.questionText,
      comment: q.comment,
      planned_action: q.action,
    })),
    open_actions_from_earlier_shifts: carried.map((a) => ({
      question: a.questionText,
      action: a.action,
      due: a.dueAt,
      overdue: a.dueAt && a.dueAt < new Date(),
    })),
  });
  const aiItems = new Map((ai?.items ?? []).map((i) => [String(i.code), i]));

  // Corrective actions (idempotent per inspection + question).
  const existing = new Set(
    (await CorrectiveActionModel.find({ inspectionId: inspection._id }).select("questionCode").lean()).map(
      (a) => a.questionCode,
    ),
  );
  const now = Date.now();
  const actions = [];
  for (const q of items) {
    const a = aiItems.get(String(q.questionCode)) ?? {};
    const rule = ruleSeverity(`${q.questionText} ${q.comment}`);
    const severity = SEVERITIES.includes(a.severity) ? maxSeverity(a.severity, rule) : rule;
    const doc = await CorrectiveActionModel.findOneAndUpdate(
      { inspectionId: inspection._id, questionCode: q.questionCode },
      {
        $setOnInsert: {
          mine_name: inspection.mine_name,
          area: inspection.area,
          Inspection_type: inspection.Inspection_type,
          shift: inspection.shift,
          questionText: q.questionText,
          issue: q.comment,
          action: q.action?.trim() || a.action || "Rectify the non-compliance and re-inspect.",
          severity,
          owner: a.owner || (severity === "critical" ? "Mine Manager" : "Shift Supervisor"),
          dueAt: new Date(now + DUE_HOURS[severity] * 3600e3),
          raisedBy: user?._id,
        },
      },
      { upsert: true, new: true },
    );
    actions.push(doc);
  }

  // Immediate alerts for critical/high findings.
  const urgent = actions.filter((a) => ["critical", "high"].includes(a.severity));
  const newUrgent = urgent.filter((a) => !existing.has(a.questionCode)); // re-runs must not re-alert
  if (newUrgent.length) {
    await AlertModel.insertMany(
      newUrgent.map((a) => ({
        mine_name: a.mine_name,
        type: "critical_finding",
        severity: a.severity === "critical" ? "critical" : "high",
        title: `${a.severity.toUpperCase()}: ${a.questionText?.slice(0, 80)}`,
        message: `${inspection.Inspection_type} · ${inspection.area} · Shift ${inspection.shift}. ${a.issue || ""} Action: ${a.action}. Due ${a.dueAt.toLocaleString("en-IN")}.`,
        refId: a._id,
        createdBy: user?._id,
      })),
    );
  }

  // Handover note (AI text, or a plain rule-based summary when AI is unavailable).
  const { toShift, date } = nextShift(inspection.shift, inspection.date);
  const openCount = carried.length + actions.length;
  const fallbackSummary = `Shift ${inspection.shift} ${inspection.Inspection_type} inspection at ${inspection.mine_name} (${inspection.area}): ${inspection.checklistData.length} items checked, ${items.length} non-compliant, ${openCount} corrective actions open.${inspection.observations ? ` Observations: ${inspection.observations}` : ""}`;
  const handover = await HandoverModel.findOneAndUpdate(
    { inspectionId: inspection._id },
    {
      $set: {
        mine_name: inspection.mine_name,
        area: inspection.area,
        Inspection_type: inspection.Inspection_type,
        date,
        fromShift: inspection.shift,
        toShift,
        fromUser: user?._id,
        fromName: user?.name,
        summary: ai?.summary || fallbackSummary,
        critical: ai?.critical?.length
          ? ai.critical.slice(0, 5)
          : urgent.slice(0, 5).map((a) => `${a.questionText} — ${a.issue || a.action}`),
        watchNext: ai?.watch_next?.length
          ? ai.watch_next.slice(0, 5)
          : carried
              .filter((a) => a.dueAt && a.dueAt < new Date())
              .slice(0, 5)
              .map((a) => `Overdue: ${a.action} (${a.questionText})`),
        openActionCount: openCount,
        language,
        aiGenerated: Boolean(ai),
      },
    },
    { upsert: true, new: true },
  );

  return { handover, actions };
};

// Escalate open actions past their due time (runs on an interval from index.js).
export const escalateOverdue = async () => {
  const overdue = await CorrectiveActionModel.find({
    status: "open",
    escalated: false,
    dueAt: { $lt: new Date() },
  }).limit(200);
  for (const a of overdue) {
    a.escalated = true;
    a.escalatedAt = new Date();
    await a.save();
    await AlertModel.create({
      mine_name: a.mine_name,
      type: "overdue_action",
      severity: a.severity === "critical" ? "critical" : "high",
      title: `Overdue action: ${a.questionText?.slice(0, 80)}`,
      message: `${a.action} — owner ${a.owner}, was due ${a.dueAt.toLocaleString("en-IN")}. Escalated to mine admin.`,
      refId: a._id,
    });
  }
  return overdue.length;
};
