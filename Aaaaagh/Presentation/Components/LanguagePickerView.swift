// LanguagePickerView.swift
// Presentation/Components: compact language dropdown.
//
// When auto-detect is active and a language is detected, the picker label
// shows "Auto-Detect (Spanish)" instead of a separate badge (avoids overlap
// and layout shifts).

import SwiftUI
import Domain

struct LanguagePickerView: View {
    /// Optional title (nil = no title).
    let title: String?
    @Binding var selectedLanguage: Language?
    @Binding var isAuto: Bool
    var allowsAutoDetect: Bool
    var detectedLanguage: Language?
    var isDetectionUncertain: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let title {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Picker("", selection: Binding(
                get: { isAuto ? Self.autoTag : (selectedLanguage?.code ?? "") },
                set: { newTag in
                    if newTag == Self.autoTag {
                        isAuto = true
                        selectedLanguage = nil
                    } else if let lang = Language.language(withCode: newTag) {
                        isAuto = false
                        selectedLanguage = lang
                    }
                }
            )) {
                if allowsAutoDetect {
                    // Show detected language in the label (if any).
                    Text(autoDetectLabel).tag(Self.autoTag)
                }
                ForEach(Language.all) { lang in
                    Text(lang.displayLabel).tag(lang.code)
                }
            }
            .labelsHidden()
            .frame(height: 28)
        }
    }

    /// Label for the auto-detect option: "Auto-Detect" or "Auto-Detect (Spanish)".
    private var autoDetectLabel: String {
        guard allowsAutoDetect && isAuto else { return "Auto-Detect" }
        if let detected = detectedLanguage {
            let confidence = isDetectionUncertain ? ", uncertain" : ""
            return "Auto-Detect (\(detected.englishName)\(confidence))"
        }
        return "Auto-Detect"
    }

    private static let autoTag = "__auto__"
}
