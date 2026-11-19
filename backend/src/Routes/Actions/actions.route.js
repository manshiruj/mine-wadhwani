import { Router } from "express";
import { list_actions, close_action } from "../../Controller/actions.controller.js";

const actions_router = Router();

actions_router.route("/").get(list_actions);
actions_router.route("/:id/close").patch(close_action);

export default actions_router;
