// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Aaaaagh",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        // Core MLX (MLX, MLXNN, MLXFast, MLXRandom). Pinned to 0.33.x to match what
        // mlx-swift-lm 3.33.0 requires (mlx-swift 0.33.0..<0.34.0).
        .package(url: "https://github.com/ml-explore/mlx-swift.git", "0.33.0"..<"0.34.0"),
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
