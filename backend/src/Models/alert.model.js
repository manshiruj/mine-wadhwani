import mongoose from "mongoose";

// In-app alert for mine admins (critical findings, overdue actions, PPE/AQM flags).
const AlertSchema = new mongoose.Schema(
  {
    mine_name: { type: String, required: true },
    type: {
      type: String,
      enum: ["critical_finding", "overdue_action", "ppe", "aqm", "health", "risk_monitor", "other"],
      required: true,
    },
    severity: { type: String, enum: ["medium", "high", "critical"], default: "high" },
    title: { type: String, required: true },
    message: String,
    refId: mongoose.Schema.Types.ObjectId, // action / inspection id
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
    readBy: [{ type: mongoose.Schema.Types.ObjectId, ref: "User" }],
  },
  { timestamps: true },
);

AlertSchema.index({ mine_name: 1, createdAt: -1 });

export const AlertModel = mongoose.model("Alert", AlertSchema);
export default AlertModel;
