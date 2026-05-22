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
ruby - "$PBXPROJ" <<'RUBY' || { echo "ERROR: failed to patch project.pbxproj"; exit 1; }
path = ARGV.fetch(0)
project = File.read(path)

project.gsub!(
  /\n\t\tB8F01B61D9B17A25E3E3BFD7 \/\* PBXContainerItemProxy \*\/ = \{.*?\n\t\t\};/m,
  ""
)

project.gsub!(
  /\n\t\t8D771ACF4E84AC81A24AC200 \/\* PBXTargetDependency \*\/ = \{.*?\n\t\t\};/m,
  ""
)

project.gsub!(
  /\n\t\t\t\t8D771ACF4E84AC81A24AC200 \/\* PBXTargetDependency \*\/,/,
  ""
)

File.write(path, project)
RUBY
echo "=== Patched project: removed NSE explicit dependency from Runner ==="

PODS_DIR="$REPO_ROOT/ios/Pods"
ruby - "$PODS_DIR" <<'RUBY' || { echo "ERROR: failed to patch OneSignal pod outputs"; exit 1; }
pods_dir = ARGV.fetch(0)
files = Dir[
  File.join(pods_dir, "Target Support Files/OneSignalXCFramework-192fe2b2/*"),
  File.join(pods_dir, "Target Support Files/Pods-OneSignalNotificationServiceExtension/*.xcconfig")
]

files.each do |path|
  next unless File.file?(path)

  contents = File.read(path)
  patched = contents
    .gsub("${PODS_XCFRAMEWORKS_BUILD_DIR}/OneSignalXCFramework/", "${PODS_XCFRAMEWORKS_BUILD_DIR}/OneSignalXCFrameworkExtension/")
    .gsub("\"OneSignalXCFramework/", "\"OneSignalXCFrameworkExtension/")

  File.write(path, patched) if patched != contents
end
RUBY
echo "=== Patched OneSignal extension XCFramework output paths ==="

echo "=== firebase_auth headers after pod install ==="
find "$REPO_ROOT/ios/Pods" -name "FLTFirebaseAuthPlugin.h" 2>/dev/null || echo "HEADER NOT FOUND"
echo "=== public headers root ==="
ls "$REPO_ROOT/ios/Pods/Headers/Public/" 2>/dev/null | head -10 || echo "NO PUBLIC HEADERS DIR"

echo "=== done ==="
