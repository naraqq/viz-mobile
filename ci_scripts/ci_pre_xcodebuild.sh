#!/bin/sh
set -e

echo "=== ci_pre_xcodebuild start ==="
echo "PWD: $(pwd)"
echo "CI_WORKSPACE: $CI_WORKSPACE"

REPO_ROOT="${CI_WORKSPACE:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$REPO_ROOT"

echo "=== Installing Flutter via Homebrew ==="
HOMEBREW_NO_AUTO_UPDATE=1 brew install --cask flutter 2>&1 || true

FLUTTER_BIN="$(brew --prefix)/bin/flutter"

echo "=== flutter pub get ==="
"$FLUTTER_BIN" pub get

echo "=== pod install ==="
cd "$REPO_ROOT/ios"
LANG=en_US.UTF-8 pod install --repo-update

echo "=== done ==="
