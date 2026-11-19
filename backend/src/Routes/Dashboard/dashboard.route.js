import { Router } from "express";
import { get_summary } from "../../Controller/dashboard.controller.js";
import { requireAdmin } from "../../Middleware/role.middleware.js";

const dashboard_router = Router();

dashboard_router.route("/summary").get(requireAdmin, get_summary);

export default dashboard_router;
