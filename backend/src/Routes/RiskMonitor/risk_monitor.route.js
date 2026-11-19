import { Router } from "express";
import { list_monitors, upsert_monitor, add_reading, history, model_card } from "../../Controller/risk_monitor.controller.js";
import { requireAdmin } from "../../Middleware/role.middleware.js";

const risk_monitor_router = Router();

risk_monitor_router.route("/monitors").get(list_monitors).post(requireAdmin, upsert_monitor);
risk_monitor_router.route("/monitors/:id/readings").post(add_reading);
risk_monitor_router.route("/monitors/:id/history").get(history);
risk_monitor_router.route("/model").get(model_card);

export default risk_monitor_router;
