#!/bin/sh

echo "=== ci_post_clone start ==="
echo "CI_WORKSPACE: $CI_WORKSPACE"

REPO_ROOT="${CI_WORKSPACE:-$(pwd)}"
FLUTTER_SDK="$HOME/flutter"

echo "=== Step 1: Clone Flutter (stable) ==="
git clone https://github.com/flutter/flutter.git \
  --depth 1 --branch stable \
  "$FLUTTER_SDK" || { echo "ERROR: Flutter clone failed"; exit 1; }

export PATH="$PATH:$FLUTTER_SDK/bin"

echo "=== Step 2: Flutter version ==="
flutter --version --no-version-check

echo "=== Step 3: Disable analytics ==="
flutter config --no-analytics 2>/dev/null || true

echo "=== Step 4: flutter pub get ==="
cd "$REPO_ROOT"
flutter pub get || { echo "ERROR: flutter pub get failed"; exit 1; }

echo "=== Step 5: flutter precache --ios ==="
flutter precache --ios || { echo "ERROR: flutter precache failed"; exit 1; }

echo "=== Step 6: pod install ==="
cd "$REPO_ROOT/ios"
LANG=en_US.UTF-8 pod install || { echo "ERROR: pod install failed"; exit 1; }

echo "=== ci_post_clone DONE ==="
