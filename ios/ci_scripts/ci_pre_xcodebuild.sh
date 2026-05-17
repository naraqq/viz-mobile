#!/bin/sh
set -e

echo "=== ci_pre_xcodebuild start (ios/ci_scripts) ==="
REPO_ROOT="${CI_WORKSPACE:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$REPO_ROOT"

HOMEBREW_NO_AUTO_UPDATE=1 brew install --cask flutter 2>&1 || true

FLUTTER_BIN="$(brew --prefix)/bin/flutter"
"$FLUTTER_BIN" pub get

cd "$REPO_ROOT/ios"
LANG=en_US.UTF-8 pod install --repo-update

echo "=== done ==="
