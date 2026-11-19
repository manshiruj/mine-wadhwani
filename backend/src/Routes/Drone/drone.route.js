import { Router } from "express";
import { analyze_ppe } from "../../Controller/drone.controller.js";

const drone_router = Router();

drone_router.route("/analyze-ppe").post(analyze_ppe);

export default drone_router;
