// WordAlternativeRequest.swift
// Domain: a request for contextual word-level translation alternatives.
// All members are `public` so the `Aaaaagh` target can use them.

import Foundation

/// Asks the local model for a few alternative translations of a single selected
/// word, given the surrounding sentence and the source/target languages.
public struct WordAlternativeRequest: Equatable, Sendable {
    public let selectedWord: String
    /// The sentence (or short passage) in the *target* language that contains the
    /// selected word. Used for contextual disambiguation.
    public let contextSentence: String
    public let sourceLanguage: Language
    public let targetLanguage: Language
    /// How many alternatives to request (the engine caps this for safety).
    public let maximumAlternatives: Int

    public init(
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

    public var isEmpty: Bool {
        selectedWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
