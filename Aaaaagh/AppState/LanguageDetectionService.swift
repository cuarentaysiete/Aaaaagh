// LanguageDetectionService.swift
// AppState: offline language detection backed by Apple's NaturalLanguage.
// No network; runs entirely on-device.

import Foundation
import NaturalLanguage
import Domain

/// Result of a detection, including confidence and whether the text was usable.
struct DetectionResult: Equatable {
    /// Detected `Language`, if confident enough to map.
    let language: Language?
    /// Apple's confidence score in 0...1 (or 0 when text is empty/unknown).
    let confidence: Double
    /// True when the input was too short / ambiguous to trust the detection.
    let isUncertain: Bool
}

/// Wraps `NLLanguageRecognizer` to detect the language of user input offline.
///
/// Used synchronously from the `@MainActor` ViewModel, so this class is a
/// plain, owned object (no explicit `Sendable` conformance — it has mutable
/// config properties and is never shared across isolation domains).
final class LanguageDetectionService {
    /// Confidence below which we consider a detection "uncertain".
    var confidenceThreshold: Double = 0.5

    /// Minimum number of characters for a "reliable" detection. Very short strings
    /// (single words, proper nouns) are inherently ambiguous.
    var minReliableLength: Int = 4

    /// Detect the language of `text`. Never throws; empty text yields a neutral result.
    func detect(_ text: String) -> DetectionResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return DetectionResult(language: nil, confidence: 0, isUncertain: true)
        }

        let recognizer = NLLanguageRecognizer()
        // `recognizeLanguage(of:)` returns a non-optional `NLLanguage`; it is
        // `.unknown` when the recognizer cannot determine the language.
        let dominant = recognizer.recognizeLanguage(of: trimmed)
        let isKnown = (dominant != NLLanguage.unknown)
        // Apple reports confidence in 0...1 (Float).
        let confidence = Double(recognizer.recognizeConfidence(for: dominant))

        // Map the `NLLanguage` to our domain `Language` via its BCP-47 raw value.
        let language = isKnown
            ? Language.language(fromDetectionCode: dominant.rawValue)
            : nil

        // Uncertainty: unknown, low confidence, or text shorter than our reliable floor.
        let isUncertain = (!isKnown)
            || (confidence < confidenceThreshold)
            || (trimmed.count < minReliableLength)
            || (language == nil)

        return DetectionResult(language: language, confidence: confidence, isUncertain: isUncertain)
    }
}
