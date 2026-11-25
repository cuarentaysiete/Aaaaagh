// WordAlternativeRequest.swift
// Domain: a request for contextual word-level translation alternatives.

import Foundation

/// Asks the local model for a few alternative translations of a single selected
/// word, given the surrounding sentence and the source/target languages.
struct WordAlternativeRequest: Equatable, Sendable {
    let selectedWord: String
    /// The sentence (or short passage) in the *target* language that contains the
    /// selected word. Used for contextual disambiguation.
    let contextSentence: String
    let sourceLanguage: Language
    let targetLanguage: Language
    /// How many alternatives to request (the engine caps this for safety).
    let maximumAlternatives: Int

    init(
        selectedWord: String,
        contextSentence: String,
        sourceLanguage: Language,
        targetLanguage: Language,
        maximumAlternatives: Int = 5
    ) {
        self.selectedWord = selectedWord
        self.contextSentence = contextSentence
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.maximumAlternatives = maximumAlternatives
    }

    var isEmpty: Bool {
        selectedWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
