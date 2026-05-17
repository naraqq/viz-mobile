#!/bin/sh
set -e

echo "=== ci_post_clone start ==="
echo "PWD: $(pwd)"
echo "CI_WORKSPACE: $CI_WORKSPACE"

REPO_ROOT="${CI_WORKSPACE:-$(pwd)}"
FLUTTER_SDK="$HOME/flutter"

# Clone Flutter stable SDK
echo "=== Cloning Flutter SDK (stable) ==="
git clone https://github.com/flutter/flutter.git \
  --depth 1 \
  --branch stable \
  "$FLUTTER_SDK"

export PATH="$PATH:$FLUTTER_SDK/bin"

echo "=== Flutter version ==="
flutter --version --no-version-check

echo "=== flutter pub get ==="
cd "$REPO_ROOT"
flutter pub get

echo "=== pod install ==="
cd "$REPO_ROOT/ios"
LANG=en_US.UTF-8 pod install --repo-update

echo "=== ci_post_clone done ==="
