// ModelProfile.swift
// Domain: a configurable description of a local MLX model.
// Nothing here hardcodes paths or prompt strings inside the UI layer.
// All members are `public` so the `Aaaaagh` target can use them.

import Foundation

/// The prompt-building strategy used by a profile. Keeping it a domain enum means
/// the UI never sees prompt text, and swapping models only means swapping profiles.
public enum PromptStyle: String, Codable, CaseIterable, Sendable {
    /// Terse, deterministic, non-conversational translation prompts (the correct
    /// choice for `Instruct` models used strictly as a translation engine).
    case terseEngine
    /// A looser, more conversational chat-style prompt (reserved for future models).
    case conversational
}

/// A fully self-describing local model. The engine loads `localDirectoryURL`
/// lazily and applies sampling limits / prompt style from here.
public struct ModelProfile: Identifiable, Equatable, Codable, Sendable {
    /// Stable identifier, e.g. `"eurolm-1.7b-instruct-4bit"`.
    public var id: String
    public var displayName: String
    /// Absolute or app-relative URL to the folder containing config.json,
    /// tokenizer files and .safetensors weights.
    public var localDirectoryURL: URL
    public var promptStyle: PromptStyle
    /// Max tokens of context the model supports (from config.json max_position_embeddings).
    public var contextWindow: Int
    /// Practical character budget for user input, derived from `contextWindow`.
    public var maxInputCharacters: Int
    /// Hard cap on generated tokens per translation (safety, on top of EOS).
    public var maxOutputTokens: Int
    /// Sampling temperature (low for deterministic translation).
    public var samplingTemperature: Double
    /// Nucleus sampling threshold.
    public var topP: Double
    /// Extra stop-token IDs (in addition to the model's built-in EOS).
    public var stopTokenIDs: Set<Int>
    /// Seconds of inactivity after which the engine should release the model.
    public var idleUnloadSeconds: Int

    public init(
        id: String,
        displayName: String,
        localDirectoryURL: URL,
        promptStyle: PromptStyle = .terseEngine,
        contextWindow: Int,
        maxInputCharacters: Int,
        maxOutputTokens: Int = 512,
        samplingTemperature: Double = 0.3,
        topP: Double = 0.9,
        stopTokenIDs: Set<Int> = [],
        idleUnloadSeconds: Int = 120
    ) {
        self.id = id
        self.displayName = displayName
        self.localDirectoryURL = localDirectoryURL
        self.promptStyle = promptStyle
        self.contextWindow = contextWindow
        self.maxInputCharacters = maxInputCharacters
        self.maxOutputTokens = maxOutputTokens
        self.samplingTemperature = samplingTemperature
        self.topP = topP
        self.stopTokenIDs = stopTokenIDs
        self.idleUnloadSeconds = idleUnloadSeconds
    }
}

extension ModelProfile {
    /// The default profile for the bundled EuroLLM 1.7B Instruct (4-bit) model.
    ///
    /// `contextWindow` = 4096 (from the model's config.json). `maxInputCharacters`
    /// = 3000 (safe budget with headroom for prompt + output, CJK-safe). EOS for
    /// this model is token id 4 (`</s>`), which MLX also honors from the model's
    /// own generation config; listed here as a belt-and-braces stop set.
    public static func defaultEuroLLM(bundledModelsRoot: URL) -> ModelProfile {
        let dir = bundledModelsRoot
            .appendingPathComponent("EuroLLM-1.7B-Instruct-4bit", isDirectory: true)
        return ModelProfile(
            id: "eurolm-1.7b-instruct-4bit",
            displayName: "EuroLLM 1.7B (4-bit)",
            localDirectoryURL: dir,
            promptStyle: .terseEngine,
            contextWindow: 4096,
            maxInputCharacters: 3000,
            maxOutputTokens: 512,
            samplingTemperature: 0.3,
            topP: 0.9,
            stopTokenIDs: [4],
            idleUnloadSeconds: 120
        )
    }

    /// Compute a safe input-character budget from a token context window.
    public static func practicalCharacterBudget(
        maxContextTokens: Int,
        reservedPromptTokens: Int = 512,
        outputShare: Double = 0.4,
        charsPerToken: Double = 1.4
    ) -> Int {
        let availableForInput = max(0, maxContextTokens - reservedPromptTokens)
        let inputTokens = Int(Double(availableForInput) * (1.0 - outputShare))
        let chars = Int(Double(inputTokens) * charsPerToken)
        return max(0, chars)
    }
}
