#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CHECKER="$SCRIPT_DIR/check-build-feasibility.sh"
TEST_ROOT="$(mktemp -d)"
SHIM_DIR="$TEST_ROOT/shims"
PASS_COUNT=0
FAIL_COUNT=0
mkdir -p "$SHIM_DIR"
trap 'rm -rf "$TEST_ROOT"' EXIT

cat > "$SHIM_DIR/sw_vers" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${MOCK_MACOS_VERSION:-15.7.8}"
EOF

cat > "$SHIM_DIR/xcode-select" <<'EOF'
#!/usr/bin/env bash
[[ "${MOCK_NO_DEVELOPER_DIR:-0}" -eq 1 ]] && exit 1
printf '%s\n' '/Applications/Xcode.app/Contents/Developer'
EOF

cat > "$SHIM_DIR/xcodebuild" <<'EOF'
#!/usr/bin/env bash
[[ "${MOCK_NO_XCODE:-0}" -eq 1 ]] && exit 1
case "${1:-}" in
  -version) printf 'Xcode %s\nBuild version TEST\n' "${MOCK_XCODE_VERSION:-26.3}" ;;
  -showsdks)
    [[ "${MOCK_NO_SDK:-0}" -eq 1 ]] && exit 1
    printf 'macOS SDKs:\n\tmacOS %s -sdk macosx%s\n' "${MOCK_SDK_VERSION:-26.2}" "${MOCK_SDK_VERSION:-26.2}"
    ;;
esac
EOF

cat > "$SHIM_DIR/xcrun" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == '--find' ]]; then
  printf '%s\n' '/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift'
else
  printf 'Apple Swift version %s\n' "${MOCK_SELECTED_SWIFT_VERSION:-6.2.3}"
fi
EOF

cat > "$SHIM_DIR/swift" <<'EOF'
#!/usr/bin/env bash
printf 'Apple Swift version %s\n' "${MOCK_PATH_SWIFT_VERSION:-${MOCK_SELECTED_SWIFT_VERSION:-6.2.3}}"
EOF
chmod +x "$SHIM_DIR"/*

run_case() {
  name="$1"
  expected_exit="$2"
  expected_text="$3"
  shift 3
  output_file="$TEST_ROOT/output"
  set +e
  PATH="$SHIM_DIR:/usr/bin:/bin:/usr/sbin:/sbin" "$@" > "$output_file" 2>&1
  actual_exit=$?
  set -e
  if [[ "$actual_exit" -eq "$expected_exit" ]] && grep -Fq "$expected_text" "$output_file"; then
    printf 'PASS: %s\n' "$name"
    PASS_COUNT=$((PASS_COUNT+1))
  else
    printf 'FAIL: %s (exit %s, expected %s; wanted %s)\n' \
      "$name" "$actual_exit" "$expected_exit" "$expected_text"
    sed 's/^/  /' "$output_file"
    FAIL_COUNT=$((FAIL_COUNT+1))
  fi
}

make_package() {
  folder="$1"
  version="$2"
  mkdir -p "$folder"
  printf '// swift-tools-version: %s\nimport PackageDescription\n' "$version" > "$folder/Package.swift"
}

make_project() {
  folder="$1"
  mkdir -p "$folder/App.xcodeproj"
  printf 'MACOSX_DEPLOYMENT_TARGET = "15.0";\n' > "$folder/App.xcodeproj/project.pbxproj"
}

set -e

make_package "$TEST_ROOT/newer" 6.9
run_case "newer tools-version blocks" 1 "DECLARED COMPATIBILITY BLOCKER FOUND" \
  bash "$CHECKER" "$TEST_ROOT/newer"

make_package "$TEST_ROOT/older" 5.7
run_case "older tools-version has no declared blocker" 0 "not permission to build" \
  bash "$CHECKER" "$TEST_ROOT/older"

make_package "$TEST_ROOT/version-order" 5.9
run_case "dotted versions compare numerically" 0 "NO DECLARED COMPATIBILITY BLOCKER FOUND" \
  env MOCK_SELECTED_SWIFT_VERSION=5.10 MOCK_PATH_SWIFT_VERSION=5.10 bash "$CHECKER" "$TEST_ROOT/version-order"

make_project "$TEST_ROOT/no-xcode"
run_case "Xcode project needs full Xcode" 2 "full selected Xcode and macOS SDK could not be confirmed" \
  env MOCK_NO_XCODE=1 MOCK_NO_DEVELOPER_DIR=1 bash "$CHECKER" "$TEST_ROOT/no-xcode"

make_project "$TEST_ROOT/no-sdk"
run_case "Xcode project needs an SDK" 2 "full selected Xcode and macOS SDK could not be confirmed" \
  env MOCK_NO_SDK=1 bash "$CHECKER" "$TEST_ROOT/no-sdk"

make_package "$TEST_ROOT/mismatch" 5.7
run_case "PATH Swift mismatch is inconclusive" 2 "differs from selected Swift" \
  env MOCK_PATH_SWIFT_VERSION=6.1.2 bash "$CHECKER" "$TEST_ROOT/mismatch"

make_package "$TEST_ROOT/multiple/One" 5.7
make_package "$TEST_ROOT/multiple/Two" 6.9
run_case "multiple build files require selection" 2 "Multiple build files found" \
  bash "$CHECKER" "$TEST_ROOT/multiple"
run_case "selected nested package is checked" 1 "below declared tools-version 6.9" \
  bash "$CHECKER" "$TEST_ROOT/multiple" --build-file Two/Package.swift

mkdir -p "$TEST_ROOT/malformed"
printf 'import PackageDescription\n' > "$TEST_ROOT/malformed/Package.swift"
run_case "malformed manifest header is inconclusive" 2 "first line has no readable" \
  bash "$CHECKER" "$TEST_ROOT/malformed"

make_package "$TEST_ROOT/pin" 5.7
printf '6.9\n' > "$TEST_ROOT/pin/.swift-version"
run_case "newer Swift pin blocks" 1 "Pinned Swift 6.9 is newer" \
  bash "$CHECKER" "$TEST_ROOT/pin"

make_project "$TEST_ROOT/quoted"
run_case "quoted deployment target is informational" 0 "not a required SDK version" \
  bash "$CHECKER" "$TEST_ROOT/quoted"

make_project "$TEST_ROOT/workspace"
mkdir -p "$TEST_ROOT/workspace/App.xcworkspace"
run_case "Xcode workspace is reported" 0 "App.xcworkspace (workspace; inspect its projects)" \
  bash "$CHECKER" "$TEST_ROOT/workspace"

make_project "$TEST_ROOT/xcode-pin"
printf '26.9\n' > "$TEST_ROOT/xcode-pin/.xcode-version"
run_case "newer Xcode pin blocks" 1 "Pinned Xcode 26.9 is newer" \
  bash "$CHECKER" "$TEST_ROOT/xcode-pin"

make_project "$TEST_ROOT/configured"
printf 'SWIFT_VERSION = 6.0\n' > "$TEST_ROOT/configured/Build.xcconfig"
run_case "xcconfig requires manual review" 2 ".xcconfig files found" \
  bash "$CHECKER" "$TEST_ROOT/configured"

make_package "$TEST_ROOT/path with spaces" 5.7
run_case "source path may contain spaces" 0 "NO DECLARED COMPATIBILITY BLOCKER FOUND" \
  bash "$CHECKER" "$TEST_ROOT/path with spaces"

printf '\n%s passed; %s failed\n' "$PASS_COUNT" "$FAIL_COUNT"
[[ "$FAIL_COUNT" -eq 0 ]]
