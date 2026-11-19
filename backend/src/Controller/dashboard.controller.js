import ApiResponse from "../Utils/Apiresponse.js";
import QuestionModel from "../Models/form_data.model.js";
import CorrectiveActionModel from "../Models/corrective_action.model.js";
import { mineScope } from "../Utils/mine_scope.js";
import { summarize } from "../Services/dashboard.js";

// GET /dashboard/summary?days=30  (admins) -> totals, per-mine, per-shift, daily trend
const get_summary = async (req, res) => {
  try {
    const days = Math.min(Math.max(Number(req.query.days) || 30, 1), 365);
    const since = new Date(Date.now() - days * 86400e3);
    const scope = await mineScope(req);
    const [inspections, actions] = await Promise.all([
      QuestionModel.find({ ...scope, completed: true, date: { $gte: since } })
        .select("mine_name shift date checklistData.answer")
        .lean(),
      CorrectiveActionModel.find({ ...scope, status: "open" }).select("mine_name status dueAt").lean(),
    ]);
    return res.status(200).json(ApiResponse.success({ days, ...summarize(inspections, actions) }));
  } catch (error) {
    return res.status(500).json(ApiResponse.error(error.message, 500));
  }
};

export { get_summary };
