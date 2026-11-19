import { Router } from "express";
import { list_handovers, acknowledge_handover, regenerate_handover } from "../../Controller/handover.controller.js";

const handover_router = Router();

handover_router.route("/").get(list_handovers);
handover_router.route("/:id/acknowledge").post(acknowledge_handover);
handover_router.route("/regenerate/:inspectionId").post(regenerate_handover);

export default handover_router;
