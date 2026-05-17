#!/bin/sh
set -e

echo "=== CI_WORKSPACE: $CI_WORKSPACE ==="
echo "=== PWD: $(pwd) ==="

FLUTTER_SDK="$HOME/flutter"

echo "=== Cloning Flutter stable ==="
git clone https://github.com/flutter/flutter.git \
  --depth 1 \
  --branch stable \
  "$FLUTTER_SDK"

export PATH="$PATH:$FLUTTER_SDK/bin"

echo "=== Flutter version ==="
flutter --version --no-version-check

echo "=== Flutter pub get ==="
cd "$CI_WORKSPACE"
flutter pub get

echo "=== Pod install ==="
cd "$CI_WORKSPACE/ios"
LANG=en_US.UTF-8 pod install --repo-update

echo "=== Done ==="
