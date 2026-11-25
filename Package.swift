// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Aaaaagh",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        // Core MLX (MLX, MLXNN, MLXFast, MLXRandom). Pinned to the same minor the
        // official mlx-swift-examples use, for a known-good matrix.
        .package(url: "https://github.com/ml-explore/mlx-swift.git", .upToNextMinor(from: "0.31.4")),
        // High-level LLM loading + ChatSession (MLXLLM, MLXLMCommon, MLXHuggingFace).
        .package(url: "https://github.com/ml-explore/mlx-swift-lm.git", from: "3.33.0"),
        // HuggingFace Hub client (HubClient) used by the #hubDownloader macro.
        .package(url: "https://github.com/huggingface/swift-huggingface.git", from: "0.9.0")
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
            ],
            path: "Aaaaagh",
            resources: [
                .copy("Resources/Models")
            ]
        )
    ]
)
