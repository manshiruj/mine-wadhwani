import ApiResponse from "../Utils/Apiresponse.js";
import CorrectiveActionModel from "../Models/corrective_action.model.js";
import { mineScope } from "../Utils/mine_scope.js";

// GET /actions?status=open|closed&mine_name=
const list_actions = async (req, res) => {
  try {
    const query = await mineScope(req);
    if (["open", "closed"].includes(req.query.status)) query.status = req.query.status;
    const items = await CorrectiveActionModel.find(query)
      .sort({ status: -1, dueAt: 1 })
      .limit(200)
      .lean();
    return res.status(200).json(ApiResponse.success(items));
  } catch (error) {
    return res.status(500).json(ApiResponse.error(error.message, 500));
  }
};

// PATCH /actions/:id/close { note }
const close_action = async (req, res) => {
  try {
    const { note } = req.body ?? {};
    if (!note || !String(note).trim()) {
      return res.status(400).json(ApiResponse.error("A closing note describing the fix is required", 400));
    }
    const a = await CorrectiveActionModel.findById(req.params.id);
    if (!a) return res.status(404).json(ApiResponse.error("Action not found", 404));
    if (a.status === "closed") return res.status(409).json(ApiResponse.error("Action already closed", 409));
    Object.assign(a, {
      status: "closed",
      closedBy: req.user._id,
      closedName: req.user.name,
      closeNote: String(note).trim(),
      closedAt: new Date(),
    });
    await a.save();
    return res.status(200).json(ApiResponse.success(a, "Action closed"));
  } catch (error) {
    return res.status(500).json(ApiResponse.error(error.message, 500));
  }
};

export { list_actions, close_action };
