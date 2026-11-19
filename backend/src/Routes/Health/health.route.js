import { Router } from "express";
import { assess, list_records } from "../../Controller/health.controller.js";

const health_router = Router();

health_router.route("/assess").post(assess);
health_router.route("/records").get(list_records);

export default health_router;
