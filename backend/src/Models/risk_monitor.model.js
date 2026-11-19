import mongoose from "mongoose";

const ENVIRONMENTS = ["surface_stockpile", "underground_goaf", "active_workings"];

// A monitored location (one AQM device and/or manual readings).
const MonitorSchema = new mongoose.Schema(
  {
    mine_name: { type: String, required: true },
    zone: { type: String, required: true },
    environment: { type: String, enum: ENVIRONMENTS, default: "surface_stockpile" },
    device_serial: String, // aqi.in device; empty = manual readings only
    coal_grade: { type: String, default: "G7" },
    fines_pct: { type: Number, default: 15 },
    active: { type: Boolean, default: true },
  },
  { timestamps: true },
);
MonitorSchema.index({ mine_name: 1, zone: 1 }, { unique: true });

const ReadingSchema = new mongoose.Schema(
  {
    monitor: { type: mongoose.Schema.Types.ObjectId, ref: "RiskMonitor", required: true },
    source: { type: String, enum: ["aqm", "manual"], required: true },
    taken_at: { type: Date, default: Date.now },
    coal_temp_c: Number,
    co_ppm: Number,
    co2_ppm: Number,
    o2_pct: Number,
    c2h4_ppm: Number,
    ambient_temp_c: Number,
    humidity_pct: Number,
    pm25: Number,
    note: String,
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
  },
  { timestamps: true },
);
ReadingSchema.index({ monitor: 1, taken_at: -1 });

const AssessmentSchema = new mongoose.Schema(
  {
    monitor: { type: mongoose.Schema.Types.ObjectId, ref: "RiskMonitor", required: true },
    mine_name: String,
    zone: String,
    environment: String,
    measured: mongoose.Schema.Types.Mixed, // the readings used
    baseline_index: Number,
    ml: mongoose.Schema.Types.Mixed,
    forecast: mongoose.Schema.Types.Mixed,
    safety_alerts: mongoose.Schema.Types.Mixed,
    data_quality: [String],
    level: String,
    grade: Number,
    risk_index: Number,
    explanation: mongoose.Schema.Types.Mixed,
    aiGenerated: Boolean,
  },
  { timestamps: true },
);
AssessmentSchema.index({ monitor: 1, createdAt: -1 });

export const RiskMonitorModel = mongoose.model("RiskMonitor", MonitorSchema);
export const RiskReadingModel = mongoose.model("RiskReading", ReadingSchema);
export const RiskAssessmentModel = mongoose.model("RiskAssessment", AssessmentSchema);
