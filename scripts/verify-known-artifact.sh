#!/usr/bin/env bash
# Read-only drift check for a previously-audited macOS artifact.
# Records, or compares against, the signing/privilege invariants established at audit time.
# It never installs, launches, mounts, modifies or executes the artifact.
set -uo pipefail

OK="✅"; WARN="⚠️"; STOP="🛑"; INFO="•"

usage() {
  cat <<'EOF'
Usage:
  scripts/verify-known-artifact.sh --record <bundle> [> baseline.txt]
  scripts/verify-known-artifact.sh --baseline <baseline.txt> <bundle>

Compares a new version of an already-audited artifact against the invariants
recorded when it was audited: Team ID, signing authority, notarization,
Gatekeeper verdict, code-directory flags, entitlements, the component list, and
any non-Apple linked libraries.

This answers "did the trust anchor or the privilege change?" — it is NOT a
re-audit, and a clean result is not permission to install. A human still owns
the decision.

  --record <bundle>          Print a baseline for <bundle> to stdout.
  --baseline <file> <bundle> Compare <bundle> against a recorded baseline.
  -h, --help                 Show this message.

<bundle> is a path to an .app (or any signed bundle) that is already on disk —
for example a disk image you mounted read-only yourself with:
  hdiutil attach -readonly -nobrowse -noautoopen <image.dmg>

The script only reads. It does not mount, install, launch or execute anything.
EOF
}

MODE=""; BASELINE=""; BUNDLE=""

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    -h|--help) usage; exit 0 ;;
    --record)
      MODE="record"; shift
      BUNDLE="${1:-}"; shift || true ;;
    --baseline)
      MODE="compare"; shift
      BASELINE="${1:-}"; shift || true
      BUNDLE="${1:-}"; shift || true ;;
    *)
      echo "$STOP Unrecognised argument: $1"; echo; usage; exit 2 ;;
  esac
done

if [[ -z "$MODE" || -z "$BUNDLE" ]]; then
  usage; exit 2
fi
if [[ ! -e "$BUNDLE" ]]; then
  echo "$STOP Artifact not found: $BUNDLE"; exit 2
fi
if [[ "$MODE" == "compare" && ! -f "$BASELINE" ]]; then
  echo "$STOP Baseline file not found: $BASELINE"; exit 2
fi
for t in codesign spctl otool file find; do
  command -v "$t" >/dev/null 2>&1 || { echo "$STOP Required tool missing: $t"; exit 2; }
done

BUNDLE="${BUNDLE%/}"

# Entitlements vary in key order and array indices between runs; flatten to a
# stable, sorted set so only real changes show up as drift.
normalize_entitlements() {
  sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^[0-9][0-9]* => //' \
    | grep -v '^[][{}]$' \
    | grep -v '^$' \
    | sort -u
}

collect_facts() {
  local bundle="$1" out="$2"
  : > "$out"

  local bid
  bid=$(codesign -dv --verbose=2 "$bundle" 2>&1 | sed -n 's/^Identifier=//p' | head -1)
  [[ -n "$bid" ]] && printf 'bundle-identifier\t%s\n' "$bid" >> "$out"

  if xcrun stapler validate "$bundle" >/dev/null 2>&1; then
    printf 'notarization\tstapled\n' >> "$out"
  else
    printf 'notarization\tabsent\n' >> "$out"
  fi

  if spctl -a -vv "$bundle" >/dev/null 2>&1; then
    printf 'gatekeeper\taccepted\n' >> "$out"
  else
    printf 'gatekeeper\trejected\n' >> "$out"
  fi

  local f rel info team auth flags ent lib
  while IFS= read -r f; do
    file -b "$f" 2>/dev/null | grep -q 'Mach-O' || continue
    rel="${f#"$bundle"/}"
    printf 'component\t%s\n' "$rel" >> "$out"

    info=$(codesign -dv --verbose=4 "$f" 2>&1)

    team=$(printf '%s\n' "$info" | sed -n 's/^TeamIdentifier=//p' | head -1)
    [[ -n "$team" ]] && printf 'teamid\t%s|%s\n' "$rel" "$team" >> "$out"

    auth=$(printf '%s\n' "$info" | sed -n 's/^Authority=//p' | head -1)
    [[ -n "$auth" ]] && printf 'authority\t%s|%s\n' "$rel" "$auth" >> "$out"

    flags=$(printf '%s\n' "$info" | sed -n 's/.*flags=\(0x[0-9a-f]*\).*/\1/p' | head -1)
    [[ -n "$flags" ]] && printf 'cdflags\t%s|%s\n' "$rel" "$flags" >> "$out"

    while IFS= read -r ent; do
      [[ -n "$ent" ]] && printf 'entitlement\t%s|%s\n' "$rel" "$ent" >> "$out"
    done < <(codesign -d --entitlements - --xml "$f" 2>/dev/null \
               | plutil -p - 2>/dev/null | normalize_entitlements)

    while IFS= read -r lib; do
      [[ -n "$lib" ]] && printf 'nonapple-lib\t%s|%s\n' "$rel" "$lib" >> "$out"
    done < <(otool -L "$f" 2>/dev/null | tail -n +2 | awk '{print $1}' \
               | grep -vE '^/System/Library/|^/usr/lib/')
  done < <(find "$bundle" -type f -perm -u+x 2>/dev/null | sort)

  sort -o "$out" "$out"
}

