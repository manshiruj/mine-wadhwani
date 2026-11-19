import ApiResponse from "../Utils/Apiresponse.js";
import HandoverModel from "../Models/handover.model.js";
import QuestionModel from "../Models/form_data.model.js";
import { mineScope } from "../Utils/mine_scope.js";
import { runShiftAgent } from "../Services/shift_agent.js";
import { languageFromReq } from "../Utils/llm.js";

// GET /handover?pending=true&mine_name=  -> latest handovers (pending = not yet signed off)
const list_handovers = async (req, res) => {
  try {
    const query = await mineScope(req);
    if (req.query.pending === "true") query.acknowledged = false;
    const items = await HandoverModel.find(query)
      .select("-ackSignature")
      .sort({ createdAt: -1 })
      .limit(Math.min(Number(req.query.limit) || 30, 100))
      .lean();
    return res.status(200).json(ApiResponse.success(items));
  } catch (error) {
    return res.status(500).json(ApiResponse.error(error.message, 500));
  }
};

// POST /handover/:id/acknowledge { name, signature (base64 png), note }
const acknowledge_handover = async (req, res) => {
  try {
    const { name, signature, note } = req.body ?? {};
    if (!signature || typeof signature !== "string") {
      return res.status(400).json(ApiResponse.error("signature is required", 400));
    }
    const h = await HandoverModel.findById(req.params.id);
    if (!h) return res.status(404).json(ApiResponse.error("Handover not found", 404));
    if (h.acknowledged) return res.status(409).json(ApiResponse.error("Handover already signed off", 409));
    if (String(h.fromUser) === String(req.user._id)) {
      return res.status(403).json(ApiResponse.error("Outgoing supervisor cannot sign off their own handover", 403));
    }
    Object.assign(h, {
      acknowledged: true,
      ackBy: req.user._id,
      ackName: name || req.user.name,
      ackSignature: signature,
      ackNote: note || "",
      ackAt: new Date(),
    });
    await h.save();
    const out = h.toObject();
    delete out.ackSignature;
    return res.status(200).json(ApiResponse.success(out, "Handover signed off"));
  } catch (error) {
    return res.status(500).json(ApiResponse.error(error.message, 500));
  }
};

// POST /handover/regenerate/:inspectionId -> re-run the agent (e.g. after AI key was added)
const regenerate_handover = async (req, res) => {
  try {
    const inspection = await QuestionModel.findById(req.params.inspectionId);
    if (!inspection?.completed) {
      return res.status(404).json(ApiResponse.error("Completed inspection not found", 404));
    }
    const { handover } = await runShiftAgent(inspection, req.user, languageFromReq(req));
    return res.status(200).json(ApiResponse.success(handover));
  } catch (error) {
    return res.status(500).json(ApiResponse.error(error.message, 500));
  }
};

export { list_handovers, acknowledge_handover, regenerate_handover };
