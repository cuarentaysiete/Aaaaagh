// MainTranslationView.swift
// Presentation: dual panes (input/output), grey-out when no model, swap, per-pane
// language dropdowns + auto-detect badge, character counter, copy buttons with
// "Copied!" overlay, word-selection for alternatives, and the status bar.

import SwiftUI
import AppKit
import Domain

struct MainTranslationView: View {
    @EnvironmentObject var viewModel: TranslatorViewModel
    @State private var showModelSettings = false

    // Tracking which output word is selected for the alternatives popover.
    @State private var showAlternatives = false

    // Focus management: the input text editor should have focus on launch.
    @FocusState private var inputHasFocus: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            languageBar
            Divider()
            panes
            Divider()
            statusBar
        }
        .sheet(isPresented: $showModelSettings) {
            ModelSettingsView()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "character.bubble")
                .font(.title3)
            Text("Aaaaagh")
                .font(.headline)

            Spacer()

            if let model = viewModel.modelStore.activeModel {
                HStack(spacing: 6) {
                    Image(systemName: "cpu")
                    Text(model.displayName)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary, in: Capsule())
            }

            Button {
                showModelSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .help("Model Settings")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Language bar

    private var languageBar: some View {
        HStack(spacing: 12) {
            // Input pane: auto-detect allowed.
            LanguagePickerView(
                title: "From",
                selectedLanguage: Binding(
                    get: { if case .language(let l) = viewModel.sourceLanguageOption { return l }; return nil },
                    set: { lang in viewModel.sourceLanguageOption = lang == nil ? .auto : .language(lang!) }
                ),
                isAuto: Binding(
                    get: { if case .auto = viewModel.sourceLanguageOption { return true }; return false },
                    set: { isAuto in viewModel.sourceLanguageOption = isAuto ? .auto : .language(.defaultLanguage) }
                ),
                allowsAutoDetect: true,
                detectedLanguage: viewModel.detectedLanguage,
                isDetectionUncertain: viewModel.detectionIsUncertain
            )
            .frame(maxWidth: 280)

            Button {
                viewModel.swap()
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.title3)
            }
            .help("Swap text and languages (⇄)")

            // Output pane: concrete language only.
            LanguagePickerView(
                title: "To",
                selectedLanguage: Binding(
                    get: { viewModel.targetLanguage },
                    set: { lang in
                        if let lang { viewModel.targetLanguage = lang }
                    }
                ),
                isAuto: .constant(false),
                allowsAutoDetect: false,
                detectedLanguage: nil,
                isDetectionUncertain: false
            )
            .frame(maxWidth: 280)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Panes

    private var panes: some View {
        HStack(spacing: 0) {
            // The input pane is ALWAYS editable (the user can type/paste text
            // regardless of whether a model is loaded). Only the output pane and
            // the Translate button are gated on model availability.
            inputPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            outputPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .disabled(viewModel.panesDisabled)
        }
        .overlay {
            if viewModel.panesDisabled {
                missingModelOverlay
            }
        }
    }

    private var inputPane: some View {
        VStack(spacing: 8) {
            TextEditor(text: $viewModel.inputText)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))
                .focused($inputHasFocus)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        inputHasFocus = true
                    }
                }

            HStack {
                // Live character counter.
                Text("\(viewModel.inputText.count)/\(viewModel.maxInputCharacters)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(
                        viewModel.inputText.count > viewModel.maxInputCharacters ? .red : .secondary
                    )

                Spacer()

                Button("Clear") { viewModel.clearInput() }
                    .controlSize(.small)

                Button {
                    viewModel.copyInput()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .controlSize(.small)
                .disabled(viewModel.inputText.isEmpty)
            }
        }
        .padding(12)
        .overlay(alignment: .bottomTrailing) {
            if viewModel.inputCopied {
                CopiedBadge()
                    .padding(10)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: viewModel.inputCopied)
    }

    private var outputPane: some View {
        VStack(spacing: 8) {
            // Rich output text with word selection for alternatives.
            OutputTextView(
                text: viewModel.outputText,
                onWordSelect: { word, sentence in
                    viewModel.requestAlternativesForWord(word, contextSentence: sentence)
                    showAlternatives = true
                }
            )
            .font(.body)
            .scrollContentBackground(.hidden)
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))

            HStack {
                if viewModel.isTranslating {
                    ProgressView().controlSize(.small)
                    Text("Translating…").font(.caption).foregroundStyle(.secondary)
                } else if viewModel.selectedOutputWord != nil {
                    Text("Select an alternative for “\(viewModel.selectedOutputWord!)”")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()

                Button {
                    viewModel.copyOutput()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.body)
                }
                .controlSize(.regular)
                .disabled(viewModel.outputText.isEmpty)
                .popover(isPresented: $showAlternatives, arrowEdge: .top) {
                    WordAlternativesPopover(
                        selectedWord: viewModel.selectedOutputWord ?? "",
                        alternatives: viewModel.wordAlternatives,
                        isLoading: viewModel.isLoadingAlternatives
                    ) { alternative in
                        viewModel.replaceSelectedWord(with: alternative)
                        showAlternatives = false
                    }
                }
            }
        }
        .padding(12)
        .overlay(alignment: .bottomTrailing) {
            if viewModel.outputCopied {
                CopiedBadge()
                    .padding(10)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: viewModel.outputCopied)
    }

    // MARK: - Missing model overlay

    private var missingModelOverlay: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title)
                .foregroundStyle(.orange)
            Text("No valid model available")
                .font(.headline)
            Text("Both panes are disabled until a valid local model is configured.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("Open Model Settings") { showModelSettings = true }
                .buttonStyle(.borderedProminent)
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }

    // MARK: - Status bar

    private var statusBar: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(viewModel.isModelValid ? .green : .orange)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var statusText: String {
        var parts: [String] = []
        parts.append(viewModel.statusMessage)
        parts.append(viewModel.isModelValid ? "Offline" : "No model")
        if let m = viewModel.modelStore.activeModel {
            parts.append(m.displayName)
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - "Copied!" badge

private struct CopiedBadge: View {
    var body: some View {
        Label("Copied!", systemImage: "checkmark.circle.fill")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.green.opacity(0.9), in: Capsule())
            .foregroundStyle(.white)
    }
}
