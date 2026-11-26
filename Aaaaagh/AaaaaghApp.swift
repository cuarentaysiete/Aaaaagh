// AaaaaghApp.swift
// App entry point: dependency-graph wiring, scene, and global shortcuts.
//
// Wiring:
//   bundledModelsRoot (Bundle.main/Resources/Models)
//     -> ModelRegistryStore(bundledModelsRoot:)
//     -> MLXTranslationEngine(profile:modelDirectory:)
//     -> TranslatorViewModel(modelStore:engine:)
//
// SwiftUI note: global keyboard shortcuts belong in `.commands { }` (CommandMenu /
// CommandGroup), not as view modifiers. We expose Translate + Copy there.

import SwiftUI
import AppKit
import Domain

@main
struct AaaaaghApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// Single source of truth for the app's state. Built once at launch.
    @StateObject private var viewModel: TranslatorViewModel

    init() {
        let bundledModelsRoot = Bundle.main.resourceURL?
            .appendingPathComponent("Models", isDirectory: true)
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Models")

        let modelStore = ModelRegistryStore(bundledModelsRoot: bundledModelsRoot)
        let profile = modelStore.profile
        let engine = MLXTranslationEngine(
            profile: profile,
            modelDirectory: profile.localDirectoryURL
        )
        let vm = TranslatorViewModel(modelStore: modelStore, engine: engine)
        _viewModel = StateObject(wrappedValue: vm)
    }

    var body: some Scene {
        WindowGroup("Aaaaagh") {
            MainTranslationView()
                .environmentObject(viewModel)
                .frame(minWidth: 760, minHeight: 480)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}

            // ⌘+Return — translate / re-run.
            CommandMenu("Translate") {
                Button("Translate") {
                    viewModel.translate()
                }
                .keyboardShortcut(.return, modifiers: .command)

                Button("Swap Languages") {
                    viewModel.swap()
                }
                .keyboardShortcut("s", modifiers: .command)

                Button("Clear") {
                    viewModel.clearInput()
                }
                .keyboardShortcut(.delete, modifiers: .command)
            }

            // ⌘+Shift+C — copy output.
            CommandGroup(after: .pasteboard) {
                Button("Copy Translation") {
                    viewModel.copyOutput()
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
            }
        }
    }
}

/// Handles window-frame persistence via `NSWindow.setFrameAutosaveName(_:)`,
/// which lets AppKit save and restore the window frame automatically.
/// No manual `NSKeyedArchiver`/`NSKeyedUnarchiver` needed (and `NSRect`/`CGRect`
/// is a C struct that can't be archived with `NSKeyedArchiver` anyway).
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let autosaveName = "AaaaaghMainWindow"

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Give SwiftUI a moment to create the main window, then apply the
        // autosave name so AppKit restores the last saved frame.
        DispatchQueue.main.async {
            NSApp.mainWindow?.setFrameAutosaveName(self.autosaveName)
        }
    }
}
