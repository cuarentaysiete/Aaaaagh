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

    private let profile: ModelProfile
    private let modelDirectory: URL

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
        if isLoaded { return }
        if let loadingTask {
            try await loadingTask.value
            return
        }

        let task = Task { [self] in
            set isLoading(true)
            defer { set isLoading(false) }

            // ModelConfiguration pointing at the local directory (offline; no network).
            let configuration = ModelConfiguration(
                directory: modelDirectory,
                eosTokenIds: Set(profile.stopTokenIDs)
            )

            // Load the model + tokenizer from the local directory. The `#hubDownloader`
            // macro isn't needed because the configuration is a local directory; the
            // tokenizer loader reads tokenizer files from the same directory.
            let container = try await LLMModelFactory.shared.loadContainer(
                from: #hubDownloader(HubClient()),
                using: #huggingFaceTokenizerLoader(),
                configuration: configuration
            )

            self.modelContainer = container
        }

        stateLock.lock()
        if loadingTask == nil { loadingTask = task }
        stateLock.unlock()

        defer { stateLock.lock(); loadingTask = nil; stateLock.unlock() }
        try await task.value
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
        AsyncThrowingStream { continuation in
            let task = Task {
                guard let container = self.modelContainer else {
                    throw TranslationError.modelNotLoaded
                }

                // Build the chat session with a terse, non-conversational system prompt.
                let system = PromptBuilder.systemPrompt(
                    from: request.sourceLanguage == .auto ? nil : sourceLanguage,
                    to: request.targetLanguage,
                    modelStyle: self.profile.promptStyle
                )

                let userPrompt = PromptBuilder.translationPrompt(
                    text: request.text,
                    target: request.targetLanguage,
                    source: request.sourceLanguage == .auto ? nil : sourceLanguage,
                    modelStyle: self.profile.promptStyle
                )

                let params = self.generateParameters(maxTokens: self.profile.maxOutputTokens)
                let session = ChatSession(
                    container,
                    instructions: system,
                    generateParameters: params
                )

                // Fresh session per request: translation is stateless, so we don't
                // replay the previous turn's history (keeps the KV cache small).
                for try await chunk in session.streamResponse(to: userPrompt) {
                    try Task.checkCancellation()
                    continuation.yield(chunk)
                }
                continuation.finish()
            }
            task.resume()
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
