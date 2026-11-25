// WordAlternativesPopover.swift
// Presentation/Components: lightweight popover listing contextual alternatives
// for the selected output word. Choosing one replaces the word in place.

import SwiftUI
import Domain

struct WordAlternativesPopover: View {
    let selectedWord: String
    let alternatives: [String]
    let isLoading: Bool
    /// Called when the user picks an alternative (the current word is the implicit first).
    let onChoose: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Alternatives for “\(selectedWord)”")
                .font(.caption.weight(.semibold))

            if isLoading {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Loading…").font(.caption).foregroundStyle(.secondary)
                }
            } else {
                // The current word is always an option (keep as-is).
                buttonRow(label: selectedWord, isCurrent: true) {
                    onChoose(selectedWord)
                }
                ForEach(alternatives, id: \.self) { alt in
                    buttonRow(label: alt, isCurrent: false) {
                        onChoose(alt)
                    }
                }
                if alternatives.isEmpty {
                    Text("No alternatives found.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .frame(width: 220, alignment: .leading)
    }

    private func buttonRow(label: String, isCurrent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isCurrent ? "checkmark" : "arrow.uturn.up")
                    .font(.caption2)
                    .foregroundStyle(isCurrent ? .green : .secondary)
                Text(label)
                    .font(.callout)
                    .lineLimit(1)
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}
