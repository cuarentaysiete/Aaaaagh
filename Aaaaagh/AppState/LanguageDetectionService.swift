// LanguageDetectionService.swift
// AppState: offline language detection.
//
// Strategy:
// 1. Character-based detection for CJK (Chinese, Japanese, Korean) — very reliable.
// 2. NLTagger for other languages.
//
// No network.

import Foundation
import NaturalLanguage
import Domain

/// Result of a detection.
struct DetectionResult: Equatable {
    let language: Language?
    let confidence: Double
    let isUncertain: Bool
}

final class LanguageDetectionService {
    var minReliableLength: Int = 4

    func detect(_ text: String) -> DetectionResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return DetectionResult(language: nil, confidence: 0, isUncertain: true)
        }
        if trimmed.count < minReliableLength {
            return DetectionResult(language: nil, confidence: 0, isUncertain: true)
        }

        // 1. CJK detection (character-based, very reliable).
        if let cjkResult = detectCJK(trimmed) {
            return cjkResult
        }

        // 2. NLTagger for other languages.
        return detectWithNLTagger(trimmed)
    }

    /// Detect CJK languages by counting CJK characters.
    private func detectCJK(_ text: String) -> DetectionResult? {
        var cjkCount = 0
        var totalCount = 0

        for char in text.unicodeScalars {
            totalCount += 1
            // CJK Unified Ideographs (Chinese).
            if (0x4E00...0x9FFF).contains(char.value) ||
               (0x3400...0x4DBF).contains(char.value) ||
               (0x20000...0x2A6DF).contains(char.value) {
                cjkCount += 1
            }
            // Japanese Hiragana + Katakana.
            else if (0x3040...0x309F).contains(char.value) ||
                    (0x30A0...0x30FF).contains(char.value) {
                cjkCount += 1
            }
            // Korean Hangul.
            else if (0xAC00...0xD7AF).contains(char.value) ||
                    (0x1100...0x11FF).contains(char.value) {
                cjkCount += 1
            }
        }

        guard totalCount > 0 else { return nil }
        let cjkRatio = Double(cjkCount) / Double(totalCount)

        // If >50% of characters are CJK, it's likely CJK.
        guard cjkRatio > 0.5 else { return nil }

        // Distinguish between Chinese, Japanese, Korean:
        // - Japanese: has Hiragana or Katakana.
        // - Korean: has Hangul.
        // - Chinese: only CJK Unified Ideographs.
        var hasHiraganaKatakana = false
        var hasHangul = false

        for char in text.unicodeScalars {
            if (0x3040...0x309F).contains(char.value) ||
               (0x30A0...0x30FF).contains(char.value) {
                hasHiraganaKatakana = true
            }
            if (0xAC00...0xD7AF).contains(char.value) ||
               (0x1100...0x11FF).contains(char.value) {
                hasHangul = true
            }
        }

        let language: Language
        if hasHiraganaKatakana {
            language = Language(languageCode: "ja", englishName: "Japanese")
        } else if hasHangul {
            language = Language(languageCode: "ko", englishName: "Korean")
        } else {
            language = Language(languageCode: "zh", englishName: "Chinese")
        }

        return DetectionResult(
            language: language,
            confidence: min(0.95, cjkRatio + 0.5),
            isUncertain: false
        )
    }

    /// Detect language using NLTagger.
    private func detectWithNLTagger(_ text: String) -> DetectionResult {
        let tagger = NLTagger(tagSchemes: [.language])
        tagger.string = text

        let result = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .language)
        guard let tag = result.0 else {
            return DetectionResult(language: nil, confidence: 0, isUncertain: true)
        }
        let languageCode = tag.rawValue

        guard let language = Language.language(withCode: languageCode) else {
            return DetectionResult(language: nil, confidence: 0, isUncertain: true)
        }

        let confidence = min(0.9, Double(text.count) / 50.0)
        let isUncertain = confidence < 0.5

        return DetectionResult(language: language, confidence: confidence, isUncertain: isUncertain)
    }
}
