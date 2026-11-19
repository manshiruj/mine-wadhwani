import mongoose from "mongoose";

// One AI Health Manager assessment (AQM + PPE + smartwatch) for a shift / zone.
const HealthRecordSchema = new mongoose.Schema(
  {
    mine_name: { type: String, required: true },
    area: String,
    zone: String,
    shift: Number,
    inputs: mongoose.Schema.Types.Mixed,
    score: Number,
    level: { type: String, enum: ["Low", "Moderate", "High", "Critical"] },
    components: mongoose.Schema.Types.Mixed,
    findings: mongoose.Schema.Types.Mixed,
    advice: mongoose.Schema.Types.Mixed,
    aiGenerated: Boolean,
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
  },
  { timestamps: true },
);

HealthRecordSchema.index({ mine_name: 1, createdAt: -1 });

export const HealthRecordModel = mongoose.model("HealthRecord", HealthRecordSchema);
export default HealthRecordModel;
