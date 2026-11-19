import { Router } from "express";
import { list_alerts, create_alert, mark_read } from "../../Controller/alerts.controller.js";

const alerts_router = Router();

alerts_router.route("/").get(list_alerts).post(create_alert);
alerts_router.route("/read").post(mark_read);

export default alerts_router;
