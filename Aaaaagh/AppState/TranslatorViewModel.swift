// TranslatorViewModel.swift
// AppState: orchestrates input/output state, streaming, swap, word alternatives,
// character limits, idle model unload, and model registry integration.
//
// Aligned with the Domain + Infrastructure API:
//   - ModelRegistryStore (profile, isActiveModelValid, bundledModelsRoot)
//   - MLXTranslationEngine (translate(_:) -> AsyncThrowingStream<String> of *delta*
//     chunks; wordAlternatives(_:) -> [String]; load(); unload())
//   - TranslationRequest / WordAlternativeRequest (sourceLanguageOption, word, etc.)

import Foundation
import Combine
import AppKit
import Domain

@MainActor
final class TranslatorViewModel: ObservableObject {

    // MARK: - Published state

    @Published var inputText: String = "" {
        didSet {
            // Enforce the max input length (hard limit): trim if over.
            if inputText.count > maxInputCharacters {
                inputText = String(inputText.prefix(maxInputCharacters))
            }
            scheduleRedetect(); invalidateIdleTimer()
        }
    }
    @Published var outputText: String = "" {
        didSet { outputCopied = false }
    }

    @Published var sourceLanguageOption: SourceLanguageOption = .auto
    @Published var targetLanguage: Language = .defaultLanguage

    @Published var detectedLanguage: Language?
    @Published var detectionIsUncertain: Bool = true

    @Published private(set) var isTranslating: Bool = false
    @Published private(set) var isLoadingAlternatives: Bool = false

    @Published var selectedOutputWord: String?
    @Published var wordAlternatives: [String] = []

    @Published var inputCopied: Bool = false
    @Published var outputCopied: Bool = false

    @Published var statusMessage: String = "Ready"

    // MARK: - Collaborators

    let modelStore: ModelRegistryStore
    private let engine: MLXTranslationEngine
    private let detector: LanguageDetectionService
    private var cancellables = Set<AnyCancellable>()

    // Cancellation handles.
    private var translationTask: Task<Void, Never>?
    private var alternativesTask: Task<Void, Never>?

    // Idle unload.
    private var idleWorkItem: DispatchWorkItem?
    private let idleInterval: TimeInterval

    // Copy badge auto-dismiss.
    private var copyBadgeWorkItem: DispatchWorkItem?

    // MARK: - Init

    init(
        modelStore: ModelRegistryStore,
        engine: MLXTranslationEngine,
        detector: LanguageDetectionService = LanguageDetectionService()
    ) {
        self.modelStore = modelStore
        self.engine = engine
        self.detector = detector
        self.idleInterval = TimeInterval(modelStore.profile.idleUnloadSeconds)

        // React to model changes (validity flips, profile changes).
        modelStore.$profile
            .removeDuplicates()
            .sink { [weak self] _ in self?.handleActiveModelChanged() }
            .store(in: &cancellables)

        modelStore.$isActiveModelValid
            .removeDuplicates()
            .sink { [weak self] valid in
                self?.statusMessage = valid ? "Model ready (loads on demand)" : "No valid model"
            }
            .store(in: &cancellables)

        handleActiveModelChanged()
    }

    // MARK: - Derived state

    var maxInputCharacters: Int { modelStore.profile.maxInputCharacters }
    var isModelValid: Bool { modelStore.isActiveModelValid }
    var panesDisabled: Bool { !isModelValid }

    /// The effective source language (resolving `.auto` with detection).
    var effectiveSourceLanguage: SourceLanguageOption {
        switch sourceLanguageOption {
        case .auto:
            if let d = detectedLanguage, !detectionIsUncertain { return .language(d) }
            return .auto
        case .language:
            return sourceLanguageOption
        }
    }

    // MARK: - Detection

    private func scheduleRedetect() {
        Task { @MainActor in
            guard sourceLanguageOption == .auto else {
                detectedLanguage = nil
                detectionIsUncertain = false
                return
            }
            let result = detector.detect(inputText)
            detectedLanguage = result.language
            detectionIsUncertain = result.isUncertain
        }
    }

    // MARK: - Translation (streaming, incremental chunks)

    func translate() {
        guard !panesDisabled else {
            statusMessage = "No valid model. Open Model Settings."
            return
        }
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            statusMessage = "Nothing to translate."
            return
        }

        cancelTranslation()
        cancelAlternatives()

        let request = TranslationRequest(
            text: inputText,
            sourceLanguage: sourceLanguageOption,
            targetLanguage: targetLanguage
        )

        outputText = ""
        isTranslating = true
        statusMessage = "Translating…"
        invalidateIdleTimer()

        // Ensure the model is loaded before streaming.
        let detectedSource = (sourceLanguageOption == .auto)
            ? detectedLanguage
            : { if case .language(let l) = sourceLanguageOption { return l } else { return nil } }()

