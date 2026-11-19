// In-memory registry of the AI agents: what each does, how it is triggered, and its recent activity.
// Every agent run goes through track(), so GET /api/v1/agents shows them all working side by side.
const agents = new Map();

export const registerAgent = (id, { name, description, trigger }) => {
  if (!agents.has(id)) {
    agents.set(id, { id, name, description, trigger, runs: 0, errors: 0, running: 0, lastRunAt: null, lastStatus: "idle", lastSummary: "" });
  }
};

/** Run fn as agent `id`, recording timing, outcome and a one-line summary (summarize(result) -> string). */
export const track = async (id, fn, summarize = () => "") => {
  const a = agents.get(id);
  if (!a) return fn();
  a.running++;
  a.lastStatus = "running";
  const started = Date.now();
  try {
    const result = await fn();
    a.runs++;
    a.lastStatus = "ok";
    a.lastSummary = String(summarize(result) ?? "").slice(0, 200);
    return result;
  } catch (e) {
    a.errors++;
    a.lastStatus = "error";
    a.lastSummary = e.message.slice(0, 200);
    throw e;
  } finally {
    a.running--;
    a.lastRunAt = new Date();
    a.lastDurationMs = Date.now() - started;
  }
};

export const setAgentStatus = (id, status, summary = "") => {
  const a = agents.get(id);
  if (a) Object.assign(a, { lastStatus: status, lastSummary: summary });
};

export const listAgents = () => [...agents.values()].map((a) => ({ ...a }));

registerAgent("shift", { name: "Shift Agent", description: "On every submitted inspection: triages NO answers into corrective actions with owners and deadlines, raises alerts and writes the next-shift handover.", trigger: "event: inspection submitted" });
registerAgent("escalation", { name: "Escalation Agent", description: "Finds corrective actions past their deadline and escalates them to the mine admin.", trigger: "schedule: every 15 min" });
registerAgent("health", { name: "Health Manager", description: "Scores worker health risk from AQM, drone PPE and smartwatch readings and suggests actions.", trigger: "event: health assessment" });
registerAgent("risk_monitor", { name: "Risk Monitor", description: "Continuously reads the AQM device and manual coal temperatures, runs the ML heating-grade model, safety rules and a 6 h forecast, then explains the risk with recommendations from approved procedures.", trigger: "schedule: every 10 min + new reading" });
registerAgent("assistant", { name: "Safety Assistant", description: "Answers questions about inspections, risks, actions and DGMS rules using live mine data.", trigger: "on demand: chat" });
registerAgent("voice", { name: "Voice Fill Agent", description: "Turns spoken inspection notes (Hindi/English/Hinglish) into checklist answers.", trigger: "on demand: voice note" });
