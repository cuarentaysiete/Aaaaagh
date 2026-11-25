// TranslationEngineProtocol.swift
// Domain: the contract a translation engine (MLX today, other backends later) fulfils.
// No SwiftUI, no MLX imports here — pure domain types only.

import Foundation

/// A backend that can stream translations and produce contextual word alternatives.
///
/// Implementations must:
///  - Load models lazily on demand.
///  - Stream incremental text chunks via `AsyncThrowingStream`.
///  - Honour Swift task cancellation cleanly (no stale chunks after cancel).
///  - Allow the loaded model to be released.
protocol TranslationEngineProtocol: Sendable {
    /// Load the current model (idempotent).
    func load() async throws
    /// Release any currently loaded model from memory.
    func unload()
    /// Stream translated text as incremental chunks.
    func translate(
        _ request: TranslationRequest,
        sourceLanguage: Language?
    ) -> AsyncThrowingStream<String, Error>
    /// Return a few contextual alternatives for a single word in the target language.
    func wordAlternatives(_ request: WordAlternativeRequest) async throws -> [String]
}
