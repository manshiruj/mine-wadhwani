import mongoose from "mongoose";

// Cache of AI translations (checklist questions etc.) so each text is translated once per language.
const TranslationSchema = new mongoose.Schema({
  text: { type: String, required: true },
  language: { type: String, required: true },
  translated: { type: String, required: true },
});

TranslationSchema.index({ text: 1, language: 1 }, { unique: true });

export const TranslationModel = mongoose.model("Translation", TranslationSchema);
export default TranslationModel;
