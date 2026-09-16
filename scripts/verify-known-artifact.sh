#!/usr/bin/env bash
# Read-only drift check for a previously-audited macOS artifact.
# Records, or compares against, the signing/privilege invariants established at audit time.
# It never installs, launches, mounts, modifies or executes the artifact.
set -uo pipefail

# Byte collation, not locale collation: sort and comm must agree or comm
# silently reports the tail of both files as drift. See artifact-facts.sh.
export LC_ALL=C

OK="✅"; WARN="⚠️"; STOP="🛑"; INFO="•"

# The fact collector is shared with phase4-artifact.sh so that audited evidence
# and the stored baseline can never describe the same artifact differently.
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [[ ! -r "$SCRIPT_DIR/lib/artifact-facts.sh" ]]; then
  echo "$STOP Missing shared collector: $SCRIPT_DIR/lib/artifact-facts.sh" >&2
  exit 2
fi
# shellcheck source=lib/artifact-facts.sh
. "$SCRIPT_DIR/lib/artifact-facts.sh"

usage() {
  cat <<'EOF'
Usage:
  scripts/verify-known-artifact.sh --record <bundle> [> baseline.txt]
  scripts/verify-known-artifact.sh --baseline <baseline.txt> <bundle>
  scripts/verify-known-artifact.sh --system-persistence <bundle>
  scripts/verify-known-artifact.sh --system-ownership <bundle>

Compares a new version of an already-audited artifact against the invariants
recorded when it was audited: Team ID, signing authority, notarization,
Gatekeeper verdict, code-directory flags, entitlements, bundle-declared
persistence, privileged helpers, the component list, and any non-Apple linked
libraries.

This answers "did the trust anchor or the privilege change?" — it is NOT a
re-audit, and a clean result is not permission to install. A human still owns
the decision.

  --record <bundle>          Print a baseline for <bundle> to stdout.
  --baseline <file> <bundle> Compare <bundle> against a recorded baseline.
  --system-persistence <bundle>
                             List launchd jobs INSTALLED on this system that
                             reference <bundle>. Use after installing, to check
                             what the artifact actually registered. Enumerates
                             from the system — never from memory or docs.
                             NOTE: this output describes YOUR machine, not the
                             artifact. Summarise it in a public report rather
                             than pasting it raw.
  --system-ownership <bundle>
                             Report who owns the INSTALLED bundle and whether
                             a less-privileged account could modify it. Use
                             after installing. Ownership is deliberately NOT a
                             baseline record: a mounted image reports the
                             mounting user rather than the image's own value,
                             so a baselined figure would be a reading artifact.
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
    --system-persistence)
      MODE="syspersist"; shift
      BUNDLE="${1:-}"; shift || true ;;
    --system-ownership)
      MODE="sysowner"; shift
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
artifact_facts_require_tools || exit 2
artifact_facts_require_collation || exit 2

BUNDLE="${BUNDLE%/}"

WORK=$(mktemp -d) || { echo "$STOP Could not create a temporary directory."; exit 2; }
trap 'rm -rf "$WORK"' EXIT

if [[ "$MODE" == "syspersist" ]]; then
  bid=$(codesign -dv --verbose=2 "$BUNDLE" 2>&1 | sed -n 's/^Identifier=//p' | head -1)
  echo "=================================================================="
  echo " Installed launchd jobs referencing this artifact (read-only)"
  echo " Artifact: $BUNDLE"
  echo " Bundle id: ${bid:-<unknown>}"
  echo "=================================================================="
  echo
  found=0
  # Match either by program path (points into this bundle) or by vendor prefix
  # of the bundle id, which still catches jobs whose program lives elsewhere.
  vendor=$(printf '%s' "${bid:-}" | cut -d. -f1,2)
  for dir in /Library/LaunchAgents /Library/LaunchDaemons "$HOME/Library/LaunchAgents"; do
    [[ -d "$dir" ]] || continue
    for pl in "$dir"/*.plist; do
      [[ -e "$pl" ]] || continue
      label=$(/usr/libexec/PlistBuddy -c 'Print :Label' "$pl" 2>/dev/null)
      prog=$(/usr/libexec/PlistBuddy -c 'Print :Program' "$pl" 2>/dev/null)
      [[ -z "$prog" ]] && prog=$(/usr/libexec/PlistBuddy -c 'Print :ProgramArguments:0' "$pl" 2>/dev/null)
      match=0
      [[ -n "$prog"  && "$prog"  == "$BUNDLE"* ]] && match=1
      [[ -n "$vendor" && "$label" == "$vendor".* ]] && match=1
      [[ $match -eq 1 ]] || continue

      found=1
      case "$dir" in
        */LaunchDaemons) echo "$STOP ROOT DAEMON  $pl" ;;
        *)               echo "$INFO USER AGENT   $pl" ;;
      esac
      echo "     label:   ${label:-<none>}"
      echo "     program: ${prog:-<none>}"
      case "$prog" in
        "$BUNDLE"*) echo "     scope:   inside the audited bundle" ;;
        "")         echo "     scope:   unresolved" ;;
        *)          echo "     scope:   $WARN OUTSIDE the audited bundle — not covered by the baseline" ;;
      esac
      echo
    done
  done
  if [[ $found -eq 0 ]]; then
    echo "$WARN No launchd jobs matched this artifact."
    echo "$INFO That is a real result only if the app is INSTALLED. Run this"
    echo "  against a mounted image and it will always find nothing — which is"
    echo "  indistinguishable from a broken check. Calibrate against an app you"
    echo "  know persists before trusting an empty result."
  fi
  echo "=================================================================="
  echo "$INFO Enumerated from the system, not from documentation. A daemon whose"
  echo "  program lives outside the bundle is NOT covered by the baseline and"
  echo "  must be verified separately."
  exit 0
