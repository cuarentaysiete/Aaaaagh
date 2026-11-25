# Aaaaagh

A lightweight, native, **100% offline** macOS text-translation app built with
SwiftUI + [MLX Swift](https://github.com/ml-explore/mlx-swift). It loads a local
small multilingual model (default: `EuroLLM-1.7B-Instruct-4bit`) and translates
text without any network access.

## Requirements

- macOS 14+, **Apple Silicon** (MLX requires Metal / Apple Silicon GPU).
- Xcode 16+ / Swift 5.9+ toolchain.

## Project layout

```
Aaaaagh/
├── Package.swift
├── Sources/Domain/            # Pure model: no SwiftUI, no MLX
│   ├── Language.swift
│   ├── TranslationRequest.swift
│   ├── WordAlternativeRequest.swift
│   ├── ModelProfile.swift
│   └── TranslationEngineProtocol.swift
└── Aaaaagh/                   # The executable app target
    ├── AaaaaghApp.swift       # @main entry, global shortcuts
    ├── AppState/
    │   ├── TranslatorViewModel.swift
    │   └── LanguageDetectionService.swift
    ├── Infrastructure/
    │   ├── MLX/
    │   │   ├── MLXTranslationEngine.swift
    │   │   └── PromptBuilder.swift
    │   └── Models/
    │       ├── LocalModelScanner.swift
    │       └── ModelRegistryStore.swift
    ├── Presentation/
    │   ├── MainTranslationView.swift
    │   ├── ModelSettingsView.swift
    │   └── Components/
    │       ├── LanguagePickerView.swift
    │       ├── OutputTextView.swift
    │       └── WordAlternativesPopover.swift
    └── Resources/Models/EuroLLM-1.7B-Instruct-4bit/
```

Layering rule: `Domain` depends on nothing; `Infrastructure` depends on `Domain`
+ MLX; `AppState` + `Presentation` depend on `Domain`. The UI never touches MLX
types directly.

## Build & run

1. **Get the model weights** (one-time, ~930 MB). Copy your existing
   `model.safetensors` into the bundled folder:

   ```bash
   cp /path/to/EuroLLM-1.7B-Instruct-4bit/model.safetensors \
      Aaaaagh/Resources/Models/EuroLLM-1.7B-Instruct-4bit/
   ```

   …or skip this and point the app at a model folder that already exists on disk
   via **Model Settings** (top-right gear). The UI stays greyed out until a valid
   model is available.

2. **Build & launch** with Swift Package Manager:

   ```bash
   swift build
   swift run
   ```

   Or open with Xcode: `xcodebuild -scheme Aaaaagh -destination 'platform=macOS' build`.

### Shortcuts

- **⌘+Return** — translate.
- **⌘+Shift+C** — copy the translation to the pasteboard.
- **⌘+,** — model settings (standard).
- Click/double-click a word in the output pane to see contextual alternatives.

## Model & generation settings

- Model path is stored in `UserDefaults` (`ModelRegistryStore`); the default
  points at the bundled folder. You can pick any folder with a valid
  `config.json` + `model*.safetensors` + tokenizer.
- `ModelProfile` holds per-model behaviour (context cap, sampling temperature,
  prompt style, stop tokens). The default profile is tuned for EuroLLM.
- Translations stream token-by-token into the output pane and auto-stop at the
  model's EOS (`</s>`, id 4) or at `maxOutputTokens`.

## Honest note on the MLX Swift API

This project targets the **current stable** `mlx-swift-lm` high-level API
(`LLMModelFactory` + `ChatSession`), which is the API the official
`mlx-swift-examples` tooling uses. The high-level LLM API has been evolving
quickly across MLX releases; if your pinned version differs from the one used to
write `MLXTranslationEngine.swift`, the load/generate calls in that one file may
need a small signature adjustment (the load entry point and the streaming call).
The rest of the app is independent of those signatures. `Package.swift` pins
known-good versions so a fresh `swift build` resolves a coherent set.
