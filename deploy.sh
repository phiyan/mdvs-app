#!/usr/bin/env bash
# deploy.sh — Build MDVisualizer in release mode and install to ~/Applications
set -euo pipefail

APP_NAME="MDVisualizer"
BUNDLE_ID="com.mdvisualizer.app"
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$REPO_ROOT/.build/arm64-apple-macosx/release"
INFO_PLIST="$REPO_ROOT/Sources/MDVisualizer/Info.plist"
DEST="$HOME/Applications/$APP_NAME.app"

# ── 1. Build ────────────────────────────────────────────────────────────────
echo "→ Building $APP_NAME (release)…"
swift build -c release --arch arm64

# ── 2. Assemble .app bundle ──────────────────────────────────────────────────
echo "→ Assembling $APP_NAME.app…"

# Remove any previous staging area, then recreate
STAGING="$(mktemp -d)/MDVisualizer.app"

mkdir -p "$STAGING/Contents/MacOS"
mkdir -p "$STAGING/Contents/Resources"

# Info.plist
cp "$INFO_PLIST" "$STAGING/Contents/Info.plist"

# Executable
cp "$BUILD_DIR/$APP_NAME" "$STAGING/Contents/MacOS/$APP_NAME"
chmod +x "$STAGING/Contents/MacOS/$APP_NAME"

# SPM resource bundle — Bundle.module looks for it at bundleURL root, not
# inside Contents/Resources. See: resource_bundle_accessor.swift:
#   Bundle.main.bundleURL.appendingPathComponent("MDVisualizer_MDVisualizer.bundle")
cp -R "$BUILD_DIR/${APP_NAME}_${APP_NAME}.bundle" "$STAGING/"

# ── 3. Ad-hoc code-sign (required for launch on Apple Silicon) ───────────────
echo "→ Code-signing (ad-hoc)…"
codesign --force --deep --sign - "$STAGING"

# ── 4. Install into ~/Applications ──────────────────────────────────────────
mkdir -p "$HOME/Applications"

if [[ -d "$DEST" ]]; then
    echo "→ Replacing existing $DEST…"
    rm -rf "$DEST"
fi

cp -R "$STAGING" "$DEST"
echo "✓ Installed: $DEST"
