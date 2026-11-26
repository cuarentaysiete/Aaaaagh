// MLXTranslationEngine.swift
// Concrete TranslationEngine implementation backed by mlx-swift-lm (LLMModelFactory,
// ChatSession). Loads a local GGUF/MLX model directory, streams tokens, and exposes
// unloading. The model is treated as a deterministic translation engine via terse,
// non-conversational prompts (see PromptBuilder).
//
// API notes (mlx-swift-lm, current stable):
//   - `LLMModelFactory.shared.loadContainer(from:using:configuration:)` loads a local
//     directory via `ModelConfiguration(directory:)` + the `#huggingFaceTokenizerLoader()`
//     macro (from MLXHuggingFace).
//   - `ChatSession(model:instructions:generateParameters:)` + `streamResponse(to:)`
//     applies the chat template and streams `String` chunks.

import Foundation
import MLX
import MLXNN
import MLXLMCommon
import MLXLLM
import MLXHuggingFace
import HuggingFace
import Tokenizers
import Domain

final class MLXTranslationEngine: TranslationEngineProtocol, @unchecked Sendable {
    // MARK: - State

    private var profile: ModelProfile
    private var modelDirectory: URL

    private var modelContainer: ModelContainer?
    private var loadingTask: Task<Void, Error>?

    private let stateLock = NSLock()
    private var _isLoading = false

