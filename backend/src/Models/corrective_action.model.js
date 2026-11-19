import mongoose from "mongoose";

// One corrective action per non-compliant ("NO") checklist answer.
const CorrectiveActionSchema = new mongoose.Schema(
  {
    mine_name: { type: String, required: true },
    area: String,
    Inspection_type: String,
    shift: Number,
    inspectionId: { type: mongoose.Schema.Types.ObjectId, ref: "Question", required: true },
    questionCode: { type: String, required: true },
    questionText: String,
    issue: String, // supervisor's comment
    action: String, // what must be done (supervisor's or agent-suggested)
    severity: { type: String, enum: ["low", "medium", "high", "critical"], default: "medium" },
    owner: String, // role responsible, e.g. "Shift Supervisor", "Mine Manager"
    dueAt: Date,
    status: { type: String, enum: ["open", "closed"], default: "open" },
    raisedBy: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
    closedBy: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
    closedName: String,
    closeNote: String,
    closedAt: Date,
    escalated: { type: Boolean, default: false },
    escalatedAt: Date,
  },
  { timestamps: true },
);

CorrectiveActionSchema.index({ inspectionId: 1, questionCode: 1 }, { unique: true });
CorrectiveActionSchema.index({ mine_name: 1, status: 1, dueAt: 1 });

export const CorrectiveActionModel = mongoose.model("CorrectiveAction", CorrectiveActionSchema);
export default CorrectiveActionModel;
