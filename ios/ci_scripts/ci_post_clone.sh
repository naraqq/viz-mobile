#!/bin/sh

echo "=== ci_post_clone start (ios) ==="
REPO_ROOT="${CI_WORKSPACE:-$(cd "$(dirname "$0")/../.." && pwd)}"
FLUTTER_SDK="$HOME/flutter"

git clone https://github.com/flutter/flutter.git \
  --depth 1 --branch stable "$FLUTTER_SDK" || { echo "ERROR: clone failed"; exit 1; }

export PATH="$PATH:$FLUTTER_SDK/bin"
flutter config --no-analytics 2>/dev/null || true
flutter config --no-enable-swift-package-manager 2>/dev/null || true

cd "$REPO_ROOT"
flutter pub get || { echo "ERROR: pub get failed"; exit 1; }

echo "=== GeneratedPluginRegistrant.m after pub get (first 20 lines) ==="
head -20 "$REPO_ROOT/ios/Runner/GeneratedPluginRegistrant.m" 2>/dev/null || echo "FILE NOT FOUND"

# Restore the committed plugin registrant — CI's Flutter version may regenerate
# it without the #if __has_include guard, causing @import failures at build time.
git checkout -- ios/Runner/GeneratedPluginRegistrant.m \
                ios/Runner/GeneratedPluginRegistrant.h 2>/dev/null || true

echo "=== GeneratedPluginRegistrant.m after git restore (first 20 lines) ==="
head -20 "$REPO_ROOT/ios/Runner/GeneratedPluginRegistrant.m" 2>/dev/null || echo "FILE NOT FOUND"

flutter precache --ios || { echo "ERROR: precache failed"; exit 1; }

cd "$REPO_ROOT/ios"
pod repo remove trunk 2>/dev/null || true
LANG=en_US.UTF-8 pod install --repo-update || { echo "ERROR: pod install failed"; exit 1; }

# Remove the explicit PBXTargetDependency from Runner AFTER pod install.
# CocoaPods needs it during 'pod install' to identify Runner as the NSE host target.
# Xcode 26's build system, combined with buildImplicitDependencies=YES, also finds the
# NSE as an implicit dependency via the Embed App Extensions phase — keeping the explicit
# dependency too causes it to be scheduled twice, producing "Multiple commands produce .appex".
PBXPROJ="$REPO_ROOT/ios/Runner.xcodeproj/project.pbxproj"
grep -v "8D771ACF4E84AC81A24AC200 /\* PBXTargetDependency \*/," "$PBXPROJ" > /tmp/project_patched.pbxproj \
  && mv /tmp/project_patched.pbxproj "$PBXPROJ" \
  || { echo "ERROR: failed to patch project.pbxproj"; exit 1; }
echo "=== Patched project: removed NSE explicit dependency from Runner ==="

echo "=== firebase_auth headers after pod install ==="
find "$REPO_ROOT/ios/Pods" -name "FLTFirebaseAuthPlugin.h" 2>/dev/null || echo "HEADER NOT FOUND"
echo "=== public headers root ==="
ls "$REPO_ROOT/ios/Pods/Headers/Public/" 2>/dev/null | head -10 || echo "NO PUBLIC HEADERS DIR"

echo "=== done ==="