        translationTask = Task { @MainActor [weak self, engine] in
            guard let self else { return }
            do {
                // Load on demand (no-op if already loaded).
                try await engine.load()
                let stream = engine.translate(request, sourceLanguage: detectedSource)
                for try await chunk in stream {
                    // Engine yields *delta* chunks; append incrementally.
                    self.outputText += chunk
                    self.invalidateIdleTimer()
                }
                self.isTranslating = false
                self.statusMessage = "Done"
            } catch is CancellationError {
                self.isTranslating = false
                self.statusMessage = "Cancelled"
            } catch {
                self.isTranslating = false
                self.statusMessage = "Error: \(error.localizedDescription)"
            }
        }
    }

    func cancelTranslation() {
        translationTask?.cancel()
        translationTask = nil
        isTranslating = false
    }

    // MARK: - Swap

    func swap() {
        cancelTranslation()
        cancelAlternatives()

        let resolvedSource: Language
        switch sourceLanguageOption {
        case .language(let l):
            resolvedSource = l
        case .auto:
            if let d = detectedLanguage, !detectionIsUncertain {
                resolvedSource = d
            } else {
                resolvedSource = targetLanguage
            }
        }

        let previousTarget = targetLanguage
        let newInput = outputText
        outputText = ""

        sourceLanguageOption = .language(resolvedSource)
        if previousTarget.code == resolvedSource.code {
            targetLanguage = (Language.defaultLanguage.code == resolvedSource.code)
                ? Language.all[1]
                : Language.defaultLanguage
        } else {
            targetLanguage = previousTarget
        }

        inputText = newInput
        statusMessage = "Swapped"
        invalidateIdleTimer()
        scheduleRedetect()
    }

    func clearInput() {
        cancelTranslation()
        cancelAlternatives()
        inputText = ""
        outputText = ""
        detectedLanguage = nil
        detectionIsUncertain = true
        selectedOutputWord = nil
        wordAlternatives = []
    }

    // MARK: - Copy

    func copyInput() {
        guard !inputText.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(inputText, forType: .string)
        flashInputCopied()
    }

    func copyOutput() {
        guard !outputText.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(outputText, forType: .string)
        flashOutputCopied()
    }

    private func flashInputCopied() {
        inputCopied = true
        copyBadgeWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.inputCopied = false }
        copyBadgeWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: item)
    }

    private func flashOutputCopied() {
        outputCopied = true
        copyBadgeWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.outputCopied = false }
        copyBadgeWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: item)
    }

    // MARK: - Word alternatives

    func requestAlternativesForWord(_ word: String, contextSentence: String) {
        guard !panesDisabled else { return }
        guard !word.isEmpty else { return }
        cancelAlternatives()

        selectedOutputWord = word
        isLoadingAlternatives = true
        statusMessage = "Looking up alternatives…"

        let sourceLang: Language
        switch effectiveSourceLanguage {
        case .auto: sourceLang = detectedLanguage ?? targetLanguage
        case .language(let l): sourceLang = l
        }

        let request = WordAlternativeRequest(
            selectedWord: word,
            contextSentence: contextSentence,
            sourceLanguage: sourceLang,
            targetLanguage: targetLanguage
        )

        alternativesTask = Task { @MainActor [weak self, engine] in
            guard let self else { return }
            do {
                try await engine.load()
                let alts = try await engine.wordAlternatives(request)
                if self.selectedOutputWord == word {
                    self.wordAlternatives = alts
                }
                self.isLoadingAlternatives = false
                self.statusMessage = "Ready"
            } catch is CancellationError {
                self.isLoadingAlternatives = false
            } catch {
                self.isLoadingAlternatives = false
                self.statusMessage = "Alternatives unavailable"
            }
        }
    }

    func replaceSelectedWord(with alternative: String) {
        guard let word = selectedOutputWord, !word.isEmpty else { return }
        var text = outputText
        var searchRange = text.startIndex..<text.endIndex
        while let range = text.range(of: word, options: [.caseInsensitive, .diacriticInsensitive], range: searchRange) {
            let beforeOK = range.lowerBound == text.startIndex
                || !text[text.index(before: range.lowerBound)].isLetter
                && !text[text.index(before: range.lowerBound)].isNumber
            let afterOK = range.upperBound == text.endIndex
                || !text[text.index(after: range.upperBound)].isLetter
                && !text[text.index(after: range.upperBound)].isNumber
            if beforeOK && afterOK {
                text.replaceSubrange(range, with: alternative)
                break
            }
            searchRange = range.upperBound..<text.endIndex
        }
        outputText = text
        selectedOutputWord = nil
        wordAlternatives = []
    }

    func cancelAlternatives() {
        alternativesTask?.cancel()
        alternativesTask = nil
        isLoadingAlternatives = false
    }

    // MARK: - Model change handling

    private func handleActiveModelChanged() {
        cancelTranslation()
        cancelAlternatives()
        // Rebuild the engine against the (possibly new) model directory.
        let dir = modelStore.profile.localDirectoryURL
        let profile = modelStore.profile
        // The engine is created at VM init; on model change we update it in place.
        engine.update(profile: profile, modelDirectory: dir)
        statusMessage = isModelValid ? "Model ready (loads on demand)" : "No valid model"
        invalidateIdleTimer()
    }

    // MARK: - Idle unload

    func invalidateIdleTimer() {
        idleWorkItem?.cancel()
        guard isModelValid else { return }
        let item = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.engine.unload()
                self?.statusMessage = "Model unloaded (idle)"
            }
        }
        idleWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + idleInterval, execute: item)
    }
}
