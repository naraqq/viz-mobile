#!/bin/sh
set -e

echo "=== ci_post_clone start (ios) ==="
REPO_ROOT="${CI_WORKSPACE:-$(cd "$(dirname "$0")/../.." && pwd)}"
FLUTTER_SDK="$HOME/flutter"

echo "=== Cloning Flutter SDK (stable) ==="
git clone https://github.com/flutter/flutter.git \
  --depth 1 \
  --branch stable \
  "$FLUTTER_SDK"

export PATH="$PATH:$FLUTTER_SDK/bin"

flutter --version --no-version-check

cd "$REPO_ROOT"
flutter pub get

cd "$REPO_ROOT/ios"
LANG=en_US.UTF-8 pod install --repo-update

echo "=== done ==="
