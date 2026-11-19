import ApiResponse from "../Utils/Apiresponse.js";
import { RiskMonitorModel, RiskReadingModel, RiskAssessmentModel } from "../Models/risk_monitor.model.js";
import { assessMonitor } from "../Services/risk_monitor.js";
import { ENVIRONMENTS, SITE_PROCEDURES } from "../Services/site_procedures.js";
import { track } from "../Services/agent_registry.js";
import { languageFromReq } from "../Utils/llm.js";
import { mineScope } from "../Utils/mine_scope.js";
import { MODEL_INFO } from "../ml/heating_model.js";

const num = (v) => (v === "" || v === null || v === undefined ? undefined : Number(v));

// GET /risk-monitor/monitors -> zones with their latest assessment
const list_monitors = async (req, res) => {
  try {
    const monitors = await RiskMonitorModel.find({ ...(await mineScope(req)), active: true }).sort({ mine_name: 1, zone: 1 }).lean();
    const latest = await Promise.all(
      monitors.map((m) => RiskAssessmentModel.findOne({ monitor: m._id }).sort({ createdAt: -1 }).lean()),
    );
    return res.status(200).json(ApiResponse.success(monitors.map((m, i) => ({ ...m, latest: latest[i] }))));
  } catch (error) {
    return res.status(500).json(ApiResponse.error(error.message, 500));
  }
};

// POST /risk-monitor/monitors { mine_name, zone, environment, device_serial, coal_grade, fines_pct }  (create or update)
const upsert_monitor = async (req, res) => {
  try {
    const { mine_name, zone, environment = "surface_stockpile", device_serial, coal_grade = "G7", fines_pct = 15 } = req.body ?? {};
    if (!mine_name || !zone) return res.status(400).json(ApiResponse.error("mine_name and zone are required", 400));
    if (!ENVIRONMENTS.includes(environment)) return res.status(400).json(ApiResponse.error(`environment must be one of ${ENVIRONMENTS.join(", ")}`, 400));
    if (!/^G([1-9]|1[0-4])$/.test(coal_grade)) return res.status(400).json(ApiResponse.error("coal_grade must be G1..G14", 400));
    const m = await RiskMonitorModel.findOneAndUpdate(
      { mine_name, zone },
      { environment, device_serial: device_serial || undefined, coal_grade, fines_pct: Number(fines_pct), active: true },
      { upsert: true, new: true },
    );
    return res.status(200).json(ApiResponse.success(m));
  } catch (error) {
    return res.status(500).json(ApiResponse.error(error.message, 500));
  }
};

// POST /risk-monitor/monitors/:id/readings { coal_temp_c, co_ppm, co2_ppm, o2_pct, c2h4_ppm, note } -> runs the agent now
const add_reading = async (req, res) => {
  try {
    const m = await RiskMonitorModel.findById(req.params.id).lean();
    if (!m) return res.status(404).json(ApiResponse.error("Monitored zone not found", 404));
    const b = req.body ?? {};
    const vals = { coal_temp_c: num(b.coal_temp_c), co_ppm: num(b.co_ppm), co2_ppm: num(b.co2_ppm), o2_pct: num(b.o2_pct), c2h4_ppm: num(b.c2h4_ppm) };
    const bad = Object.entries(vals).filter(([, v]) => v !== undefined && !Number.isFinite(v));
    if (bad.length) return res.status(400).json(ApiResponse.error(`Not a number: ${bad.map(([k]) => k).join(", ")}`, 400));
    if (Object.values(vals).every((v) => v === undefined)) return res.status(400).json(ApiResponse.error("Enter at least one reading", 400));
    if (vals.o2_pct !== undefined && (vals.o2_pct < 0 || vals.o2_pct > 21)) return res.status(400).json(ApiResponse.error("o2_pct must be 0-21", 400));
    await RiskReadingModel.create({ monitor: m._id, source: "manual", ...vals, note: b.note, createdBy: req.user._id });
    const doc = await track("risk_monitor", () => assessMonitor(m, { language: languageFromReq(req), force: true }), (d) => `${m.zone}: ${d?.level}`);
    return res.status(201).json(ApiResponse.success(doc, "Reading saved and assessed", 201));
  } catch (error) {
    return res.status(500).json(ApiResponse.error(error.message, 500));
  }
};

// GET /risk-monitor/monitors/:id/history -> recent assessments (newest first)
const history = async (req, res) => {
  try {
    const items = await RiskAssessmentModel.find({ monitor: req.params.id })
      .sort({ createdAt: -1 })
      .limit(48)
      .select("createdAt grade level risk_index ml.expected_grade measured")
      .lean();
    return res.status(200).json(ApiResponse.success(items));
  } catch (error) {
    return res.status(500).json(ApiResponse.error(error.message, 500));
  }
};

// GET /risk-monitor/model -> model card (training data, validation, limitations) + procedures
const model_card = (req, res) =>
  res.status(200).json(ApiResponse.success({ ...MODEL_INFO, procedures: SITE_PROCEDURES }));

export { list_monitors, upsert_monitor, add_reading, history, model_card };
