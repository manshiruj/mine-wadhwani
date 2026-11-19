import { Router } from "express";
import {
  get_devices,
  get_latest,
  get_history,
  get_rainfall,
} from "../../Controller/aqm.controller.js";

const aqm_router = Router();

aqm_router.route("/devices").get(get_devices);
aqm_router.route("/latest").get(get_latest);
aqm_router.route("/history").get(get_history);
aqm_router.route("/rainfall").get(get_rainfall);

export default aqm_router;