fi

if [[ "$MODE" == "sysowner" ]]; then
  echo "=================================================================="
  echo " Installed-bundle ownership and writability (read-only)"
  echo " Artifact: $BUNDLE"
  echo "=================================================================="
  echo

  case "$BUNDLE" in
    /Volumes/*)
      echo "$STOP This path is on a mounted volume, so the answer is meaningless."
      echo "  Disk images mount with 'noowners': every file reports the mounting"
      echo "  user rather than the owner recorded in the image. Run this against"
      echo "  the INSTALLED copy instead."
      echo "=================================================================="
      exit 2 ;;
  esac

  total=$(find "$BUNDLE" 2>/dev/null | wc -l | tr -d ' ')
  nonroot=$(find "$BUNDLE" ! -user root 2>/dev/null | wc -l | tr -d ' ')
  writable=$(find "$BUNDLE" \( -perm -g+w -o -perm -o+w \) 2>/dev/null | wc -l | tr -d ' ')
  setid=$(find "$BUNDLE" \( -perm -4000 -o -perm -2000 \) 2>/dev/null | wc -l | tr -d ' ')

  echo "--- Ownership -------------------------------------------------------"
  echo "  bundle root : $(stat -f '%Su:%Sg  %Sp' "$BUNDLE" 2>/dev/null)"
  echo "  files        : $total"
  echo "  owner:group pairs present across the bundle:"
  find "$BUNDLE" -exec stat -f '%Su:%Sg' {} + 2>/dev/null \
    | sort | uniq -c | sort -rn | head -5 | sed 's/^/      /'
  echo
  echo "--- Writability by a less-privileged account ------------------------"
  printf '  not owned by root      : %s\n' "$nonroot"
  printf '  group- or world-writable: %s\n' "$writable"
  printf '  setuid / setgid        : %s\n' "$setid"
  [[ "$writable" -gt 0 ]] && find "$BUNDLE" \( -perm -g+w -o -perm -o+w \) 2>/dev/null \
    | head -5 | sed "s|$BUNDLE/|      |"

  # Ownership only becomes a privilege problem when the bundle carries code that
  # runs with more authority than the account that can rewrite it.
  sysext=$(find "$BUNDLE/Contents/Library/SystemExtensions" -maxdepth 1 -name '*.systemextension' 2>/dev/null | wc -l | tr -d ' ')
  bdaemon=$(find "$BUNDLE/Contents/Library/LaunchDaemons" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
  smpriv=$(/usr/libexec/PlistBuddy -c 'Print :SMPrivilegedExecutables' \
             "$BUNDLE/Contents/Info.plist" 2>/dev/null | grep -c '=' | tr -d ' ')
  privileged=$(( sysext + bdaemon + smpriv ))

  echo
  echo "--- Privileged components this bundle carries -----------------------"
  printf '  system extensions       : %s\n' "$sysext"
  printf '  bundled LaunchDaemons   : %s\n' "$bdaemon"
  printf '  SMPrivilegedExecutables : %s\n' "$smpriv"

  exposed=0
  [[ "$nonroot" -gt 0 || "$writable" -gt 0 || "$setid" -gt 0 ]] && exposed=1

  echo
  echo "--- What that combination means -------------------------------------"
  if [[ "$privileged" -gt 0 && "$exposed" -eq 1 ]]; then
    echo "$STOP This bundle carries privileged components AND can be modified by"
    echo "  an account that is not root. Anything able to write here can alter"
    echo "  code that runs with elevated privilege. Investigate before trusting"
    echo "  this install."
  elif [[ "$privileged" -gt 0 ]]; then
    echo "$OK Privileged components are present, and the bundle is root-owned and"
    echo "  not group/world-writable — so a non-root account cannot rewrite them."
  elif [[ "$exposed" -eq 1 ]]; then
    echo "$INFO Owned by a non-root account, but this bundle declares no privileged"
    echo "  components. That is normal for a drag-installed user application and is"
    echo "  not by itself a finding."
  else
    echo "$OK Root-owned, not writable by group or others, no setuid/setgid."
  fi

  echo
  echo "=================================================================="
  echo "$INFO This is SYSTEM STATE, not a baseline invariant, and it is not a"
  echo "  verdict. Ownership cannot be baselined — see --help. Record the"
  echo "  figures in the report; a human owns the decision."
  exit 0
fi

collect_facts "$BUNDLE" "$WORK/new.txt"

# Not "is the file non-empty": notarization and gatekeeper records are written
# for ANY path, so this file is never empty. Without a component record a
# baseline would carry no identity anchor at all, and every later drift check
# against it would report "No drift" while proving nothing.
if [[ "$(awk -F'\t' '$1=="component"' "$WORK/new.txt" | grep -c .)" -eq 0 ]]; then
  echo "$STOP No signed Mach-O components found in: $BUNDLE"
  echo "$INFO Point this at an .app bundle, not a disk image or an archive."
  exit 2
fi

if [[ "$MODE" == "record" ]]; then
  emit_baseline "$BUNDLE" "$WORK/new.txt"
  exit 0
fi

# A schema-1 baseline has no persistence records, so comparing it against a
# schema-2 collection would report every new record type as drift. Drop the
# newer record types rather than inventing a finding that isn't one.
BASE_SCHEMA=$(sed -n 's/^# ECISF known-artifact baseline (schema \([0-9][0-9]*\)).*/\1/p' "$BASELINE" | head -1)
[[ -z "$BASE_SCHEMA" ]] && BASE_SCHEMA=1
if [[ "$BASE_SCHEMA" -lt "$ARTIFACT_FACTS_SCHEMA" ]]; then
  awk -F'\t' '$1!="persistence" && $1!="privileged-helper"' "$WORK/new.txt" > "$WORK/new.trimmed"
  mv "$WORK/new.trimmed" "$WORK/new.txt"
  SCHEMA_NOTE=1
