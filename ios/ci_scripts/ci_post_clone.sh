#!/bin/sh
set -e

echo "=== Installing Flutter ==="
git clone https://github.com/flutter/flutter.git \
  --depth 1 \
  --branch 3.41.9 \
  "$HOME/flutter"

export PATH="$PATH:$HOME/flutter/bin"

echo "=== Flutter version ==="
flutter --version

echo "=== Flutter pub get ==="
cd "$CI_WORKSPACE"
flutter pub get

echo "=== Pod install ==="
cd "$CI_WORKSPACE/ios"
LANG=en_US.UTF-8 pod install

echo "=== Done ==="
