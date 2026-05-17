#!/bin/sh
set -e

echo "=== ci_post_clone start ==="
echo "PWD: $(pwd)"
echo "CI_WORKSPACE: $CI_WORKSPACE"
echo "HOME: $HOME"

# Determine repo root — CI_WORKSPACE is set by Xcode Cloud
REPO_ROOT="${CI_WORKSPACE:-$(pwd)}"
cd "$REPO_ROOT"

# Install Flutter via Homebrew (Homebrew is pre-installed on Xcode Cloud agents)
echo "=== Installing Flutter via Homebrew ==="
brew install --cask flutter

FLUTTER_BIN="$(brew --prefix)/bin/flutter"

echo "=== Flutter version ==="
"$FLUTTER_BIN" --version --no-version-check

echo "=== flutter pub get ==="
"$FLUTTER_BIN" pub get

echo "=== pod install ==="
cd "$REPO_ROOT/ios"
LANG=en_US.UTF-8 pod install --repo-update

echo "=== ci_post_clone done ==="
