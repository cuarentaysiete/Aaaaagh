// LanguageDetectionService.swift
// AppState: offline language detection using NLTagger (NaturalLanguage framework).
//
// Uses `NLTagger` with the `.language` scheme, which is a stable, well-documented
// API that works across macOS versions without the variability of
// `NLLanguageRecognizer`. No network.

import Foundation
import NaturalLanguage
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

/// Detects the language of user input offline using `NLTagger` with the
/// `.language` scheme. No network.
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

        // Use NLTagger with the .language scheme to detect the language.
        let tagger = NLTagger(tagSchemes: [.language])
        tagger.string = trimmed

        // Get the language tag for the first paragraph.
        let result = tagger.tag(at: trimmed.startIndex, unit: .paragraph, scheme: .language)
        guard let tag = result.0 else {
            return DetectionResult(language: nil, confidence: 0, isUncertain: true)
        }
        let languageCode = tag.rawValue

        // Map the ISO 639-1 code to a Domain.Language.
        guard let language = Language.language(withCode: languageCode) else {
            return DetectionResult(language: nil, confidence: 0, isUncertain: true)
        }

        // NLTagger doesn't expose a confidence score directly; use a heuristic.
        // Shorter texts are less reliable, so scale confidence by length.
        let confidence = min(0.9, Double(trimmed.count) / 50.0)

        let isUncertain = confidence < 0.5

        return DetectionResult(language: language, confidence: confidence, isUncertain: isUncertain)
    }
}
