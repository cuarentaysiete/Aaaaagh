// LanguagePickerView.swift
// Presentation/Components: per-pane language dropdown + auto-detect badge for the input pane.

import SwiftUI
import Domain

/// A compact language selector.
///
/// - For the *input* pane: includes an "Auto-Detect" option plus every language.
/// - For the *output* pane: only concrete languages (never auto).
struct LanguagePickerView: View {
    /// Optional title (nil = no title, just the picker).
    let title: String?
    /// The currently selected language (nil for auto).
    @Binding var selectedLanguage: Language?
    /// True when the "Auto-Detect" option is active (input pane only).
    @Binding var isAuto: Bool
    /// Whether to offer the auto option at all (input pane = true).
    var allowsAutoDetect: Bool
    /// Detected language + uncertainty, shown as a badge when auto is active.
    var detectedLanguage: Language?
    var isDetectionUncertain: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Title (only if provided).
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
                    Text("Auto-Detect").tag(Self.autoTag)
                }
                ForEach(Language.all) { lang in
                    Text(lang.displayLabel).tag(lang.code)
                }
            }
            .labelsHidden()

            // Auto-detect badge (inline, compact).
            if allowsAutoDetect && isAuto {
                if let detected = detectedLanguage {
                    Text(isDetectionUncertain
                         ? "(\(detected.englishName), uncertain)"
                         : "(\(detected.englishName))")
                        .font(.caption2)
                        .foregroundStyle(isDetectionUncertain ? .orange : .secondary)
                } else {
                    Text("(no detection)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private static let autoTag = "__auto__"
}
