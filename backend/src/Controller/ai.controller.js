import ApiResponse from "../Utils/Apiresponse.js";
import TranslationModel from "../Models/translation.model.js";
import { chatJSON, chatText, llmEnabled, LANGUAGES, languageFromReq } from "../Utils/llm.js";
import { APP_KNOWLEDGE, liveContext } from "../Services/assistant_context.js";
import { track } from "../Services/agent_registry.js";
import { mineScope } from "../Utils/mine_scope.js";

const VOICE_SYSTEM = `You fill a mine inspection checklist from a supervisor's spoken notes (may be Hindi, English, Hinglish or another Indian language).
Input: transcript and a list of questions {code, text}.
For each question the notes clearly address, output answer "YES" (compliant / condition satisfied), "NO" (non-compliant / problem found) or "NA" (not applicable).
Answer the question exactly as worded: YES means the statement in the question is true. Watch negative wording — e.g. smoke seen + "Is the stockpile free from smoke?" = NO; fire seen + "free from active fire?" = NO.
Skip questions that ask for a value or category ("What is…", "High/Medium/Low") — they are not yes/no. Use a statement only for the question it directly answers.
Add a short comment in the supervisor's language capturing the specifics they said (location, measurement, defect).
Never guess: if the notes do not mention a question, leave it out of "answers" entirely. Use "NA" only when the supervisor explicitly says it does not apply.
JSON: {"answers":[{"code":string,"answer":"YES"|"NO"|"NA","comment":string}], "follow_up": [string] (max 3 short questions to ask about important unanswered items)}`;

// POST /ai/voice-fill { transcript, questions: [{code, text}] }
const voice_fill = async (req, res) => {
  try {
    const { transcript, questions } = req.body ?? {};
    if (typeof transcript !== "string" || !transcript.trim()) {
      return res.status(400).json(ApiResponse.error("transcript is required", 400));
    }
    if (!Array.isArray(questions) || questions.length === 0) {
      return res.status(400).json(ApiResponse.error("questions must be a non-empty array", 400));
    }
    if (!llmEnabled()) {
      return res.status(503).json(ApiResponse.error("AI is not configured on the server (LLM_API_KEY missing)", 503));
    }
    const qs = questions.slice(0, 120).map((q) => ({ code: String(q.code), text: String(q.text).slice(0, 400) }));
    const ai = await track("voice", () => chatJSON(VOICE_SYSTEM, { transcript: transcript.slice(0, 6000), questions: qs }, { maxTokens: 2000 }), (r) => `${r?.answers?.length ?? 0} answers filled`);
    if (!ai) return res.status(502).json(ApiResponse.error("AI could not process the notes, please retry", 502));

    const valid = new Set(qs.map((q) => q.code));
    const answers = (ai.answers ?? []).filter(
      (a) => valid.has(String(a.code)) && ["YES", "NO", "NA"].includes(String(a.answer).toUpperCase()),
    ).map((a) => ({ code: String(a.code), answer: String(a.answer).toUpperCase(), comment: String(a.comment ?? "").slice(0, 500) }));
    return res.status(200).json(
      ApiResponse.success({ answers, follow_up: (ai.follow_up ?? []).slice(0, 3).map(String) }),
    );
  } catch (error) {
    return res.status(500).json(ApiResponse.error(error.message, 500));
  }
};

