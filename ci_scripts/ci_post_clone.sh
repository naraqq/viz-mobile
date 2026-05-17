#!/bin/sh

echo "=== ci_post_clone start ==="
echo "PWD: $(pwd)"
echo "CI_WORKSPACE: $CI_WORKSPACE"
echo "HOME: $HOME"
echo "macOS: $(sw_vers -productVersion)"

REPO_ROOT="${CI_WORKSPACE:-$(pwd)}"
FLUTTER_SDK="$HOME/flutter"

# Clone Flutter stable SDK
echo "=== Step 1: Cloning Flutter SDK ==="
git clone https://github.com/flutter/flutter.git \
  --depth 1 \
  --branch stable \
  "$FLUTTER_SDK" || { echo "ERROR: git clone failed"; exit 1; }

export PATH="$PATH:$FLUTTER_SDK/bin"

echo "=== Step 2: Flutter version ==="
flutter --version || { echo "ERROR: flutter --version failed"; exit 1; }

echo "=== Step 3: Disable analytics ==="
flutter config --no-analytics 2>/dev/null || true

echo "=== Step 4: flutter pub get ==="
cd "$REPO_ROOT"
flutter pub get || { echo "ERROR: flutter pub get failed"; exit 1; }

echo "=== Step 5: pod install ==="
cd "$REPO_ROOT/ios"
LANG=en_US.UTF-8 pod install --repo-update || { echo "ERROR: pod install failed"; exit 1; }

echo "=== ci_post_clone DONE ==="
