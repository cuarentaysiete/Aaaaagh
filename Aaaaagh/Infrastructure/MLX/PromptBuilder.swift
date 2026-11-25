// PromptBuilder.swift
// Infrastructure/MLX: builds terse, deterministic prompts so that an `Instruct`
// model is used strictly as a translation engine — zero conversational chatter.
// Prompts are isolated per ModelProfile (via promptTemplateType) so swapping
// models never leaks prompt text into the UI.

import Foundation
import Domain

/// Builds the terse system/user prompt strings fed to the LLM.
///
/// The system prompt is deliberately minimal and imperative: it forces the model
/// to output *only* the translation (or only the alternative list), with no
/// greeting, no explanation, no markdown, no quotes.
struct PromptBuilder: Sendable {

    // MARK: - Translation

    /// Terse, imperative system prompt for translation.
    static func systemPrompt(
        from source: Language?,
        to target: Language,
        modelStyle: ModelProfile.PromptStyle
    ) -> String {
        var s = """
        You are a precise, offline translation engine. \
        Output ONLY the direct translation. \
        No greetings, no commentary, no explanations, no markdown, no quotes, \
        no labels, no source text. \
        Preserve the original tone, register, and line structure.
        """
        if let source {
            s += " Translate from \(source.englishName) into \(target.englishName)."
        } else {
            s += " Detect the source language automatically and translate into \(target.englishName)."
        }
        // Style-specific fine-tuning (kept minimal; the model is Instruct, so a
        // small nudge is enough to suppress conversational filler).
        switch modelStyle {
        case .terseEngine:
            s += " Reply with the translation and nothing else."
        }
        return s
    }

    /// The user message: just the raw text (or an explicit "translate X to Y"
    /// wrapper when the source isn't auto-detected, for extra determinism).
    static func translationPrompt(
        text: String,
        target: Language,
        source: Language?,
        modelStyle: ModelProfile.PromptStyle
    ) -> String {
        if let source {
            return "Translate the following \(source.englishName) text into \(target.englishName). Reply with the translation only.\n\n\(text)"
        } else {
            return "Translate the following text into \(target.englishName). Reply with the translation only.\n\n\(text)"
        }
    }

    // MARK: - Word alternatives

    static func wordAlternativeSystemPrompt(modelStyle: ModelProfile.PromptStyle) -> String {
        """
        You are a precise, offline word-level translation helper. \
        Return ONLY a short list of alternative translations of a single word, \
        one per line. \
        No explanations, no numbering, no quotes, no markdown, no extra text.
        """
    }

    static func wordAlternativePrompt(
        word: String,
        contextSentence: String,
        source: Language,
        target: Language,
        count: Int,
        modelStyle: ModelProfile.PromptStyle
    ) -> String {
        """
        Target language: \(target.englishName) (\(target.code))
        Source language: \(source.englishName) (\(source.code))
        Context sentence: \(contextSentence)
        Selected word: \(word)

        Give \(count) alternative translations of the selected word that best fit this context. One per line.
        """
    }
}
