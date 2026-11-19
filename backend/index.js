import express from "express";
import dotenv from "dotenv";
import cors from "cors";
dotenv.config();
import { connectDB } from "./src/DB/index.db.js";
import app from "./app.js";
import { escalateOverdue } from "./src/Services/shift_agent.js";
import { runRiskMonitorCycle } from "./src/Services/risk_monitor.js";
import { track } from "./src/Services/agent_registry.js";
connectDB()
  .then(() => {
    console.log("process.env.PORT:", process.env.PORT);
    app.listen(process.env.PORT || 1425, () => {
      console.log(`⚙️ Server is running on port ${process.env.PORT}`);
    });
    // shortcut: in-process timer, runs once per server instance; move to a cron/queue if scaled to many instances.
    // Scheduled agents run independently of each other (and of the event-driven agents).
    const escalate = () =>
      track("escalation", escalateOverdue, (n) => `${n} overdue action(s) escalated`).catch((e) =>
        console.error("Escalation error:", e.message),
      );
    const monitorRisk = () => runRiskMonitorCycle().catch((e) => console.error("Risk monitor error:", e.message));
    setInterval(escalate, 15 * 60 * 1000);
    setInterval(monitorRisk, Number(process.env.RISK_MONITOR_INTERVAL_MIN || 10) * 60 * 1000);
    setTimeout(() => { escalate(); monitorRisk(); }, 5000);
  })
  .catch((e) => {
    console.log("DB connection error", e);
  });
