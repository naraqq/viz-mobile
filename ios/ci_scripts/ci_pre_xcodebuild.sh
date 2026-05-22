#!/bin/sh
set -eu

echo "=== ci_pre_xcodebuild start (ios) ==="

REPO_ROOT="${CI_WORKSPACE:-$(cd "$(dirname "$0")/../.." && pwd)}"
PBXPROJ="${PBXPROJ:-$REPO_ROOT/ios/Runner.xcodeproj/project.pbxproj}"

ruby - "$PBXPROJ" <<'RUBY'
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

project.gsub!(
  /(CODE_SIGN_ENTITLEMENTS = [^;]+;\n)(?!\t\t\t\tCODE_SIGNING_ALLOWED = NO;\n)/,
  "\\1\t\t\t\tCODE_SIGNING_ALLOWED = NO;\n"
)

File.write(path, project)
RUBY

echo "=== Patched project for Xcode Cloud archive signing ==="

PODS_DIR="$REPO_ROOT/ios/Pods"
ruby - "$PODS_DIR" <<'RUBY'
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
