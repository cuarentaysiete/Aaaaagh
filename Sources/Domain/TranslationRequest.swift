// TranslationRequest.swift
// Domain: a single translation operation.

import Foundation

/// Describes the source language for a translation: either "auto-detect" or an
/// explicit user-chosen language.
enum SourceLanguageOption: Equatable, Sendable {
    case auto
    case language(Language)
}

/// A request to translate a piece of text.
struct TranslationRequest: Equatable, Sendable {
    let text: String
    let sourceLanguage: SourceLanguageOption
    let targetLanguage: Language

    init(text: String, sourceLanguage: SourceLanguageOption, targetLanguage: Language) {
        self.text = text
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
    }

    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The resolved source language, if one is known (not `.auto`).
    var resolvedSourceLanguage: Language? {
        switch sourceLanguage {
        case .auto: return nil
        case .language(let lang): return lang
        }
    }
}
