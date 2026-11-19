import mongoose from "mongoose";

// Shift handover note: written by the agent when a shift's inspection is submitted,
// signed off by the incoming supervisor (audit trail: from -> to, both signatures).
const HandoverSchema = new mongoose.Schema(
  {
    mine_name: { type: String, required: true },
    area: String,
    Inspection_type: String,
    date: { type: Date, required: true },
    fromShift: { type: Number, enum: [1, 2, 3], required: true },
    toShift: { type: Number, enum: [1, 2, 3], required: true },
    inspectionId: { type: mongoose.Schema.Types.ObjectId, ref: "Question", unique: true },
    fromUser: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
    fromName: String,
    summary: String,
    critical: [String],
    watchNext: [String],
    openActionCount: { type: Number, default: 0 },
    language: { type: String, default: "English" },
    aiGenerated: { type: Boolean, default: false },
    acknowledged: { type: Boolean, default: false },
    ackBy: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
    ackName: String,
    ackSignature: String, // base64 PNG
    ackNote: String,
    ackAt: Date,
  },
  { timestamps: true },
);

HandoverSchema.index({ mine_name: 1, acknowledged: 1, createdAt: -1 });

export const HandoverModel = mongoose.model("Handover", HandoverSchema);
export default HandoverModel;
