import { Router } from "express";
import { voice_fill, translate, ai_status, chat } from "../../Controller/ai.controller.js";

const ai_router = Router();

ai_router.route("/status").get(ai_status);
ai_router.route("/voice-fill").post(voice_fill);
ai_router.route("/translate").post(translate);
ai_router.route("/chat").post(chat);

export default ai_router;
