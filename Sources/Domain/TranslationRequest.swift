// TranslationRequest.swift
// Domain: a single translation operation.
// All members are `public` so the `Aaaaagh` target can use them.

import Foundation

/// Describes the source language for a translation: either "auto-detect" or an
/// explicit user-chosen language.
public enum SourceLanguageOption: Equatable, Sendable {
    case auto
    case language(Language)
}

/// A request to translate a piece of text.
public struct TranslationRequest: Equatable, Sendable {
    public let text: String
    public let sourceLanguage: SourceLanguageOption
    public let targetLanguage: Language

    public init(text: String, sourceLanguage: SourceLanguageOption, targetLanguage: Language) {
        self.text = text
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
    }

    public var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The resolved source language, if one is known (not `.auto`).
    public var resolvedSourceLanguage: Language? {
        switch sourceLanguage {
        case .auto: return nil
        case .language(let lang): return lang
        }
    }
}