fi

# Baselines recorded before the plutil-stdout fix hold parse-error text as
# entitlement records for components that simply have none. Those were never
# facts about the artifact, so drop them rather than reporting their
# disappearance as a dropped privilege.
grep -v '^#' "$BASELINE" | grep -v '^$' \
  | grep -v 'Cannot parse a NULL or zero-length data' | sort > "$WORK/base.txt"

# comm produces nonsense, not an error, if either side is out of byte order.
# Assert it rather than trusting it: a desynchronised comm looks like drift.
if ! sort -c "$WORK/base.txt" 2>/dev/null || ! sort -c "$WORK/new.txt" 2>/dev/null; then
  echo "$STOP Fact files are not in the byte order comm requires, so any"
  echo "  comparison below would be unreliable. This is a tool fault, not a"
  echo "  finding about the artifact. Check that LC_ALL=C is in effect."
  exit 2
fi

comm -23 "$WORK/base.txt" "$WORK/new.txt" > "$WORK/removed.txt"
comm -13 "$WORK/base.txt" "$WORK/new.txt" > "$WORK/added.txt"

echo "=================================================================="
echo " Known-artifact drift check (read-only)"
echo " Baseline: $BASELINE"
echo " Artifact: $BUNDLE"
echo "=================================================================="

if [[ "${SCHEMA_NOTE:-0}" -eq 1 ]]; then
  echo
  echo "$WARN Baseline is schema $BASE_SCHEMA; this script records schema $ARTIFACT_FACTS_SCHEMA."
  echo "  Persistence and privileged-helper records were NOT compared, because"
  echo "  the baseline predates them. Re-record a baseline to cover them."
fi

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
    persistence*)
      echo "$STOP PERSISTENCE REMOVED: $line"; critical=1 ;;
    privileged-helper*)
      echo "$STOP PRIVILEGED HELPER REMOVED: $line"; critical=1 ;;
  esac
done < "$WORK/removed.txt"
while IFS= read -r line; do
  case "$line" in
    teamid*|authority*|notarization*|gatekeeper*|cdflags*)
      echo "$STOP CHANGED (now): $line"; critical=1 ;;
    entitlement*)
      echo "$STOP NEW PRIVILEGE:  $line"; critical=1 ;;
    persistence*)
      echo "$STOP NEW PERSISTENCE: $line"; critical=1 ;;
    privileged-helper*)
      echo "$STOP NEW PRIVILEGED HELPER: $line"; critical=1 ;;
    nonapple-lib*)
      echo "$STOP NEW NON-APPLE LIBRARY: $line"; critical=1 ;;
  esac
done < "$WORK/added.txt"
[[ $critical -eq 0 ]] && echo "$OK Team ID, authority, notarization, flags, entitlements, persistence and libraries unchanged."

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