    var isLoading: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _isLoading
    }

    var isLoaded: Bool {
        modelContainer != nil
    }

    // MARK: - Init

    init(profile: ModelProfile, modelDirectory: URL) {
        self.profile = profile
        self.modelDirectory = modelDirectory
    }

    // MARK: - Loading

    func load() async throws {
        NSLog("[MLX] load() called, isLoaded: \(isLoaded), modelDir: \(modelDirectory.path)")
        // Fast path: already loaded.
        if isLoaded { return }

        // If a load is already in flight, await it (don't start a second one).
        stateLock.lock()
        if let existing = loadingTask {
            stateLock.unlock()
            try await existing.value
            return
        }
        stateLock.unlock()

        let task = Task { [self] in
            set(true)
            NSLog("[MLX] load task started")
            defer { set(false) }

            // ModelConfiguration pointing at the local directory (offline; no network).
            let configuration = ModelConfiguration(
                directory: modelDirectory,
                eosTokenIds: Set(profile.stopTokenIDs)
            )
            NSLog("[MLX] configuration: directory=\(modelDirectory.path)")

            // Load the model + tokenizer from the local directory.
            do {
                NSLog("[MLX] calling LLMModelFactory.loadContainer...")
                let container = try await LLMModelFactory.shared.loadContainer(
                    from: #hubDownloader(),
                    using: #huggingFaceTokenizerLoader(),
                    configuration: configuration
                )
                NSLog("[MLX] model loaded successfully")
                self.modelContainer = container
            } catch {
                NSLog("[MLX] load() FAILED: \(error)")
                throw error
            }
        }

        stateLock.lock()
        loadingTask = task
        stateLock.unlock()

        // Clear the loading task handle when the task completes.
        defer {
            stateLock.lock()
            loadingTask = nil
            stateLock.unlock()
        }

        try await task.value
        NSLog("[MLX] load() completed")
    }

    func unload() {
        stateLock.lock()
        loadingTask = nil
        stateLock.unlock()
        modelContainer = nil
    }

    /// Re-point the engine at a different model (e.g. after the user picks a new
    /// folder in settings). Drops any loaded container first.
    func update(profile: ModelProfile, modelDirectory: URL) {
        stateLock.lock()
        self.profile = profile
        self.modelDirectory = modelDirectory
        modelContainer = nil
        loadingTask = nil
        stateLock.unlock()
    }

    private func set(_ newValue: Bool) {
        stateLock.lock()
        _isLoading = newValue
        stateLock.unlock()
    }

    // MARK: - Translation (streaming)

    func translate(
        _ request: TranslationRequest,
        sourceLanguage: Language?
    ) -> AsyncThrowingStream<String, Error> {
        // Capture the loaded container and profile up front (avoids data races in the
        // nonisolated Task, and fails fast if the model isn't loaded).
        guard let container = modelContainer else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: TranslationError.modelNotLoaded)
            }
        }
        let profile = self.profile
        NSLog("[MLXTranslationEngine] translate(): model loaded, building prompts")

        // Always pass the resolved source language (even if it was auto-detected).
        // This makes the prompt more deterministic: "Translate from X into Y" instead of
        // "Detect the source language automatically".
        let system = PromptBuilder.systemPrompt(
            from: sourceLanguage,
            to: request.targetLanguage,
            modelStyle: profile.promptStyle
        )
        let userPrompt = PromptBuilder.translationPrompt(
            text: request.text,
            target: request.targetLanguage,
            source: sourceLanguage,
            modelStyle: profile.promptStyle
        )
        let params = self.generateParameters(maxTokens: profile.maxOutputTokens)

        NSLog("[MLXTranslationEngine] system prompt: \(system.prefix(120))")
        NSLog("[MLXTranslationEngine] user prompt: \(userPrompt.prefix(120))")

        return AsyncThrowingStream { continuation in
            let task = Task {
                var chunkCount = 0
                do {
                    let session = ChatSession(
                        container,
                        instructions: system,
                        generateParameters: params
                    )
                    NSLog("[MLXTranslationEngine] ChatSession created, starting streamResponse")
                    for try await chunk in session.streamResponse(to: userPrompt) {
                        chunkCount += 1
                        if chunkCount <= 3 {
                            NSLog("[MLXTranslationEngine] chunk \(chunkCount): \(chunk.prefix(80))")
                        }
                        try Task.checkCancellation()
                        continuation.yield(chunk)
                    }
                    NSLog("[MLXTranslationEngine] stream finished, total chunks: \(chunkCount)")
                    continuation.finish()
                } catch {
                    NSLog("[MLXTranslationEngine] stream error: \(error), chunks so far: \(chunkCount)")
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    // MARK: - Word alternatives (non-streaming)

    func wordAlternatives(_ request: WordAlternativeRequest) async throws -> [String] {
        guard let container = self.modelContainer else {
            throw TranslationError.modelNotLoaded
        }

        let system = PromptBuilder.wordAlternativeSystemPrompt(modelStyle: profile.promptStyle)
        let userPrompt = PromptBuilder.wordAlternativePrompt(
            word: request.selectedWord,
            contextSentence: request.contextSentence,
            source: request.sourceLanguage,
            target: request.targetLanguage,
            count: request.maximumAlternatives,
            modelStyle: profile.promptStyle
        )

        let params = self.generateParameters(maxTokens: min(256, profile.maxOutputTokens))
        let session = ChatSession(
            container,
            instructions: system,
            generateParameters: params
        )

        var output = ""
        for try await chunk in session.streamResponse(to: userPrompt) {
            output += chunk
        }
        return parseAlternatives(output, word: request.selectedWord)
    }

    // MARK: - Helpers

    private func generateParameters(maxTokens: Int) -> GenerateParameters {
        GenerateParameters(
            maxTokens: maxTokens,
            temperature: 0.3,
            topP: 0.9,
            repetitionPenalty: 1.05
        )
    }

    /// Strip a leading line (in case the model still echoes a header) and parse the
    /// alternatives, one per line, de-duplicated and capped.
    private func parseAlternatives(_ raw: String, word: String) -> [String] {
        var lines = raw.split(whereSeparator: { $0.isNewline })
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Drop a possible "Alternatives for …:" style header on the first line.
        if let first = lines.first,
           first.lowercased().contains("alternative") || first.lowercased().contains("for") {
            lines.removeFirst()
        }

        var seen = Set<String>()
        var result: [String] = []
        for line in lines {
            // Strip a leading bullet or numbering.
            let cleaned = line
                .replacingOccurrences(of: "^[•\\-\\*\\s]*", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            let lower = cleaned.lowercased()
            guard !cleaned.isEmpty,
                  !lower.contains("{"), !lower.contains("}"), !lower.contains("[") else { continue }
            // Skip lines that are clearly prose rather than a single word/short phrase.
            guard cleaned.split(whereSeparator: { $0 == " " }).count <= 5 else { continue }
            if seen.insert(lower).inserted {
                result.append(cleaned)
            }
            if result.count >= 20 { break }
        }
        return result
    }
}

// MARK: - Errors

public enum TranslationError: LocalizedError {
    case modelNotLoaded
    case loadFailed(underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "The model is not loaded."
        case .loadFailed(let underlying):
            return "Model load failed: \(underlying.localizedDescription)"
        }
    }
}
