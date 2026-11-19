import ApiResponse from "../Utils/Apiresponse.js";
import HealthRecordModel from "../Models/health_record.model.js";
import AlertModel from "../Models/alert.model.js";
import { runHealthManager } from "../Services/health_manager.js";
import { track } from "../Services/agent_registry.js";
import { languageFromReq } from "../Utils/llm.js";
import { mineScope } from "../Utils/mine_scope.js";

// POST /health/assess { mine_name, area, zone, shift, aqm: {label: value}, ppe: {label: value}, workers: [{name, heartRate, spo2}], persist }
const assess = async (req, res) => {
  try {
    const { mine_name, area, zone, shift, aqm = {}, ppe = {}, workers = [], persist = false } = req.body ?? {};
    if (!mine_name) return res.status(400).json(ApiResponse.error("mine_name is required", 400));
    if (typeof aqm !== "object" || typeof ppe !== "object" || !Array.isArray(workers)) {
      return res.status(400).json(ApiResponse.error("aqm and ppe must be objects, workers an array", 400));
    }
    const input = { mine_name, area, zone, shift, aqm, ppe, workers: workers.slice(0, 50) };
    const result = await track("health", () => runHealthManager(input, languageFromReq(req)), (r) => `${zone || area || mine_name}: ${r.level} (${r.score})`);

    if (persist) {
      const rec = await HealthRecordModel.create({ ...result, inputs: input, mine_name, area, zone, shift, createdBy: req.user._id });
      result.id = rec._id;
      if (result.score >= 50) {
        await AlertModel.create({
          mine_name,
          type: "health",
          severity: result.level === "Critical" ? "critical" : "high",
          title: `Health risk ${result.level} (${result.score}/100) — ${zone || area || ""}`.trim(),
          message: `${result.advice.summary} ${result.advice.actions[0]?.action ?? ""}`.trim(),
          refId: rec._id,
          createdBy: req.user._id,
        });
      }
    }
    return res.status(200).json(ApiResponse.success(result));
  } catch (error) {
    return res.status(500).json(ApiResponse.error(error.message, 500));
  }
};

// GET /health/records?mine_name=  -> latest assessments
const list_records = async (req, res) => {
  try {
    const items = await HealthRecordModel.find(await mineScope(req)).sort({ createdAt: -1 }).limit(50).lean();
    return res.status(200).json(ApiResponse.success(items));
  } catch (error) {
    return res.status(500).json(ApiResponse.error(error.message, 500));
  }
};

export { assess, list_records };
