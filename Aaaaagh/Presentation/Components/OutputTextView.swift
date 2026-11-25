// OutputTextView.swift
// Presentation/Components: a read-only output text view that supports selecting a
// single word (via click/double-click) and reports the word + its sentence context
// so the parent can fetch contextual alternatives.

import SwiftUI
import AppKit

/// Wraps an `NSTextView` (read-only) to give native word selection + scrolling.
struct OutputTextView: NSViewRepresentable {
    let text: String
    /// Called with (selectedWord, contextSentence) when the user selects a word.
    let onWordSelect: (String, String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let textView = scrollView.documentView as! NSTextView
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.drawsBackground = false
        textView.delegate = context.coordinator
        textView.allowsUndo = false
        context.coordinator.textView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        // Avoid clobbering during an active edit/selection if the text is unchanged.
        if textView.string != text {
            textView.string = text
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: OutputTextView
        weak var textView: NSTextView?

        init(_ parent: OutputTextView) { self.parent = parent }

        // Report the selected word as soon as a selection exists.
        func textDidChange(_ notification: Notification) {
            // Not used (read-only).
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView else { return }
            let range = textView.selectedRange()
            guard range.length > 0 else { return }
            guard let nsRange = Range(range, in: textView.string) else { return }

            let selected = String(textView.string[nsRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !selected.isEmpty else { return }

            // Take the last word of the selection (so clicking a single word works even
            // if the user drags a bit).
            let words = selected.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            let word = words.last.map(String.init) ?? selected

            // Find the sentence containing the selected range for context.
            let sentence = sentence(containing: range, in: textView.string)
            parent.onWordSelect(word, sentence)
        }

        /// Expand the selection to the surrounding sentence (by newline / . ! ? boundaries).
        private func sentence(containing range: NSRange, in text: String) -> String {
            guard let full = Range(range, in: text) else { return text }
            var start = full.lowerBound
            var end = full.upperBound

            // Walk backward to sentence/paragraph start.
            if let idx = text[...start].lastIndex(where: { $0 == "\n" || $0 == "." || $0 == "!" || $0 == "?" }) {
                start = text.index(after: idx)
            } else {
                start = text.startIndex
            }
            // Walk forward to sentence/paragraph end.
            if let idx = text[end...].firstIndex(where: { $0 == "\n" || $0 == "." || $0 == "!" || $0 == "?" }) {
                end = text.index(after: idx)
            } else {
                end = text.endIndex
            }
            return String(text[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}
