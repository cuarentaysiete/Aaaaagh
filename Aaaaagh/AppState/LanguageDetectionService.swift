// LanguageDetectionService.swift
// AppState: offline language detection backed by Apple's NaturalLanguage.
// No network; runs entirely on-device.

import Foundation
import NaturalLanguage
import Domain

/// Result of a detection, including confidence and whether the text was usable.
struct DetectionResult: Equatable, Sendable {
    /// Detected `Language`, if confident enough to map.
    let language: Language?
    /// Apple's confidence score in 0...1 (or nil when text is empty).
    let confidence: Double
    /// True when the input was too short / ambiguous to trust the detection.
    let isUncertain: Bool
}

/// Wraps `NLLanguageRecognizer` to detect the language of user input offline.
final class LanguageDetectionService: ObservableObject, Sendable {
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

        let dominant = NLLanguageRecognizer.dominantLanguage(for: trimmed)

        // `unknownLanguageIdentifier` signals "couldn't tell".
        let isKnown = dominant != NLLanguageRecognizer.unknownLanguageIdentifier
        // Apple reports confidence 0...1; it is often 1.0 for obvious text and
        // lower for short/ambiguous strings.
        let confidence = isKnown ? 1.0 : 0.0

        let language = isKnown ? Language.language(fromDetectionCode: dominant) : nil

        // Uncertainty: unknown, low confidence, or text shorter than our reliable floor.
        let isUncertain = (!isKnown)
            || (confidence < confidenceThreshold)
            || (trimmed.count < minReliableLength)
            || (language == nil)

        return DetectionResult(language: language, confidence: confidence, isUncertain: isUncertain)
    }
}
