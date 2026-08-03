#!/usr/bin/env bash
#
# Read-only preflight for declared Swift/Xcode compatibility blockers.
# It never parses a manifest, resolves dependencies, builds, or runs target code.

set -uo pipefail

OK="✅"; WARN="⚠️"; STOP="🛑"; INFO="•"

usage() {
  cat <<'EOF'
Usage: scripts/check-build-feasibility.sh [source-folder] [--build-file relative-path]

Checks one Swift/Xcode build file without executing reviewed code. If the source
contains multiple Package.swift or project.pbxproj files, rerun with --build-file
and one of the relative paths reported by the script.
EOF
}

SRC="quarantine"
SELECTED_BUILD_FILE=""
if [[ $# -gt 0 && "${1:-}" != "--build-file" ]]; then
  SRC="$1"
  shift
fi
if [[ $# -gt 0 ]]; then
  if [[ "${1:-}" != "--build-file" || -z "${2:-}" || $# -ne 2 ]]; then
    usage
    exit 2
  fi
  SELECTED_BUILD_FILE="$2"
fi

if [[ ! -d "$SRC" ]]; then
  echo "$STOP  Folder not found: $SRC"
  usage
  exit 2
fi

echo "=================================================================="
echo " Declared build-compatibility preflight (read-only)"
echo " Target: $SRC"
echo "=================================================================="

ver_ge() {
  [[ -z "${1:-}" || -z "${2:-}" ]] && return 2
  awk -v actual="$1" -v required="$2" 'BEGIN {
    actual_count = split(actual, actual_parts, ".")
    required_count = split(required, required_parts, ".")
    count = actual_count > required_count ? actual_count : required_count
    for (part_index = 1; part_index <= count; part_index++) {
      actual_part = actual_parts[part_index] + 0
      required_part = required_parts[part_index] + 0
      if (actual_part > required_part) exit 0
      if (actual_part < required_part) exit 1
    }
    exit 0
  }'
}

version_from_output() {
  grep -Eo 'Swift version [0-9]+(\.[0-9]+)*' \
    | grep -Eo '[0-9]+(\.[0-9]+)*' | head -n1
}

first_version_in_file() {
  [[ -f "$1" ]] || return 1
  grep -Eo '[0-9]+(\.[0-9]+)+' "$1" 2>/dev/null | head -n1
}

relative_path() {
  case "$1" in
    "$SRC"/*) printf '%s\n' "${1#"$SRC"/}" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

echo
echo "--- Build files found ---------------------------------------------"

BUILD_FILES=()
while IFS= read -r build_file; do
  BUILD_FILES+=("$build_file")
done < <(find "$SRC" -type d -name .git -prune -o \
  -type f \( -name Package.swift -o -name project.pbxproj \) -print 2>/dev/null | sort)

if [[ ${#BUILD_FILES[@]} -eq 0 ]]; then
  echo "$WARN No Package.swift or project.pbxproj found under $SRC."
  echo "     This may use another build system; resolve that path manually."
  exit 2
fi

for build_file in "${BUILD_FILES[@]}"; do
  echo "$INFO $(relative_path "$build_file")"
done
while IFS= read -r workspace; do
  echo "$INFO $(relative_path "$workspace") (workspace; inspect its projects)"
done < <(find "$SRC" -type d -name .git -prune -o \
  -type d -name '*.xcworkspace' -print 2>/dev/null | sort)

ACTIVE_BUILD_FILE=""
if [[ -n "$SELECTED_BUILD_FILE" ]]; then
  candidate="$SRC/$SELECTED_BUILD_FILE"
  for build_file in "${BUILD_FILES[@]}"; do
    if [[ "$build_file" == "$candidate" ]]; then
      ACTIVE_BUILD_FILE="$build_file"
      break
    fi
  done
  if [[ -z "$ACTIVE_BUILD_FILE" ]]; then
    echo "$STOP  --build-file did not match a reported build file: $SELECTED_BUILD_FILE"
    exit 2
  fi
elif [[ ${#BUILD_FILES[@]} -gt 1 ]]; then
  echo
  echo "$WARN Multiple build files found; choosing one silently could hide a blocker."
  echo "     Rerun with: --build-file <one-relative-path-shown-above>"
  exit 2
else
  ACTIVE_BUILD_FILE="${BUILD_FILES[0]}"
fi

IS_SWIFTPM=0
IS_XCODE=0
[[ "$ACTIVE_BUILD_FILE" == */Package.swift ]] && IS_SWIFTPM=1
[[ "$ACTIVE_BUILD_FILE" == */project.pbxproj ]] && IS_XCODE=1
echo "$OK Selected: $(relative_path "$ACTIVE_BUILD_FILE")"

echo
echo "--- Selected developer toolchain ---------------------------------"

WARNINGS=0
BLOCKERS=0
MACOS_VER="$(sw_vers -productVersion 2>/dev/null || true)"
echo "$INFO macOS:          ${MACOS_VER:-unknown}"

DEVELOPER_DIR_PATH="$(xcode-select -p 2>/dev/null || true)"
echo "$INFO Developer dir:  ${DEVELOPER_DIR_PATH:-unknown}"

XCODE_VER=""
LOCAL_SDK=""
if command -v xcodebuild >/dev/null 2>&1; then
  XCODE_VER="$(xcodebuild -version 2>/dev/null | awk '/^Xcode/{print $2; exit}')"
  LOCAL_SDK="$(xcodebuild -showsdks 2>/dev/null \
    | grep -Eo 'macosx[0-9]+(\.[0-9]+)*' | sed 's/macosx//' \
    | awk -F. '{ printf "%09d.%09d.%09d %s\n", $1, $2, $3, $0 }' \
    | sort | tail -n1 | awk '{print $2}')"
fi
echo "$INFO Xcode:          ${XCODE_VER:-unknown}"
echo "$INFO macOS SDK:      ${LOCAL_SDK:-unknown}"

SELECTED_SWIFT_PATH=""
SELECTED_SWIFT_VER=""
if command -v xcrun >/dev/null 2>&1; then
  SELECTED_SWIFT_PATH="$(xcrun --find swift 2>/dev/null || true)"
  SELECTED_SWIFT_VER="$(xcrun swift --version 2>/dev/null | version_from_output || true)"
fi
echo "$INFO Selected Swift: ${SELECTED_SWIFT_VER:-unknown}${SELECTED_SWIFT_PATH:+ ($SELECTED_SWIFT_PATH)}"

PATH_SWIFT_PATH="$(command -v swift 2>/dev/null || true)"
PATH_SWIFT_VER=""
if [[ -n "$PATH_SWIFT_PATH" ]]; then
  PATH_SWIFT_VER="$(swift --version 2>/dev/null | version_from_output || true)"
fi
if [[ -n "$PATH_SWIFT_VER" && -n "$SELECTED_SWIFT_VER" && "$PATH_SWIFT_VER" != "$SELECTED_SWIFT_VER" ]]; then
  echo "$WARN PATH Swift ($PATH_SWIFT_VER at $PATH_SWIFT_PATH) differs from selected Swift ($SELECTED_SWIFT_VER)."
  echo "     This check uses the selected developer toolchain reported by xcrun."
  WARNINGS=$((WARNINGS+1))
fi

if [[ -z "$SELECTED_SWIFT_VER" ]]; then
  echo "$WARN Selected Swift version could not be determined."
  WARNINGS=$((WARNINGS+1))
fi
if [[ "$IS_XCODE" -eq 1 && ( -z "$XCODE_VER" || -z "$LOCAL_SDK" || -z "$DEVELOPER_DIR_PATH" ) ]]; then
  echo "$WARN A full selected Xcode and macOS SDK could not be confirmed."
  WARNINGS=$((WARNINGS+1))
fi

echo
echo "--- Declared project requirements --------------------------------"

REQ_TOOLS=""
REQ_SWIFT_FILE=""
REQ_XCODE_FILE=""
DEP_TARGET=""
BUILD_ROOT="$(dirname "$ACTIVE_BUILD_FILE")"
[[ "$IS_XCODE" -eq 1 ]] && BUILD_ROOT="$(dirname "$(dirname "$ACTIVE_BUILD_FILE")")"

if [[ "$IS_SWIFTPM" -eq 1 ]]; then
  REQ_TOOLS="$(head -n1 "$ACTIVE_BUILD_FILE" 2>/dev/null \
    | grep -Eio '^//[[:space:]]*swift-tools-version:[[:space:]]*[0-9]+(\.[0-9]+)+' \
    | grep -Eo '[0-9]+(\.[0-9]+)+' | head -n1 || true)"
  if [[ -n "$REQ_TOOLS" ]]; then
    echo "$INFO Package.swift requires swift-tools-version $REQ_TOOLS"
  else
    echo "$WARN Package.swift first line has no readable swift-tools-version declaration."
    WARNINGS=$((WARNINGS+1))
  fi
fi

REQ_SWIFT_FILE="$(first_version_in_file "$BUILD_ROOT/.swift-version" || true)"
REQ_XCODE_FILE="$(first_version_in_file "$BUILD_ROOT/.xcode-version" || true)"
[[ -n "$REQ_SWIFT_FILE" ]] && echo "$INFO .swift-version pins Swift $REQ_SWIFT_FILE"
[[ -n "$REQ_XCODE_FILE" ]] && echo "$INFO .xcode-version pins Xcode $REQ_XCODE_FILE"

if [[ "$IS_XCODE" -eq 1 ]]; then
  DEP_TARGET="$(grep -Eo 'MACOSX_DEPLOYMENT_TARGET[[:space:]]*=[[:space:]]*"?[0-9]+(\.[0-9]+)*"?' "$ACTIVE_BUILD_FILE" 2>/dev/null \
    | grep -Eo '[0-9]+(\.[0-9]+)*' \
    | awk -F. '{ printf "%09d.%09d.%09d %s\n", $1, $2, $3, $0 }' \
    | sort | tail -n1 | awk '{print $2}')"
  if [[ -n "$DEP_TARGET" ]]; then
    echo "$INFO Minimum runtime macOS target: $DEP_TARGET (not a required SDK version)"
  fi
  if find "$BUILD_ROOT" -type f -name '*.xcconfig' -print -quit 2>/dev/null | grep -q .; then
    echo "$WARN .xcconfig files found; settings defined or included there require manual review."
    WARNINGS=$((WARNINGS+1))
  fi
fi

echo
echo "--- Comparison ----------------------------------------------------"

if [[ -n "$REQ_TOOLS" && -n "$SELECTED_SWIFT_VER" ]]; then
  if ver_ge "$SELECTED_SWIFT_VER" "$REQ_TOOLS"; then
    echo "$OK Selected Swift $SELECTED_SWIFT_VER meets declared tools-version $REQ_TOOLS."
  else
    echo "$STOP Selected Swift $SELECTED_SWIFT_VER is below declared tools-version $REQ_TOOLS."
    BLOCKERS=$((BLOCKERS+1))
  fi
fi
if [[ -n "$REQ_SWIFT_FILE" && -n "$SELECTED_SWIFT_VER" ]] && ! ver_ge "$SELECTED_SWIFT_VER" "$REQ_SWIFT_FILE"; then
  echo "$STOP Pinned Swift $REQ_SWIFT_FILE is newer than selected Swift $SELECTED_SWIFT_VER."
  BLOCKERS=$((BLOCKERS+1))
fi
if [[ -n "$REQ_XCODE_FILE" ]]; then
  if [[ -z "$XCODE_VER" ]]; then
    echo "$WARN Xcode $REQ_XCODE_FILE is pinned, but the selected Xcode version is unknown."
    WARNINGS=$((WARNINGS+1))
  elif ! ver_ge "$XCODE_VER" "$REQ_XCODE_FILE"; then
    echo "$STOP Pinned Xcode $REQ_XCODE_FILE is newer than selected Xcode $XCODE_VER."
    BLOCKERS=$((BLOCKERS+1))
  fi
fi

echo "$WARN Static metadata cannot prove the source avoids newer Swift features or SDK APIs."

echo
echo "=================================================================="
if [[ "$BLOCKERS" -gt 0 ]]; then
  echo "$STOP  DECLARED COMPATIBILITY BLOCKER FOUND."
  echo "  Do not force the build. This result does not approve another artifact."
  echo "  Keep reviewing readable source (Phase 3). For an exact pre-built"
  echo "  artifact, complete Phase 4 and risk-appropriate Phase 5; Hold or Reject"
  echo "  if provenance or remaining uncertainty is not adequately resolved."
  echo "  An older release needs its own pinned review, including advisories and"
  echo "  fixes since that version; it cannot establish correspondence to a newer binary."
  exit 1
elif [[ "$WARNINGS" -gt 0 ]]; then
  echo "$WARN  INCONCLUSIVE — resolve the warnings before choosing a build path."
  echo "  Do not build or run anything; the human execution decision remains pending."
  exit 2
else
  echo "$OK   NO DECLARED COMPATIBILITY BLOCKER FOUND."
  echo "  This is not proof that compilation will succeed and not permission to build."
  echo "  Complete Phase 2 and Phase 3, then wait for the recorded human decision"
  echo "  before any build or other execution."
  exit 0
fi
