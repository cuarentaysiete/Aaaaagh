// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Aaaaagh",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        // Core MLX. `from:` lets SPM pick the highest 0.33.x+ that is compatible
        // with the chosen mlx-swift-lm version (rather than pinning 0.33.0 exactly,
        // whose generated Metal kernels fail to compile under Xcode 27.2).
        .package(url: "https://github.com/ml-explore/mlx-swift.git", from: "0.33.0"),
        // High-level LLM loading + ChatSession (MLXLLM, MLXLMCommon, MLXHuggingFace).
        .package(url: "https://github.com/ml-explore/mlx-swift-lm.git", from: "3.33.0"),
        // HuggingFace Hub client (HubClient) used by the #hubDownloader macro.
        .package(url: "https://github.com/huggingface/swift-huggingface.git", from: "0.9.0"),
        // Tokenizers (AutoTokenizer) — required by the #huggingFaceTokenizerLoader
        // macro and by MLXLMCommon.Container. Separate package from swift-huggingface.
        .package(url: "https://github.com/huggingface/swift-transformers.git", from: "1.3.0")
    ],
    targets: [
        // Pure domain layer: NO SwiftUI, NO MLX imports.
        .target(
            name: "Domain",
            path: "Sources/Domain"
        ),
        // App + infrastructure + presentation.
        .executableTarget(
            name: "Aaaaagh",
            dependencies: [
                "Domain",
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "MLXHuggingFace", package: "mlx-swift-lm"),
                .product(name: "HuggingFace", package: "swift-huggingface"),
                // AutoTokenizer / Tokenizers — required by MLXLMCommon.Container
                // and the #huggingFaceTokenizerLoader macro. Lives in
                // swift-transformers (NOT swift-huggingface).
                .product(name: "Tokenizers", package: "swift-transformers"),
            ],
            path: "Aaaaagh",
            resources: [
                .copy("Resources/Models")
            ]
        )
    ]
)
