// ModelSettingsView.swift
// Presentation: model selection, folder picker, and missing/invalid model guidance.

import SwiftUI
import AppKit
import Domain

struct ModelSettingsView: View {
    @EnvironmentObject var viewModel: TranslatorViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var scanMessage: String = ""
    @State private var scanIsError: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Model Settings")
                .font(.title2.weight(.semibold))

            // Active model summary.
            if let model = viewModel.modelStore.activeModel {
                HStack {
                    Label(model.displayName, systemImage: "cpu")
                    Spacer()
                    if viewModel.modelStore.isModelValid {
                        Text("Valid").font(.caption).foregroundStyle(.green)
                    } else {
                        Text("Invalid / Missing").font(.caption).foregroundStyle(.red)
                    }
                }
            } else {
                Text("No model configured.")
                    .foregroundStyle(.secondary)
            }

            // Folder picker.
            HStack(spacing: 10) {
                Button("Choose Model Folder…") {
                    chooseFolder()
                }
                Button("Reset to Default") {
                    viewModel.modelStore.resetToDefault()
                    scanMessage = "Reset to default EuroLLM 1.7B profile."
                    scanIsError = false
                }
                .disabled(viewModel.modelStore.activeModel?.id == "eurolm-1.7b-instruct-4bit")
            }

            if !scanMessage.isEmpty {
                Text(scanMessage)
                    .font(.callout)
                    .foregroundStyle(scanIsError ? .red : .secondary)
                    .textSelection(.enabled)
            }

            // Missing-model guidance.
            if !viewModel.modelStore.isModelValid {
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("No valid model in the selected folder.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Pick a folder containing config.json, tokenizer files and .safetensors weights (e.g. EuroLLM-1.7B-Instruct-4bit). Until then, the translation panes stay disabled.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(4)
                }
            }

            Spacer()

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 440, minHeight: 280)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.message = "Select a folder containing an MLX model (config.json, tokenizer, .safetensors)."

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let scanner = LocalModelScanner()
        switch scanner.scan(url) {
        case .valid:
            viewModel.modelStore.setProfileForFolder(url)
            scanMessage = "Selected and activated: \(url.lastPathComponent)"
            scanIsError = false
        case .missing:
            scanMessage = "Folder not found."
            scanIsError = true
        case .invalid(let missing):
            scanMessage = "Folder is not a valid MLX model. Missing: \(missing.joined(separator: ", "))"
            scanIsError = true
        }
    }
}
