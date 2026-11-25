// ModelRegistryStore.swift
// Infrastructure/Models: persistence of the chosen model + settings via UserDefaults.

import Foundation
import Domain

/// Persists which model is selected and per-model generation settings in
/// `UserDefaults`. Keeps the UI model-agnostic: it only stores a `ModelProfile`.
final class ModelRegistryStore: ObservableObject {

    // MARK: - Constants

    private enum Keys {
        static let selectedModelID = "selectedModelID"
        static let selectedModelDirectory = "selectedModelDirectory"
        static let promptStyle = "promptStyle"
        static let samplingTemperature = "samplingTemperature"
        static let topP = "topP"
        static let maxOutputTokens = "maxOutputTokens"
        static let idleUnloadSeconds = "idleUnloadSeconds"
        static let stopTokenIDs = "stopTokenIDs"
    }

    // MARK: - Published state

    @Published var profile: ModelProfile
    @Published var isActiveModelValid: Bool = false

    // MARK: - Defaults

    let bundledModelsRoot: URL
    private let defaults: UserDefaults

    init(
        bundledModelsRoot: URL,
        defaults: UserDefaults = .standard
    ) {
        self.bundledModelsRoot = bundledModelsRoot
        self.defaults = defaults
        self.profile = ModelProfile.defaultEuroLLM(bundledModelsRoot: bundledModelsRoot)
        load()
    }

    // MARK: - Load / Save

    func load() {
        guard defaults.object(forKey: Keys.selectedModelID) != nil else {
            // First launch: validate the default bundled profile.
            revalidate()
            return
        }

        let id = defaults.string(forKey: Keys.selectedModelID) ?? ModelProfile.defaultEuroLLM(bundledModelsRoot: bundledModelsRoot).id
        let dirStr = defaults.string(forKey: Keys.selectedModelDirectory)
        let dir = dirStr.flatMap(URL.init(string:)) ?? ModelProfile.defaultEuroLLM(bundledModelsRoot: bundledModelsRoot).localDirectoryURL

        var p = ModelProfile.defaultEuroLLM(bundledModelsRoot: bundledModelsRoot)
        p.id = id
        p.localDirectoryURL = dir

        if let style = defaults.string(forKey: Keys.promptStyle),
           let s = PromptStyle(rawValue: style) {
            p.promptStyle = s
        }
        p.samplingTemperature = defaults.object(forKey: Keys.samplingTemperature) as? Double ?? 0.3
        p.topP = defaults.object(forKey: Keys.topP) as? Double ?? 0.9
        p.maxOutputTokens = defaults.object(forKey: Keys.maxOutputTokens) as? Int ?? 512
        p.idleUnloadSeconds = defaults.object(forKey: Keys.idleUnloadSeconds) as? Int ?? 120
        p.stopTokenIDs = Set(defaults.array(forKey: Keys.stopTokenIDs).compactMap { $0 as? Int })

        profile = p
        revalidate()
    }

    func save() {
        defaults.set(profile.id, forKey: Keys.selectedModelID)
        defaults.set(profile.localDirectoryURL.absoluteString, forKey: Keys.selectedModelDirectory)
        defaults.set(profile.promptStyle.rawValue, forKey: Keys.promptStyle)
        defaults.set(profile.samplingTemperature, forKey: Keys.samplingTemperature)
        defaults.set(profile.topP, forKey: Keys.topP)
        defaults.set(profile.maxOutputTokens, forKey: Keys.maxOutputTokens)
        defaults.set(profile.idleUnloadSeconds, forKey: Keys.idleUnloadSeconds)
        defaults.set(Array(profile.stopTokenIDs).map { NSNumber(value: $0) }, forKey: Keys.stopTokenIDs)
    }

    // MARK: - Selection

    /// Point the active profile at an arbitrary model folder (e.g. picked in UI).
    func select(modelDirectoryURL url: URL) {
        let scanner = LocalModelScanner()
        switch scanner.scan(url) {
        case .valid:
            profile.localDirectoryURL = url
            // Derive a stable id from the folder name.
            profile.id = url.lastPathComponent.lowercased()
            profile.displayName = url.lastPathComponent
            revalidate()
            save()
        case .missing, .invalid:
            revalidate()
        }
    }

    /// Convenience used by the settings UI after a folder pick.
    func setProfileForFolder(_ url: URL) {
        select(modelDirectoryURL: url)
    }

    func resetToDefault() {
        profile = ModelProfile.defaultEuroLLM(bundledModelsRoot: bundledModelsRoot)
        revalidate()
        save()
    }

    // MARK: - Validation

    var activeModel: ModelProfile? { profile }
    var isModelValid: Bool { isActiveModelValid }

    private func revalidate() {
        let scanner = LocalModelScanner()
        let result = scanner.scan(profile.localDirectoryURL)
        isActiveModelValid = (result == .valid)
    }
}
