// Language.swift
// Domain: language model. Pure value types, no SwiftUI/MLX dependencies.

import Foundation

/// A human-readable language with a stable code used for prompts and detection.
///
/// The `code` is the ISO-639-1 (or script-tagged for CJK) identifier we feed to
/// the model and compare against `NaturalLanguage` detection results.
struct Language: Hashable, Identifiable, Codable, Sendable {
    /// Stable machine code, e.g. `"es"`, `"en"`, `"ja"`, `"zh-Hans"`.
    let code: String
    /// Native display name, e.g. `"Español"`.
    let nativeName: String
    /// English display name, e.g. `"Spanish"`.
    let englishName: String

    var id: String { code }

    /// Label shown in dropdowns: "Español (ES)".
    var displayLabel: String {
        let tag = code.uppercased().split(separator: "-").first.map(String.init) ?? code.uppercased()
        return "\(nativeName) (\(tag))"
    }

    /// Short name used in inline labels (no tag): "Español".
    var displayName: String { nativeName }

    /// Localized description used in status / detection messages.
    var localizedDescription: String { "\(englishName) (\(code))" }
}

extension Language {
    /// The European core subset, shown first / grouped in pickers.
    static let europeanLanguages: [Language] = all.filter { l in
        !Set(["zh-Hans", "zh-Hant", "ja", "ko"]).contains(l.code)
    }

    /// The set of languages offered in the UI. European languages are the core
    /// strength; CJK (Chinese, Japanese, Korean) is cleanly supported as well.
    static let all: [Language] = [
        // European (core)
        Language(code: "en", nativeName: "English", englishName: "English"),
        Language(code: "es", nativeName: "Español", englishName: "Spanish"),
        Language(code: "fr", nativeName: "Français", englishName: "French"),
        Language(code: "de", nativeName: "Deutsch", englishName: "German"),
        Language(code: "it", nativeName: "Italiano", englishName: "Italian"),
        Language(code: "pt", nativeName: "Português", englishName: "Portuguese"),
        Language(code: "nl", nativeName: "Nederlands", englishName: "Dutch"),
        Language(code: "ca", nativeName: "Català", englishName: "Catalan"),
        Language(code: "gl", nativeName: "Galego", englishName: "Galician"),
        Language(code: "eu", nativeName: "Euskara", englishName: "Basque"),
        Language(code: "pl", nativeName: "Polski", englishName: "Polish"),
        Language(code: "cs", nativeName: "Čeština", englishName: "Czech"),
        Language(code: "sk", nativeName: "Slovenčina", englishName: "Slovak"),
        Language(code: "ro", nativeName: "Română", englishName: "Romanian"),
        Language(code: "bg", nativeName: "Български", englishName: "Bulgarian"),
        Language(code: "hr", nativeName: "Hrvatski", englishName: "Croatian"),
        Language(code: "sr", nativeName: "Српски", englishName: "Serbian"),
        Language(code: "sl", nativeName: "Slovenščina", englishName: "Slovenian"),
        Language(code: "hu", nativeName: "Magyar", englishName: "Hungarian"),
        Language(code: "da", nativeName: "Dansk", englishName: "Danish"),
        Language(code: "sv", nativeName: "Svenska", englishName: "Swedish"),
        Language(code: "nb", nativeName: "Norsk", englishName: "Norwegian"),
        Language(code: "fi", nativeName: "Suomi", englishName: "Finnish"),
        Language(code: "el", nativeName: "Ελληνικά", englishName: "Greek"),
        Language(code: "tr", nativeName: "Türkçe", englishName: "Turkish"),
        Language(code: "uk", nativeName: "Українська", englishName: "Ukrainian"),
        Language(code: "ru", nativeName: "Русский", englishName: "Russian"),
        // CJK (clean support)
        Language(code: "zh-Hans", nativeName: "中文（简体）", englishName: "Chinese (Simplified)"),
        Language(code: "zh-Hant", nativeName: "中文（繁體）", englishName: "Chinese (Traditional)"),
        Language(code: "ja", nativeName: "日本語", englishName: "Japanese"),
        Language(code: "ko", nativeName: "한국어", englishName: "Korean"),
    ]

    /// Sensible default target when nothing better is known.
    static let defaultLanguage = Language(code: "en", nativeName: "English", englishName: "English")

    static func language(withCode code: String) -> Language? {
        all.first { $0.code.caseInsensitiveCompare(code) == .orderedSame }
    }

    /// Best-effort mapping from an Apple `NLLanguage`-style raw code to our `Language`.
    /// Tolerates scripts (e.g. "zh-Hans", "sr-Latn") by matching on the base code.
    static func language(fromDetectionCode code: String) -> Language? {
        if let exact = language(withCode: code) { return exact }
        // Fall back to the base language code (strip script/region).
        let base = code.split(separator: "-").first.map(String.init) ?? code
        return language(withCode: base)
    }
}
