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
/// Uses the property-based API (`processLanguage(of:)` + `dominantLanguage` +
/// `dominantLanguageConfidence`) which is stable across macOS versions. Avoids
/// `NLLanguage.unknown` (which may not exist) by relying on our own `Language`
/// type's `nil` return for unrecognized codes.
final class LanguageDetectionService {
    /// Confidence below which we consider a detection "uncertain".
    var confidenceThreshold: Double = 0.5

    /// Minimum number of characters for a "reliable" detection.
    var minReliableLength: Int = 4

    /// Detect the language of `text`. Never throws; empty text yields a neutral result.
    func detect(_ text: String) -> DetectionResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return DetectionResult(language: nil, confidence: 0, isUncertain: true)
        }

        let recognizer = NLLanguageRecognizer()
        recognizer.processLanguage(of: trimmed)
        let dominant = recognizer.dominantLanguage
        let confidence = Double(recognizer.dominantLanguageConfidence)

        // Map the `NLLanguage` to our domain `Language` via its BCP-47 raw value.
        // Returns `nil` for unrecognized/unknown languages, which we treat as
        // "uncertain" below.
        let language = Language.language(fromDetectionCode: dominant.rawValue)

        // Uncertainty: no recognizable language, low confidence, or text shorter
        // than our reliable floor.
        let isUncertain = (language == nil)
            || (confidence < confidenceThreshold)
            || (Double(trimmed.count) < Double(minReliableLength))

        return DetectionResult(language: language, confidence: confidence, isUncertain: isUncertain)
    }
}