// POST /ai/translate { texts: [string], language: "hi" } -> { translations: { [text]: translated } }  (cached in Mongo)
const translate = async (req, res) => {
  try {
    const { texts, language } = req.body ?? {};
    const langName = LANGUAGES[language];
    if (!langName) return res.status(400).json(ApiResponse.error(`language must be one of ${Object.keys(LANGUAGES).join(", ")}`, 400));
    if (!Array.isArray(texts)) return res.status(400).json(ApiResponse.error("texts must be an array", 400));
    const unique = [...new Set(texts.map(String).filter(Boolean))].slice(0, 300);
    if (language === "en" || unique.length === 0) {
      return res.status(200).json(ApiResponse.success({ translations: Object.fromEntries(unique.map((t) => [t, t])) }));
    }

    const cached = await TranslationModel.find({ language, text: { $in: unique } }).lean();
    const out = Object.fromEntries(cached.map((c) => [c.text, c.translated]));
    const missing = unique.filter((t) => !(t in out));

    if (missing.length && llmEnabled()) {
      for (let i = 0; i < missing.length; i += 20) {
        const chunk = missing.slice(i, i + 20);
        const ai = await chatJSON(
          `Translate mine-safety checklist text from English to ${langName}. Keep technical terms, numbers, units and regulation references (e.g. "Reg. 100", "DGMS") unchanged. JSON: {"t": [translated strings in the same order]}`,
          { texts: chunk },
          { maxTokens: 3000 },
        );
        const arr = ai?.t;
        if (!Array.isArray(arr) || arr.length !== chunk.length) continue;
        const docs = chunk.map((text, j) => ({ text, language, translated: String(arr[j]) }));
        docs.forEach((d) => (out[d.text] = d.translated));
        await TranslationModel.insertMany(docs, { ordered: false }).catch(() => {}); // ignore duplicate races
      }
    }
    // Anything still untranslated falls back to English.
    for (const t of unique) out[t] ??= t;
    return res.status(200).json(ApiResponse.success({ translations: out }));
  } catch (error) {
    return res.status(500).json(ApiResponse.error(error.message, 500));
  }
};

// GET /ai/status
const ai_status = (req, res) =>
  res.status(200).json(ApiResponse.success({ enabled: llmEnabled(), languages: LANGUAGES }));

const CHAT_SYSTEM = (language, user, data) => `You are the mine safety assistant inside a mine inspection app used in Indian mines.
Help supervisors and admins with inspections, hazards, risk, corrective actions and DGMS rules (Mines Act 1952, MMR 1961, CMR 2017).
Rules:
- Reply in ${language}. Be short and practical: steps, numbers, who should act.
- Format for a phone chat bubble: plain text, short lines, "-" bullets, **bold** allowed. No tables, no LaTeX, no headings.
- Do not invent limits, thresholds or owners that are not in the app knowledge or live data; if a limit is mine- or DGMS-specific, say "check your mine's standard / DGMS limit".
- For questions about this mine's actions, handovers or alerts, use ONLY the LIVE DATA below; if it is not there, say so.
- For regulations, give the rule's substance; cite a regulation number only if you are sure, otherwise say "check the exact clause".
- For immediate danger (gas, fire, collapse, injury) tell them to stop work, evacuate as per the mine's emergency plan and inform the mine manager first.
- Never invent inspection results.
${APP_KNOWLEDGE}
USER: ${user.name} (role ${user.role}${user.mine_role ? ", " + user.mine_role : ""}).
LIVE DATA (JSON): ${data}`;

// POST /ai/chat { messages: [{role: "user"|"assistant", content}] } -> { reply }
const chat = async (req, res) => {
  try {
    const { messages } = req.body ?? {};
    if (!Array.isArray(messages) || messages.length === 0) {
      return res.status(400).json(ApiResponse.error("messages must be a non-empty array", 400));
    }
    if (!llmEnabled()) {
      return res.status(503).json(ApiResponse.error("AI is not configured on the server (LLM_API_KEY missing)", 503));
    }
    // Last 10 turns, text only, bounded size.
    const history = messages
      .slice(-10)
      .filter((m) => ["user", "assistant"].includes(m?.role) && typeof m.content === "string")
      .map((m) => ({ role: m.role, content: m.content.slice(0, 2000) }));
    if (history.at(-1)?.role !== "user") {
      return res.status(400).json(ApiResponse.error("last message must be from the user", 400));
    }
    const data = await liveContext(await mineScope(req));
    const reply = await track("assistant", () => chatText(CHAT_SYSTEM(languageFromReq(req), req.user, data), history), () => `answered: ${history.at(-1).content.slice(0, 60)}`);
    if (!reply) return res.status(502).json(ApiResponse.error("Assistant is unavailable, please retry", 502));
    return res.status(200).json(ApiResponse.success({ reply }));
  } catch (error) {
    return res.status(500).json(ApiResponse.error(error.message, 500));
  }
};

export { voice_fill, translate, ai_status, chat };
