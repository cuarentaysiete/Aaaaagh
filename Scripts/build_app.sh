#!/bin/bash
# build_app.sh — Build Aaaaagh as a proper macOS .app bundle and optionally run it.
#
# Why a .app bundle? Running a SwiftUI GUI app via `swift run` (SPM) doesn't give
# it keyboard focus (the window appears but isn't the key window). A proper .app
# bundle (with Info.plist) gets focus and receives keyboard input correctly.
#
# Usage:
#   ./Scripts/build_app.sh          # build the .app bundle
#   ./Scripts/build_app.sh run      # build + run (open) the .app bundle
#
# The bundle is created at build/Aaaaagh.app. Model weights must be present in
# Aaaaagh/Resources/Models/EuroLLM-1.7B-Instruct-4bit/ (see README).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build"
APP_BUNDLE="$BUILD_DIR/Aaaaagh.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"
BINARY_NAME="Aaaaagh"

echo "==> Building Aaaaagh (swift build)…"
cd "$ROOT"
swift build

echo "==> Creating .app bundle structure…"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

echo "==> Writing Info.plist…"
cat > "$CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>Aaaaagh</string>
	<key>CFBundleDisplayName</key>
	<string>Aaaaagh</string>
	<key>CFBundleIdentifier</key>
	<string>com.cuarentaysiete.aaaaagh</string>
	<key>CFBundleVersion</key>
	<string>1.0</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleExecutable</key>
	<string>Aaaaagh</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
	<key>LSApplicationCategoryType</key>
	<string>public.app-category.productivity</string>
</dict>
</plist>
PLIST

echo "==> Copying executable…"
# swift build puts the executable in .build/debug/ (or .build/arm64-apple-macosx/debug/).
# Find it robustly.
EXE_PATH="$(swift build --show-bin-path)/$BINARY_NAME"
if [[ ! -f "$EXE_PATH" ]]; then
	echo "ERROR: built executable not found at $EXE_PATH" >&2
	exit 1
fi
cp -f "$EXE_PATH" "$MACOS_DIR/$BINARY_NAME"
chmod +x "$MACOS_DIR/$BINARY_NAME"

echo "==> Copying model resources…"
MODELS_SRC="$ROOT/Aaaaagh/Resources/Models"
if [[ -d "$MODELS_SRC" ]]; then
	rm -rf "$RESOURCES_DIR/Models"
	mkdir -p "$RESOURCES_DIR/Models"
	cp -R "$MODELS_SRC/." "$RESOURCES_DIR/Models/"
	echo "    Copied models from $MODELS_SRC"
else
	echo "    WARNING: no model resources at $MODELS_SRC (model won't be available)" >&2
fi

echo "==> Copying MLX Metal library bundle…"
# Find the mlx-swift_Cmlx.bundle (contains default.metallib for GPU operations).
# MLX needs this bundle at runtime to load the Metal shaders.
CMLX_BUNDLE=$(find "$ROOT/.build" -name "mlx-swift_Cmlx.bundle" -type d 2>/dev/null | head -1)
if [[ -n "$CMLX_BUNDLE" && -d "$CMLX_BUNDLE" ]]; then
	rm -rf "$RESOURCES_DIR/mlx-swift_Cmlx.bundle"
	cp -R "$CMLX_BUNDLE" "$RESOURCES_DIR/"
	echo "    Copied MLX bundle from $CMLX_BUNDLE"
else
	echo "    WARNING: mlx-swift_Cmlx.bundle not found (MLX GPU operations may fail)" >&2
fi

echo "==> Ad-hoc code signing…"
codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || echo "    (codesign skipped)"

echo ""
echo "✅ Built: $APP_BUNDLE"
echo ""

if [[ "${1:-}" == "run" ]]; then
	echo "==> Opening Aaaaagh.app…"
	open "$APP_BUNDLE"
fi