WORK=$(mktemp -d) || { echo "$STOP Could not create a temporary directory."; exit 2; }
trap 'rm -rf "$WORK"' EXIT

collect_facts "$BUNDLE" "$WORK/new.txt"

if [[ ! -s "$WORK/new.txt" ]]; then
  echo "$STOP No signed Mach-O components found in: $BUNDLE"
  echo "$INFO Point this at an .app bundle, not a disk image or an archive."
  exit 2
fi

if [[ "$MODE" == "record" ]]; then
  echo "# ECISF known-artifact baseline (schema 1)"
  echo "# artifact: $(basename "$BUNDLE")"
  echo "# recorded: $(date '+%Y-%m-%d')"
  echo "# This records what was true at audit time. It is evidence, not permission."
  cat "$WORK/new.txt"
  exit 0
fi

grep -v '^#' "$BASELINE" | grep -v '^$' | sort > "$WORK/base.txt"

comm -23 "$WORK/base.txt" "$WORK/new.txt" > "$WORK/removed.txt"
comm -13 "$WORK/base.txt" "$WORK/new.txt" > "$WORK/added.txt"

echo "=================================================================="
echo " Known-artifact drift check (read-only)"
echo " Baseline: $BASELINE"
echo " Artifact: $BUNDLE"
echo "=================================================================="

if [[ ! -s "$WORK/removed.txt" && ! -s "$WORK/added.txt" ]]; then
  echo
  echo "$OK No drift. Every recorded invariant still holds."
  echo "$INFO Components checked: $(grep -c '^component' "$WORK/new.txt")"
  echo "$INFO This is not proof the update is safe, and not permission to"
  echo "  install. Read the release notes, then record a human decision."
  exit 0
fi

# Anything touching identity, notarization or privilege is the reason this
# script exists; everything else still needs eyes but is less alarming.
critical=0
echo
echo "--- Trust anchor & privilege ---------------------------------------"
while IFS= read -r line; do
  case "$line" in
    teamid*|authority*|notarization*|gatekeeper*|cdflags*)
      echo "$STOP CHANGED (was): $line"; critical=1 ;;
  esac
done < "$WORK/removed.txt"
while IFS= read -r line; do
  case "$line" in
    teamid*|authority*|notarization*|gatekeeper*|cdflags*)
      echo "$STOP CHANGED (now): $line"; critical=1 ;;
    entitlement*)
      echo "$STOP NEW PRIVILEGE:  $line"; critical=1 ;;
    nonapple-lib*)
      echo "$STOP NEW NON-APPLE LIBRARY: $line"; critical=1 ;;
  esac
done < "$WORK/added.txt"
[[ $critical -eq 0 ]] && echo "$OK Team ID, authority, notarization, flags, entitlements and libraries unchanged."

echo
echo "--- Composition ----------------------------------------------------"
composition=0
while IFS= read -r line; do
  case "$line" in
    component*)      echo "$WARN REMOVED: $line"; composition=1 ;;
    entitlement*)    echo "$WARN DROPPED PRIVILEGE: $line"; composition=1 ;;
    nonapple-lib*)   echo "$WARN LIBRARY REMOVED: $line"; composition=1 ;;
    bundle-identifier*) echo "$STOP IDENTIFIER CHANGED (was): $line"; critical=1 ;;
  esac
done < "$WORK/removed.txt"
while IFS= read -r line; do
  case "$line" in
    component*)      echo "$WARN ADDED: $line"; composition=1 ;;
    bundle-identifier*) echo "$STOP IDENTIFIER CHANGED (now): $line"; critical=1 ;;
  esac
done < "$WORK/added.txt"
[[ $composition -eq 0 ]] && echo "$OK Component list unchanged."

echo
echo "=================================================================="
if [[ $critical -eq 1 ]]; then
  echo "$STOP Drift in the trust anchor or in requested privilege."
  echo "  Do not install. This is a Tier 2 trigger: run a full re-audit"
  echo "  before accepting the new version."
else
  echo "$WARN Composition changed, trust anchor intact."
  echo "  Read the release notes and confirm the change is explained"
  echo "  before accepting. Record the outcome either way."
fi
echo "=================================================================="
exit 1
