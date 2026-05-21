#!/bin/sh

echo "=== ci_post_clone start (ios) ==="
REPO_ROOT="${CI_WORKSPACE:-$(cd "$(dirname "$0")/../.." && pwd)}"
FLUTTER_SDK="$HOME/flutter"

git clone https://github.com/flutter/flutter.git \
  --depth 1 --branch stable "$FLUTTER_SDK" || { echo "ERROR: clone failed"; exit 1; }

export PATH="$PATH:$FLUTTER_SDK/bin"
flutter config --no-analytics 2>/dev/null || true

cd "$REPO_ROOT"
flutter pub get || { echo "ERROR: pub get failed"; exit 1; }

flutter precache --ios || { echo "ERROR: precache failed"; exit 1; }

cd "$REPO_ROOT/ios"
pod repo remove trunk 2>/dev/null || true
LANG=en_US.UTF-8 pod install --repo-update || { echo "ERROR: pod install failed"; exit 1; }

echo "=== done ==="
