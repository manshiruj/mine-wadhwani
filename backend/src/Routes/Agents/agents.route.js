import { Router } from "express";
import ApiResponse from "../../Utils/Apiresponse.js";
import { listAgents } from "../../Services/agent_registry.js";

const agents_router = Router();

// GET /agents -> every AI agent with its trigger, run count and latest activity
agents_router.route("/").get((req, res) => res.status(200).json(ApiResponse.success(listAgents())));

export default agents_router;
