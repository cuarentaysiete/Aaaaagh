// TranslationEngineProtocol.swift
// Domain: abstraction over the MLX translation engine. The UI depends on this
// protocol, never on MLX types directly.
// `public` so the `Aaaaagh` target can conform to / use it across the boundary.

import Foundation

/// A type that can translate text and produce word-level alternatives, using a
/// local model. Implementations must be safe to drive from the MainActor.
public protocol TranslationEngineProtocol: Sendable {
    /// Load the underlying model (called lazily, on demand).
    func load() async throws
    /// Release the model's memory.
    func unload()
    /// True when the model is loaded and ready.
    var isLoaded: Bool { get }
    /// True when a load is currently in flight.
    var isLoading: Bool { get }
    /// Translate a request, streaming the output tokens as they are generated.
    /// `sourceLanguage` is the detected language when `request.sourceLanguage == .auto`.
    func translate(
        _ request: TranslationRequest,
        sourceLanguage: Language?
    ) -> AsyncThrowingStream<String, Error>
    /// Produce up to `request.maximumAlternatives` alternatives for a selected word.
    func wordAlternatives(_ request: WordAlternativeRequest) async throws -> [String]
}
