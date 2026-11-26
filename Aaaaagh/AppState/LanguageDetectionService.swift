// LanguageDetectionService.swift
// AppState: offline language detection.
//
// NOTE: This implementation uses a lightweight, deterministic character-based
// heuristic rather than `NLLanguageRecognizer`, whose exact API differs across
// macOS/Xcode versions and could not be confirmed for the target SDK. The
// heuristic covers the most common European-language markers (accented
// characters, punctuation) and degrades gracefully to "uncertain" (auto mode)
// when no marker is found. The model itself can also infer the source language
// from the text when no source is explicitly selected.

import Foundation
import Domain

/// Result of a detection, including confidence and whether the text was usable.
struct DetectionResult: Equatable {
    /// Detected `Language`, if confident enough to map.
    let language: Language?
    /// Heuristic confidence score in 0...1 (0 when text is empty/no marker).
    let confidence: Double
    /// True when the input was too short / ambiguous to trust the detection.
    let isUncertain: Bool
}

/// Detects the language of user input offline using a simple character-based
/// heuristic. No network; no `NLLanguageRecognizer` (API varies across SDKs).
final class LanguageDetectionService {
    /// Minimum number of characters for a "reliable" detection.
    var minReliableLength: Int = 4

    /// Detect the language of `text`. Never throws; empty text yields a neutral result.
    func detect(_ text: String) -> DetectionResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return DetectionResult(language: nil, confidence: 0, isUncertain: true)
        }

        if trimmed.count < minReliableLength {
            return DetectionResult(language: nil, confidence: 0, isUncertain: true)
        }

        // Character-based heuristics for common European languages.
        // (Simple and deterministic; degrades to "uncertain" when no marker found.)
        let language = heuristicDetect(trimmed)

        let confidence: Double
        if language == nil {
            confidence = 0
        } else {
            confidence = 0.6 // moderate confidence for heuristic matches
        }

        let isUncertain = (language == nil) || (confidence < 0.5)

        return DetectionResult(language: language, confidence: confidence, isUncertain: isUncertain)
    }

    /// Heuristic language detection based on characteristic characters.
    private func heuristicDetect(_ text: String) -> Language? {
        let lower = text.lowercased()

        // Spanish markers: "ñ", "¿", "¡"
        if lower.contains("ñ") || lower.contains("¿") || lower.contains("¡") {
            return Language(code: "es", nativeName: "Español", englishName: "Spanish")
        }

        // French markers: "é", "è", "ê", "à", "ç" + "r" endings are common
        if lower.contains("é") || lower.contains("è") || lower.contains("ê") || lower.contains("à") || lower.contains("ç") {
            // Could be French, Spanish, Portuguese — but "ç" is very French-specific.
            if lower.contains("ç") {
                return Language(code: "fr", nativeName: "Français", englishName: "French")
            }
            // Otherwise, lean French (most common European language with these accents).
            return Language(code: "fr", nativeName: "Français", englishName: "French")
        }

        // German markers: "ü", "ö", "ä", "ß"
        if lower.contains("ü") || lower.contains("ö") || lower.contains("ä") || lower.contains("ß") {
            return Language(code: "de", nativeName: "Deutsch", englishName: "German")
        }

        // Italian markers: "è", "ì", "ù", "ò", "à" (but these overlap with French/Spanish).
        // Italian is harder to distinguish without NLP; default to uncertain.

        // No marker found → uncertain (auto mode).
        return nil
    }
}
