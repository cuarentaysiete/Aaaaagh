// LocalModelScanner.swift
// Infrastructure/Models: validates that a local MLX model folder exists and is
// complete (config.json, tokenizer files, .safetensors weights).

import Foundation

/// The result of scanning a model directory.
enum ModelAvailability: Equatable, Sendable {
    /// The folder exists and contains all required artifacts.
    case valid
    /// The folder does not exist.
    case missing
    /// The folder exists but one or more required artifacts are absent.
    case invalid(missingArtifacts: [String])
}

/// Stateless helper that knows how to validate MLX model folders.
struct LocalModelScanner: Sendable {
    /// Artifacts every valid MLX model folder must contain (by name, recursively).
    static let requiredArtifacts: [String] = [
        "config.json",
        "model.safetensors",   // or split shards: model-00001-of-0000N.safetensors
    ]

    static let requiredTokenizerFiles: [String] = [
        "tokenizer.json",      // or tokenizer.model / tokenizer_config.json
        "tokenizer_config.json",
    ]

    /// Scan `directoryURL` and report whether it is a usable MLX model folder.
    func scan(_ directoryURL: URL) -> ModelAvailability {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return .missing
        }

        // Collect all file names in the folder (top level is enough for these).
        let contents = (try? fm.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)) ?? []
        let names = Set(contents.map { $0.lastPathComponent.lowercased() })

        var missing: [String] = []

        // config.json is mandatory.
        if !names.contains("config.json") { missing.append("config.json") }

        // At least one .safetensors weight file.
        let hasSafetensors = names.contains { name in
            name.hasSuffix(".safetensors")
        }
        if !hasSafetensors { missing.append("model.safetensors") }

        // At least one tokenizer artifact.
        let hasTokenizer = names.contains { name in
            name == "tokenizer.json" || name.hasSuffix("tokenizer.model") || name == "tokenizer_config.json"
        }
        if !hasTokenizer { missing.append("tokenizer.json / tokenizer.model") }

        if missing.isEmpty { return .valid }
        return .invalid(missingArtifacts: missing)
    }

    /// Read `max_position_embeddings` from a model's `config.json`, if present.
    func maxContextTokens(in directoryURL: URL) -> Int? {
        let configURL = directoryURL.appendingPathComponent("config.json")
        guard let data = try? Data(contentsOf: configURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let value = json["max_position_embeddings"] as? Int
        else { return nil }
        return value
    }
}
