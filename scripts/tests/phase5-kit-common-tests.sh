#!/usr/bin/env bash
# Calibration battery for scripts/phase5-kit/kit-common.sh and the scripts that
# depend on it.
#
# The assertion that matters most is the canary one. 01-setup.sh PLANTS the
# decoy strings and 03-check-canary.sh SEARCHES for them. Those used to be two
# separate literals. Had they ever drifted, the check would have hunted for a
# string that was never written and reported "canary NOT found" — a false clean
# in the one check the Phase 5 finding actually turned on. These tests fail if
# a second copy is ever reintroduced.
#
# Safety: HOME is redirected to a temporary directory before any kit script is
# invoked, so nothing here can plant decoys in a real account.
set -uo pipefail
export LC_ALL=C

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
KIT_DIR="$SCRIPT_DIR/../phase5-kit"
COMMON="$KIT_DIR/kit-common.sh"
[[ -r "$COMMON" ]] || { echo "Missing: $COMMON" >&2; exit 2; }

WORK=$(mktemp -d) || { echo "Could not create a temporary directory." >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
FAKEHOME="$WORK/home"; mkdir -p "$FAKEHOME"

PASSED=0; FAILED=0
ok()  { printf 'PASS: %s\n' "$1"; PASSED=$((PASSED+1)); }
bad() { printf 'FAIL: %s\n' "$1"; FAILED=$((FAILED+1)); }
is()  { if [[ "$2" == "$3" ]]; then ok "$1"; else bad "$1 (expected '$2', got '$3')"; fi; }
has() { if printf '%s' "$2" | grep -q -- "$3"; then ok "$1"; else bad "$1 (missing '$3')"; fi; }

# --- The shared canary definition: the drift this file exists to prevent ----
# Source-level, deliberately. A behavioural test cannot run 01-setup.sh to
# completion from an administrator account, but a reintroduced literal is
# exactly what would cause the drift, and that IS detectable here.
for f in 01-setup.sh 03-check-canary.sh; do
  n=$(grep -c "CANARY-AUDIT-[0-9A-F]" "$KIT_DIR/$f" 2>/dev/null | tr -d ' ')
  is "$f defines no canary literal of its own" "0" "$n"
  if grep -q 'KIT_CANARY_' "$KIT_DIR/$f"; then
    ok "$f uses the shared canary definition"
  else
    bad "$f does not reference KIT_CANARY_*"
  fi
done

# --- No script may hardcode the old shared path -----------------------------
for f in "$KIT_DIR"/*.sh; do
  # Comments may mention it as history; executable lines may not.
  n=$(grep -v '^[[:space:]]*#' "$f" | grep -c '/Users/Shared/phase5-kit' | tr -d ' ')
  is "$(basename "$f") has no hardcoded kit path in executable code" "0" "$n"
done

# --- Library behaviour ------------------------------------------------------
( set +u; . "$COMMON"
  [[ -n "$KIT_CANARY_SSH" && -n "$KIT_CANARY_AWS" && -n "$KIT_CANARY_CAL" ]] ) \
  && ok "all three canary constants are defined and non-empty" \
  || bad "a canary constant is missing or empty"

DISTINCT=$( . "$COMMON"; printf '%s\n%s\n%s\n' "$KIT_CANARY_SSH" "$KIT_CANARY_AWS" "$KIT_CANARY_CAL" | sort -u | grep -c . )
is "the three canaries are distinct from each other" "3" "$DISTINCT"

OUTV=$( . "$COMMON"
        kit_parse_common --kit-root /x/y --listener-port 9100 --subject "Thing 2.0" \
                         --match thing --group-container group.x --probe-ext txt label
        printf '%s|%s|%s|%s|%s|%s' "$KIT_ROOT" "$KIT_PORT" "$KIT_SUBJECT" "$KIT_MATCH" "$KIT_EXT" "$KIT_POSITIONAL" )
is "every shared option is parsed" "/x/y|9100|Thing 2.0|thing|txt|label" "$OUTV"

# --- Bring-your-own probes: the kit must not be tied to Markdown -----------
mkdir -p "$WORK/pack"
printf 'probe hitting @@PORT@@ and climbing @@UP@@etc/hosts\n' > "$WORK/pack/01-custom.txt"
PACKOK=$( . "$COMMON"; KIT_PROBE_PACK="$WORK/pack"; kit_validate_common >/dev/null 2>&1; echo $? )
is "a probe pack directory is accepted" "0" "$PACKOK"
PACKBAD=$( . "$COMMON"; KIT_PROBE_PACK="$WORK/not-a-dir"; kit_validate_common >/dev/null 2>&1; echo $? )
is "a probe pack that is not a directory is rejected" "2" "$PACKBAD"

# An EMPTY pack writes no probes, exercises nothing, and would otherwise end in
# a report indistinguishable from an artifact that behaved perfectly.
mkdir -p "$WORK/emptypack"
OUT_EP=$(HOME="$FAKEHOME" "$KIT_DIR/01-setup.sh" --kit-root "$WORK/kit2" \
         --probe-pack "$WORK/emptypack" 2>&1)
if id -Gn "$(id -un)" | tr ' ' '\n' | grep -qx admin; then
  ok "empty-pack refusal not reachable from an admin account (gate fires first)"
else
  has "an empty probe pack is refused" "$OUT_EP" 'contains no files'
  has "and says why a no-probe run is dangerous" "$OUT_EP" 'tests nothing and would still look clean'
fi
has "--probe-pack is documented" "$( . "$COMMON"; kit_common_options )" '--probe-pack'

( . "$COMMON"; kit_parse_common --nonsense >/dev/null 2>&1 )
is "an unknown flag is rejected" "2" "$?"

( . "$COMMON"; KIT_PORT="abc"; kit_validate_common >/dev/null 2>&1 )
is "a non-numeric port is rejected" "2" "$?"

( . "$COMMON"; KIT_EXT="m d"; kit_validate_common >/dev/null 2>&1 )
is "a non-alphanumeric probe extension is rejected" "2" "$?"

RESOLVED=$( cd "$WORK"; . "$COMMON"; KIT_ROOT="relative/path"; kit_validate_common; printf '%s' "$KIT_ROOT" )
is "a relative kit root is resolved to absolute" "$WORK/relative/path" "$RESOLVED"

ABSKEPT=$( . "$COMMON"; KIT_ROOT="/already/absolute"; kit_validate_common; printf '%s' "$KIT_ROOT" )
is "an absolute kit root is left alone" "/already/absolute" "$ABSKEPT"

# --- Every kit script accepts the shared options ----------------------------
for f in 00-calibrate.sh 01-setup.sh 02-capture.sh 03-check-canary.sh mark.sh; do
  out=$(HOME="$FAKEHOME" "$KIT_DIR/$f" --help 2>&1); rc=$?
  is "$f --help exits 0" "0" "$rc"
  has "$f --help documents --kit-root" "$out" '--kit-root'
done

# --- Safety gate still fires ------------------------------------------------
# HOME is redirected, so even a full run could only write into the temp tree.
OUT_SETUP=$(HOME="$FAKEHOME" "$KIT_DIR/01-setup.sh" --kit-root "$WORK/kit" 2>&1); RC_SETUP=$?
if id -Gn "$(id -un)" | tr ' ' '\n' | grep -qx admin; then
  is  "01-setup.sh refuses to run in an administrator account" "1" "$RC_SETUP"
  has "and names the reason" "$OUT_SETUP" 'is an administrator'
else
  is "01-setup.sh ran in a non-admin account without error" "0" "$RC_SETUP"
  has "and wrote probes with the requested extension" "$OUT_SETUP" 'Probe files written'
fi
is "nothing was written to the real home directory" "no" \
   "$([[ -e "$HOME/probe/canaries.txt" && ! -e "$FAKEHOME/probe/canaries.txt" ]] && echo yes || echo no)"

# --- mark.sh positional handling -------------------------------------------
HOME="$FAKEHOME" "$KIT_DIR/mark.sh" >/dev/null 2>&1
is "mark.sh with no label exits 1" "1" "$?"
HOME="$FAKEHOME" "$KIT_DIR/mark.sh" not-a-real-label >/dev/null 2>&1
is "mark.sh rejects an unknown label" "1" "$?"
HOME="$FAKEHOME" "$KIT_DIR/mark.sh" prep-start --kit-root "$WORK/marks" >/dev/null 2>&1
is "mark.sh accepts a label alongside shared options" "0" "$?"
is "and wrote the timestamp under the given kit root" "1" \
   "$(grep -c 'prep-start' "$WORK/marks/out/timestamps.txt" 2>/dev/null | tr -d ' ')"

echo "=================================================================="
echo "passed $PASSED   failed $FAILED"
echo "Green means the kit reads its configuration from one place and the"
echo "planted canary cannot drift from the searched one. It says nothing"
echo "about whether any Phase 5 environment is correctly isolated."
[[ "$FAILED" -eq 0 ]]
