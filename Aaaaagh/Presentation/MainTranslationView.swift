// MainTranslationView.swift
// Presentation: minimalist dual-pane translator.

import SwiftUI
import AppKit
import Domain

struct MainTranslationView: View {
    @EnvironmentObject var viewModel: TranslatorViewModel
    @State private var showModelSettings = false
    @State private var showAlternatives = false
    @FocusState private var inputHasFocus: Bool

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            languageRow
            Divider()
            panes
            Divider()
            statusBar
        }
        .sheet(isPresented: $showModelSettings) {
            ModelSettingsView()
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button {
                showModelSettings = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "cpu")
                    Text(viewModel.modelStore.activeModel?.displayName ?? "No model")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                showModelSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .help("Model Settings")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Language row

    private var languageRow: some View {
        HStack(spacing: 12) {
            // Source language picker (left half).
            LanguagePickerView(
                title: nil,
                selectedLanguage: Binding(
                    get: { if case .language(let l) = viewModel.sourceLanguageOption { return l }; return nil },
                    set: { lang in
                        viewModel.sourceLanguageOption = lang == nil ? .auto : .language(lang!)
                        viewModel.sourceLanguageChanged()
                    }
                ),
                isAuto: Binding(
                    get: { if case .auto = viewModel.sourceLanguageOption { return true }; return false },
                    set: { isAuto in
                        viewModel.sourceLanguageOption = isAuto ? .auto : .language(.defaultLanguage)
                        viewModel.sourceLanguageChanged()
                    }
                ),
                allowsAutoDetect: true,
                detectedLanguage: viewModel.detectedLanguage,
                isDetectionUncertain: viewModel.detectionIsUncertain
            )
            .frame(maxWidth: .infinity)

            // Swap button (center).
            Button {
                viewModel.swap()
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.body)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.bordered)
            .help("Swap languages and text")

            // Target language picker (right half).
            LanguagePickerView(
                title: nil,
                selectedLanguage: Binding(
                    get: { viewModel.targetLanguage },
                    set: { lang in
                        if let lang {
                            viewModel.targetLanguage = lang
                            viewModel.targetLanguageChanged()
                        }
                    }
                ),
                isAuto: .constant(false),
                allowsAutoDetect: false,
                detectedLanguage: nil,
                isDetectionUncertain: false
            )
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Panes

    private var panes: some View {
        HStack(spacing: 0) {
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
        VStack(spacing: 0) {
            TextEditor(text: $viewModel.inputText)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(8)
                .focused($inputHasFocus)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        inputHasFocus = true
                    }
                }
            // Character count (bottom of input pane).
            Text("\(viewModel.inputText.count)/\(viewModel.maxInputCharacters)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
        }
    }

    private var outputPane: some View {
        VStack(spacing: 0) {
            OutputTextView(
                text: viewModel.outputText,
                onWordSelect: { word, sentence in
                    viewModel.requestAlternativesForWord(word, contextSentence: sentence)
                    showAlternatives = true
                }
            )
            .font(.body)
            .scrollContentBackground(.hidden)
            .padding(8)
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
            // Character count (bottom of output pane).
            Text("\(viewModel.outputText.count)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
        }
    }

    // MARK: - Missing model overlay

    private var missingModelOverlay: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            Text("No model")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }

    // MARK: - Status bar

    private var statusBar: some View {
        HStack(spacing: 8) {
            // Model status (left).
            HStack(spacing: 4) {
                Circle()
                    .fill(viewModel.isModelLoaded ? .green : .orange)
                    .frame(width: 7, height: 7)
                Text(viewModel.modelStore.activeModel?.displayName ?? "No model")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if viewModel.isModelLoaded {
                    Text("· Loaded")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Target language warning (if any).
            if let warning = viewModel.targetLanguageWarning {
                Text(warning)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Spacer()

            // Translation status (right).
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
    }

    private var statusText: String {
        if viewModel.isTranslating { return "Translating…" }
        if !viewModel.statusMessage.isEmpty { return viewModel.statusMessage }
        return "Ready"
    }
}
