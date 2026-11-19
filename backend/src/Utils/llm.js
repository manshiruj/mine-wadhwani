// Free-tier friendly LLM client: any OpenAI-compatible chat API.
//   Groq (default):  LLM_BASE_URL=https://api.groq.com/openai/v1            LLM_MODEL=openai/gpt-oss-120b
//   Gemini:          LLM_BASE_URL=https://generativelanguage.googleapis.com/v1beta/openai  LLM_MODEL=gemini-2.5-flash
//   OpenRouter:      LLM_BASE_URL=https://openrouter.ai/api/v1              LLM_MODEL=<model>:free
const BASE = () => process.env.LLM_BASE_URL || "https://api.groq.com/openai/v1";
const MODEL = () => process.env.LLM_MODEL || "openai/gpt-oss-120b";

export const llmEnabled = () => Boolean(process.env.LLM_API_KEY);

export const LANGUAGES = {
  en: "English",
  hi: "Hindi",
  bn: "Bengali",
  or: "Odia",
  te: "Telugu",
  ta: "Tamil",
  mr: "Marathi",
};

// "hi-IN,hi;q=0.9" -> "Hindi"
export const languageFromReq = (req) => {
  const code = (req.headers["accept-language"] || "en").slice(0, 2).toLowerCase();
  return LANGUAGES[code] || "English";
};

// Pull the first JSON object out of a model reply (some free models wrap it in prose/```json).
export const parseJsonReply = (text) => {
  if (!text) return null;
  const start = text.indexOf("{");
  const end = text.lastIndexOf("}");
  if (start === -1 || end <= start) return null;
  try {
    return JSON.parse(text.slice(start, end + 1));
  } catch {
    return null;
  }
};

// Free-text chat: messages = [{role: "user"|"assistant", content}]. Returns reply text or null.
export const chatText = async (system, messages, { maxTokens = 1200 } = {}) => {
  if (!llmEnabled()) return null;
  try {
    const res = await fetch(`${BASE()}/chat/completions`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${process.env.LLM_API_KEY}`,
      },
      body: JSON.stringify({
        model: MODEL(),
        temperature: 0.3,
        max_tokens: maxTokens,
        ...(MODEL().includes("gpt-oss") ? { reasoning_effort: "low" } : {}),
        messages: [{ role: "system", content: system }, ...messages],
      }),
      signal: AbortSignal.timeout(45000),
    });
    const json = await res.json().catch(() => ({}));
    if (!res.ok) {
      console.error("LLM error:", res.status, json.error?.message ?? json);
      return null;
    }
    return json.choices?.[0]?.message?.content?.trim() || null;
  } catch (e) {
    console.error("LLM request failed:", e.message);
    return null;
  }
};

// Returns parsed JSON object, or null when AI is not configured / fails (callers must fall back).
export const chatJSON = async (system, user, { maxTokens = 1500 } = {}) => {
  if (!llmEnabled()) return null;
  try {
    const res = await fetch(`${BASE()}/chat/completions`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${process.env.LLM_API_KEY}`,
      },
      body: JSON.stringify({
        model: MODEL(),
        temperature: 0.2,
        max_tokens: maxTokens,
        response_format: { type: "json_object" },
        // gpt-oss models reason first; keep it short so free-tier token limits last.
        ...(MODEL().includes("gpt-oss") ? { reasoning_effort: "low" } : {}),
        messages: [
          { role: "system", content: `${system}\nReply with a single JSON object only.` },
          { role: "user", content: typeof user === "string" ? user : JSON.stringify(user) },
        ],
      }),
      signal: AbortSignal.timeout(45000),
    });
    const json = await res.json().catch(() => ({}));
    if (!res.ok) {
      console.error("LLM error:", res.status, json.error?.message ?? json);
      return null;
    }
    return parseJsonReply(json.choices?.[0]?.message?.content);
  } catch (e) {
    console.error("LLM request failed:", e.message);
    return null;
  }
};
