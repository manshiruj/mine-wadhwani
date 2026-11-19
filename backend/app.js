import express from "express";
const app = express();
import cors from "cors";
import { auth_middleware } from "./src/Middleware/auth.middleware.js";
app.use(
  cors({
    origin: "*",
    credentials: true,
  }),
);

app.use(
  express.json({
    limit: "50mb",
  }),
);

app.use(
  express.urlencoded({
    extended: true,
    limit: "50mb",
  }),
);
app.get("/health", (req, res) => {
  res
    .status(200)
    .json({ status: "OK", message: "Server is healthy and active" });
});

import userrouter from "./src/Routes/User/user.route.js";
app.use("/api/v1/auth", userrouter);
// adding forms data route
import forms_data_router from "./src/Routes/Forms_data/forms_data.route.js";
app.use("/api/v1/forms-data", auth_middleware, forms_data_router);
// aqi.in AQM device proxy
import aqm_router from "./src/Routes/Aqm/aqm.route.js";
app.use("/api/v1/aqm", auth_middleware, aqm_router);
// Roboflow PPE detection proxy (keeps API key off the client)
import drone_router from "./src/Routes/Drone/drone.route.js";
app.use("/api/v1/drone", auth_middleware, drone_router);
// Agentic shift features: handover, corrective actions, alerts, admin dashboard, AI helpers
import handover_router from "./src/Routes/Handover/handover.route.js";
import actions_router from "./src/Routes/Actions/actions.route.js";
import alerts_router from "./src/Routes/Alerts/alerts.route.js";
import dashboard_router from "./src/Routes/Dashboard/dashboard.route.js";
import ai_router from "./src/Routes/Ai/ai.route.js";
app.use("/api/v1/handover", auth_middleware, handover_router);
app.use("/api/v1/actions", auth_middleware, actions_router);
app.use("/api/v1/alerts", auth_middleware, alerts_router);
app.use("/api/v1/dashboard", auth_middleware, dashboard_router);
app.use("/api/v1/ai", auth_middleware, ai_router);
import health_router from "./src/Routes/Health/health.route.js";
app.use("/api/v1/health", auth_middleware, health_router);
import risk_monitor_router from "./src/Routes/RiskMonitor/risk_monitor.route.js";
import agents_router from "./src/Routes/Agents/agents.route.js";
app.use("/api/v1/risk-monitor", auth_middleware, risk_monitor_router);
app.use("/api/v1/agents", auth_middleware, agents_router);
export default app;
