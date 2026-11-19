import ApiResponse from "../Utils/Apiresponse.js";
import AlertModel from "../Models/alert.model.js";
import { mineScope } from "../Utils/mine_scope.js";

// GET /alerts -> latest alerts with per-user `read` flag
const list_alerts = async (req, res) => {
  try {
    const query = await mineScope(req);
    const items = await AlertModel.find(query).sort({ createdAt: -1 }).limit(100).lean();
    const uid = String(req.user._id);
    const data = items.map(({ readBy = [], ...a }) => ({
      ...a,
      read: readBy.some((r) => String(r) === uid),
    }));
    return res.status(200).json(ApiResponse.success(data));
  } catch (error) {
    return res.status(500).json(ApiResponse.error(error.message, 500));
  }
};

// POST /alerts { mine_name, type: ppe|aqm|other, severity, title, message } (raised from the app, e.g. PPE/AQM flags)
const create_alert = async (req, res) => {
  try {
    const { mine_name, type, severity = "high", title, message } = req.body ?? {};
    if (!mine_name || !title) {
      return res.status(400).json(ApiResponse.error("mine_name and title are required", 400));
    }
    if (!["ppe", "aqm", "other"].includes(type)) {
      return res.status(400).json(ApiResponse.error("type must be ppe, aqm or other", 400));
    }
    if (!["medium", "high", "critical"].includes(severity)) {
      return res.status(400).json(ApiResponse.error("invalid severity", 400));
    }
    const alert = await AlertModel.create({
      mine_name,
      type,
      severity,
      title: String(title).slice(0, 200),
      message: String(message ?? "").slice(0, 2000),
      createdBy: req.user._id,
    });
    return res.status(201).json(ApiResponse.success(alert, "Alert raised", 201));
  } catch (error) {
    return res.status(500).json(ApiResponse.error(error.message, 500));
  }
};

// POST /alerts/read { ids: [...] } (omit ids = mark all in scope read)
const mark_read = async (req, res) => {
  try {
    const query = await mineScope(req);
    if (Array.isArray(req.body?.ids)) query._id = { $in: req.body.ids };
    await AlertModel.updateMany(query, { $addToSet: { readBy: req.user._id } });
    return res.status(200).json(ApiResponse.success(null, "Marked read"));
  } catch (error) {
    return res.status(500).json(ApiResponse.error(error.message, 500));
  }
};

export { list_alerts, create_alert, mark_read };
