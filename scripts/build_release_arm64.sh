#!/usr/bin/env bash
# ==============================================================================
# EnvOps — Ultra-Slim ARM64 Release Build Pipeline (Bash / CI / Linux / macOS)
# ==============================================================================
# Description:
#   Builds a highly optimized, minimal-size Release APK for modern physical Android devices.
#
# Optimizations:
#   1. Target: android-arm64 (arm64-v8a) — strips 32-bit ARM and x86 emulator binaries (~55% size cut).
#   2. Code Obfuscation: --obfuscate — strips method/class names.
#   3. Symbol Extraction: --split-debug-info=build/app/outputs/symbols — removes heavy symbols from APK.
#   4. Tree-shaking: supports standard icon font tree-shaking or --no-tree-shake-icons.
#
# Usage:
#   ./scripts/build_release_arm64.sh [--no-tree-shake] [--skip-tests]
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

NO_TREE_SHAKE=false
SKIP_TESTS=false

for arg in "$@"; do
  case "$arg" in
    --no-tree-shake)
      NO_TREE_SHAKE=true
      shift
      ;;
    --skip-tests)
      SKIP_TESTS=true
      shift
      ;;
  esac
done

echo "=========================================================="
echo "  EnvOps — Ultra-Slim ARM64 Release Build Pipeline"
echo "=========================================================="
echo "Project Root : $PROJECT_ROOT"
echo "Architecture : android-arm64 (64-bit physical mobile devices)"

if [ "$SKIP_TESTS" = false ]; then
  echo -e "\n[1/4] Running Static Analysis (flutter analyze)..."
  flutter analyze

  echo -e "\n[2/4] Running Automated Tests (flutter test)..."
  flutter test
else
  echo -e "\n[1/4 & 2/4] Pre-flight quality checks skipped."
fi

SYMBOLS_DIR="$PROJECT_ROOT/build/app/outputs/symbols"
mkdir -p "$SYMBOLS_DIR"

BUILD_ARGS=(
  build apk --release
  --target-platform android-arm64
  --obfuscate
  --split-debug-info="$SYMBOLS_DIR"
)

if [ "$NO_TREE_SHAKE" = true ]; then
  echo "Icon tree-shaking disabled (--no-tree-shake-icons)."
  BUILD_ARGS+=(--no-tree-shake-icons)
else
  echo "Icon font tree-shaking enabled for maximum compression."
fi

echo -e "\n[3/4] Compiling Optimized ARM64 APK with Flutter..."
flutter "${BUILD_ARGS[@]}"

echo -e "\n[4/4] Verifying Generated APK..."
APK_PATH="$PROJECT_ROOT/build/app/outputs/flutter-apk/app-release.apk"
if [ ! -f "$APK_PATH" ] && [ -f "$PROJECT_ROOT/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk" ]; then
  APK_PATH="$PROJECT_ROOT/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
fi

if [ -f "$APK_PATH" ]; then
  FILE_SIZE=$(du -h "$APK_PATH" | cut -f1)
  echo "=========================================================="
  echo "  BUILD SUCCESSFUL!"
  echo "=========================================================="
  echo "APK Location : $APK_PATH"
  echo "APK Size     : $FILE_SIZE"
  echo "Target ABI   : ARM64-v8a (Clean, single-arch standalone)"
  echo -e "\nInstall on connected Android phone using ADB:"
  echo "  adb install -r \"$APK_PATH\""
  echo "=========================================================="
fi
