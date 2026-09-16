#!/usr/bin/env bash
# Read-only Phase 2 supply-chain evidence collector.
#
# Gathers the deterministic half of docs/phases/phase-2-supply-chain.md from a
# source tree YOU have already staged: dependency pins, submodule inventory,
# the build files the build system actually invokes, and a content sweep for
# build-time red flags.
#
# It never clones, fetches, builds, installs or executes anything. Acquisition
# stays a human step, exactly as expanding an archive does in Phase 4 — where an
# action is needed, the exact command is printed for a human to run.
#
# This is the OFFLINE half by default. Advisory lookups and the submodule
# resolvability probe need the network and are behind two SEPARATE opt-in flags,
# because they differ in a way that matters: --online contacts destinations THIS
# SCRIPT chose, while --probe-pins contacts destinations THE ARTIFACT chose.
#
# It emits FACTS. It does not emit a verdict, and a quiet run is not approval.
set -uo pipefail

# Byte collation, not locale collation: sort and comm must agree or comm
# silently reports unrelated lines as differences. See lib/artifact-facts.sh.
export LC_ALL=C

OK="✅"; WARN="⚠️"; STOP="🛑"; INFO="•"

usage() {
  cat <<'EOF'
Usage:
  scripts/phase2-supplychain.sh <source-tree> [options]

Collects Phase 2 supply-chain evidence from a source tree already on disk —
one you cloned yourself, read-only, into quarantine/.

Options:
  --expect-sha <sha>   The commit the review is pinned to. Compared against
                       HEAD, because auditing one revision and running another
                       is the failure this whole phase exists to prevent.
  --exclude <dir>      A vendored subtree to exclude from the content sweep.
                       Repeatable. Excluded paths are COUNTED and NAMED, never
                       dropped silently — an exclusion list that swallows the
                       whole tree produces a clean-looking sweep of nothing.
  --online             Allow advisory lookups against api.osv.dev. OFF by
                       default. Destinations are fixed and chosen by THIS
                       SCRIPT, never by the artifact under review.
  --probe-pins         Ask each submodule's own origin whether its pinned commit
                       can still be retrieved. Requires --online, and is a
                       separate flag on purpose: the hosts contacted here come
                       out of the artifact's .gitmodules. Only https:// URLs are
                       accepted, and every URL is printed before it is used.
  --osv-json <file>    Classify an advisory response you fetched yourself
                       instead of querying. Makes a fully offline run possible.
  -h, --help           Show this message.

Environment:
  ECISF_OSV_URL        Point advisory queries at a mirror or proxy instead of
                       api.osv.dev.
  ECISF_OSV_CAL_*      Repoint the calibration reference (ECO, NAME, BAD, GOOD)
                       if the advisory it relies on ever changes upstream.

What it does NOT do:
  It does not clone, fetch, build, install or execute anything from the tree.
  Stage the tree yourself first, and never let the clone pull submodules:
      git clone --depth 1 --no-recurse-submodules -b <tag> <url> quarantine/x
  Submodules stay uninitialised on purpose: an uninitialised submodule is a
  pointer you can read, not code you have fetched. --probe-pins asks whether a
  commit EXISTS; it never checks one out.

Exit codes (they describe findings, never approval):
  0  Evidence collected; no blocking fact found.
  1  A blocking fact: a build file matched a fetch-and-run / privilege pattern,
     or a pinned commit could not be retrieved from an origin that IS reachable.
     This outranks 2 — inconclusive sections are still printed.
  2  Inconclusive: bad arguments, not a git repository, a build system that
     could not be parsed, a content sweep that scanned nothing, or an advisory
     query whose calibration failed.
EOF
}

SRC=""; EXPECT_SHA=""; EXCLUDES=""; ONLINE=0; PROBE_PINS=0; OSV_JSON=""
while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    -h|--help) usage; exit 0 ;;
    --expect-sha) shift; EXPECT_SHA="${1:-}"; shift || true ;;
    --exclude)    shift; EXCLUDES="$EXCLUDES ${1:-}"; shift || true ;;
    --osv-json)   shift; OSV_JSON="${1:-}"; shift || true ;;
    --online)     ONLINE=1; shift ;;
    --probe-pins) PROBE_PINS=1; shift ;;
    -*) echo "$STOP Unrecognised argument: $1"; echo; usage; exit 2 ;;
    *)
      if [[ -n "$SRC" ]]; then
        echo "$STOP More than one source tree given: $SRC and $1"; exit 2
      fi
      SRC="$1"; shift ;;
  esac
done

[[ -z "$SRC" ]] && { usage; exit 2; }
[[ -d "$SRC" ]] || { echo "$STOP Source tree not found: $SRC"; exit 2; }
SRC="${SRC%/}"

for t in git jq plutil awk sed grep find; do
  command -v "$t" >/dev/null 2>&1 || { echo "$STOP Required tool missing: $t"; exit 2; }
done

# The pin probe hands a URL out of the artifact's own .gitmodules to git. That
# is a different risk class from querying an endpoint this script chose, so it
# needs its own deliberate keystroke rather than riding along on --online.
if [[ "$PROBE_PINS" -eq 1 && "$ONLINE" -eq 0 ]]; then
  echo "$STOP --probe-pins requires --online."
  echo "  They are separate because they differ in who picks the destination:"
  echo "  --online contacts endpoints this script chose; --probe-pins contacts"
  echo "  hosts named by the artifact you are reviewing."
  exit 2
fi
if [[ -n "$OSV_JSON" && ! -f "$OSV_JSON" ]]; then
  echo "$STOP --osv-json file not found: $OSV_JSON"; exit 2
fi

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [[ "$ONLINE" -eq 1 || -n "$OSV_JSON" ]]; then
  if [[ ! -r "$SCRIPT_DIR/lib/advisory-query.sh" ]]; then
    echo "$STOP Missing shared classifier: $SCRIPT_DIR/lib/advisory-query.sh" >&2
    exit 2
  fi
  # shellcheck source=lib/advisory-query.sh
  . "$SCRIPT_DIR/lib/advisory-query.sh"
  advisory_require_tools || exit 2
  command -v curl >/dev/null 2>&1 || { echo "$STOP Required tool missing: curl"; exit 2; }
fi

WORK=$(mktemp -d) || { echo "$STOP Could not create a temporary directory."; exit 2; }
trap 'rm -rf "$WORK"' EXIT

BLOCKER=0; INCONCLUSIVE=0

echo "=================================================================="
echo " Phase 2 — supply-chain evidence (read-only, offline)"
echo " Source tree: $SRC"
echo " Collected: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=================================================================="

# --- Pinned revision -------------------------------------------------------
echo
echo "--- Pinned revision -------------------------------------------------"
if ! git -C "$SRC" rev-parse --git-dir >/dev/null 2>&1; then
  echo "$WARN Not a git repository, so no revision, submodule or gitlink"
  echo "  evidence can be gathered. Dependency and build-file sections below"
  echo "  still apply."
  HEAD_SHA=""
  INCONCLUSIVE=1
else
  HEAD_SHA=$(git -C "$SRC" rev-parse HEAD 2>/dev/null)
  echo "  HEAD: ${HEAD_SHA:-<unreadable>}"
  if [[ -n "$EXPECT_SHA" ]]; then
    want=$(printf '%s' "$EXPECT_SHA" | tr 'A-Z' 'a-z' | tr -cd '0-9a-f')
    got=$(printf '%s' "${HEAD_SHA:-}" | tr 'A-Z' 'a-z' | tr -cd '0-9a-f')
    if [[ -z "$want" ]]; then
      echo "$STOP --expect-sha is not a hexadecimal commit id. Nothing compared."
      INCONCLUSIVE=1
    elif [[ "$got" == "$want"* ]]; then
      echo "$OK  matches the pinned revision"
    else
      echo "$STOP HEAD does NOT match the pinned revision"
      echo "      expected: $want"
      echo "      actual  : $got"
      echo "  You would be auditing a different revision from the one recorded."
      INCONCLUSIVE=1
    fi
  else
    echo "$WARN No --expect-sha given, so the revision was NOT verified."
  fi
fi

# --- Submodules ------------------------------------------------------------
# git ls-tree, not `git submodule status`: on an uninitialised clone the latter
# reported 1 of 4 submodules in a real audit. Gitlinks are in the tree object
# whether or not anything has been checked out.
echo
echo "--- Submodules (gitlinks in the tree) -------------------------------"
: > "$WORK/gitlinks.txt"
if [[ -n "$HEAD_SHA" ]]; then
  git -C "$SRC" ls-tree -r HEAD 2>/dev/null \
    | sed -n 's/^160000 commit \([0-9a-f][0-9a-f]*\)'"$(printf '\t')"'/\1'"$(printf '\t')"'/p' \
    > "$WORK/gitlinks.txt"
fi
gl_n=$(grep -c . "$WORK/gitlinks.txt" | tr -d ' ')

: > "$WORK/gmpaths.txt"
if [[ -f "$SRC/.gitmodules" ]]; then
  git config -f "$SRC/.gitmodules" --list 2>/dev/null > "$WORK/gmraw.txt"
  sed -n 's/^submodule\.\(.*\)\.path=\(.*\)$/\1'"$(printf '\t')"'\2/p' "$WORK/gmraw.txt" \
    | LC_ALL=C sort > "$WORK/gmpaths.txt"
fi
gm_n=$(grep -c . "$WORK/gmpaths.txt" | tr -d ' ')

echo "  gitlinks recorded in the tree : $gl_n"
echo "  .gitmodules entries           : $gm_n"

if [[ -f "$SRC/.gitmodules" && "$gl_n" -eq 0 && -n "$HEAD_SHA" ]]; then
  echo "$STOP A .gitmodules file exists but NO gitlinks were found in the tree."
  echo "  That is a parsing failure, not an absence of submodules."
  INCONCLUSIVE=1
fi

: > "$WORK/pins.txt"
if [[ "$gl_n" -gt 0 ]]; then
  echo
  while IFS="$(printf '\t')" read -r sha p; do
    [[ -n "$p" ]] || continue
    url=$(git config -f "$SRC/.gitmodules" --get-regexp '^submodule\..*\.path$' 2>/dev/null \
          | awk -v want="$p" '$2==want {print $1}' \
          | sed 's/\.path$/.url/' \
          | while read -r key; do git config -f "$SRC/.gitmodules" --get "$key" 2>/dev/null; done)
    printf '%s\t%s\t%s\n' "$p" "$sha" "$url" >> "$WORK/pins.txt"
    if [[ -z "$url" ]]; then
      echo "  $WARN $p"
      echo "        $sha"
      echo "        no .gitmodules entry — a pinned commit with no declared origin"
    else
      echo "  $INFO $p"
      echo "        $sha"
      echo "        $url"
    fi
  done < "$WORK/gitlinks.txt"

  # Declared-but-absent is the other direction of the same mismatch.
  while IFS="$(printf '\t')" read -r name p; do
    [[ -n "$p" ]] || continue
    if ! awk -F"$(printf '\t')" -v want="$p" '$2==want {found=1} END{exit !found}' "$WORK/gitlinks.txt"; then
      echo "  $WARN .gitmodules declares '$name' at '$p' but the tree has no gitlink there"
    fi
  done < "$WORK/gmpaths.txt"

  echo
  echo "$INFO Whether each pinned commit can still be RETRIEVED from its origin"
  if [[ "$PROBE_PINS" -eq 0 ]]; then
    echo "  is a network question. Pass --online --probe-pins to ask it. That probe"
    echo "  found the only material supply-chain defect in this framework's"
    echo "  worked example, in seconds."
  else
    echo "  is asked below."
  fi
fi

# --- SwiftPM pins ----------------------------------------------------------
# Parsed HERE, ahead of the probe and the advisory queries, because a SwiftPM
# pin carries an immutable revision exactly as a submodule gitlink does and so
# belongs in the same two questions: can it still be retrieved, and does it
# carry a published advisory. Parsing it later left those unasked.
echo
echo "--- SwiftPM pins (Package.resolved) ---------------------------------"
resolved=$(find "$SRC" -name 'Package.resolved' -not -path '*/.git/*' 2>/dev/null | LC_ALL=C sort)
if [[ -z "$resolved" ]]; then
  echo "$INFO No Package.resolved found. Absent is normal for projects that use"
  echo "  no SwiftPM dependencies; it is a finding only if the project declares"
  echo "  them in Package.swift without committing a lockfile."
else
  # Heredoc rather than a pipeline: a pipeline runs the loop in a subshell and
  # an INCONCLUSIVE set inside it would be discarded.
  while read -r rf; do
    [[ -n "$rf" ]] || continue
    echo "  ${rf#"$SRC"/}"
    if ! jq -e . "$rf" >/dev/null 2>&1; then
      echo "    $STOP not valid JSON — not read"
      INCONCLUSIVE=1
      continue
    fi
    jq -r '
      ((.pins // .object.pins) // []) as $p
      | if ($p | length) == 0 then "    (no pins recorded)"
        else ( $p[]
               | "    \(.identity // .package // "?")  \(.state.version // .state.branch // "NO VERSION")  \(.state.revision // "NO REVISION")" )
        end' "$rf" 2>/dev/null
    jq -r '((.pins // .object.pins) // [])[]
           | select((.state.revision // "") != "")
           | "\(.identity // .package // "?")\t\(.state.revision)\t\(.location // .repositoryURL // "")"' \
      "$rf" 2>/dev/null >> "$WORK/pins.txt"
    unpinned=$(jq -r '((.pins // .object.pins) // []) | map(select((.state.revision // "") == "")) | length' "$rf" 2>/dev/null)
    if [[ "${unpinned:-0}" -gt 0 ]]; then
      echo "    $WARN $unpinned dependency/ies carry no immutable revision. A version"
      echo "      range can resolve to different code than the one reviewed."
    fi
  done <<EOF
$resolved
EOF
fi

# --- Pin resolvability (network, opt-in) -----------------------------------
# Only https, checked here rather than left to git. A .gitmodules URL is
# attacker-controlled input, and git's ext:: transport executes a command --
# handing one to git unchecked would cross the line this whole framework draws.
url_is_safe() {
  case "$1" in
    https://*) ;;
    *) return 1 ;;
  esac
  case "$1" in
    *[[:space:]]*) return 1 ;;
  esac
  return 0
}

# Ask twice, because one question cannot tell "your network is down" apart from
# "that commit is gone", and those are completely different findings.
probe_reachable() {
  GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/usr/bin/true \
  git -c protocol.allow=never -c protocol.https.allow=always \
      -c core.hooksPath=/dev/null -c credential.helper= \
      -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=20 \
      ls-remote --heads "$1" >/dev/null 2>&1
}
probe_commit() {
  GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/usr/bin/true \
  git -c protocol.allow=never -c protocol.https.allow=always \
      -c core.hooksPath=/dev/null -c credential.helper= \
      -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=20 \
      -C "$2" fetch --depth 1 --no-recurse-submodules --no-tags -q "$1" "$3" >/dev/null 2>&1
}

if [[ "$PROBE_PINS" -eq 1 ]]; then
  echo
  echo "--- Pin resolvability (network) --------------------------------------"
  if [[ ! -s "$WORK/pins.txt" ]]; then
    echo "$INFO No pinned dependencies to probe."
  else
    echo "  These hosts come from the ARTIFACT's own dependency files, not from"
    echo "  this script. Nothing has been contacted yet:"
    awk -F"$(printf '\t')" '{print "      " ($3=="" ? "<no url declared>" : $3)}' "$WORK/pins.txt" \
      | LC_ALL=C sort -u
    echo
    git init -q --bare "$WORK/probe.git" 2>/dev/null
    while IFS="$(printf '\t')" read -r p sha url; do
      [[ -n "$p" ]] || continue
      if [[ -z "$url" ]]; then
        echo "  $WARN $p — no declared origin, nothing to ask"
        INCONCLUSIVE=1
        continue
      fi
      if ! url_is_safe "$url"; then
        echo "  $STOP $p — REFUSED, not a plain https URL:"
        echo "        $url"
        echo "        git transports such as ext:: can execute a command. This"
        echo "        URL was never passed to git."
        INCONCLUSIVE=1
        continue
      fi
      if ! probe_reachable "$url"; then
        echo "  $WARN $p — origin UNREACHABLE"
        echo "        $url"
        echo "        Could be the network, could be the repository. Not a"
        echo "        finding about the artifact until the origin answers."
        INCONCLUSIVE=1
        continue
      fi
      if probe_commit "$url" "$WORK/probe.git" "$sha"; then
        echo "  $OK  $p — pinned commit RETRIEVABLE"
      else
        echo "  $STOP $p — origin is reachable but the pinned commit is NOT"
        echo "        $sha"
        echo "        $url"
        echo "        The code this project pins cannot be read, diffed against"
        echo "        upstream, or version-matched. That is a verifiability gap,"
        echo "        not proof of tampering — and it is not resolvable here."
        BLOCKER=1
      fi
    done < "$WORK/pins.txt"
  fi
fi

# --- Advisory lookups (network or injected, opt-in) ------------------------
# Querying and calibration live in lib/advisory-query.sh, so Phase 1 and Phase 2
# cannot end up asking the same question two slightly different ways.

if [[ "$ONLINE" -eq 1 || -n "$OSV_JSON" ]]; then
  echo
  echo "--- Advisories ------------------------------------------------------"
fi

CALIBRATED=0
if [[ "$ONLINE" -eq 1 ]]; then
  if advisory_osv_calibrate "$WORK"; then
    CALIBRATED=1
  else
    INCONCLUSIVE=1
  fi
fi

if [[ -n "$OSV_JSON" ]]; then
  echo
  echo "  Supplied response: $OSV_JSON"
  if advisory_classify "$OSV_JSON" "$WORK/supplied.facts"; then
    advisory_summary "$WORK/supplied.facts" "the supplied query"
  else
    echo "  $STOP the supplied response could not be classified."
    INCONCLUSIVE=1
  fi
fi

# Pins are queried BY COMMIT. Both submodule gitlinks and SwiftPM pins carry an
# immutable revision, so no package-name or ecosystem guess is needed to ask the
# question — and a wrong name would have produced a confident, empty answer.
if [[ "$ONLINE" -eq 1 && "$CALIBRATED" -eq 1 && -s "$WORK/pins.txt" ]]; then
  echo
  echo "  Pinned commits, queried by revision:"
  while IFS="$(printf '\t')" read -r p sha url; do
    [[ -n "$sha" ]] || continue
    echo "    $p  ${sha}"
    if advisory_osv_query "{\"commit\":\"$sha\"}" "$WORK/pin.json" \
       && advisory_classify "$WORK/pin.json" "$WORK/pin.facts" 2>/dev/null; then
      advisory_summary "$WORK/pin.facts" "$p" | sed 's/^/    /'
    else
      echo "      $STOP query inconclusive for this pin — not a clean result."
      INCONCLUSIVE=1
    fi
  done < "$WORK/pins.txt"
fi

# --- Build files, from the build system ------------------------------------
# A filename search for "Makefile" missed dependencies/MakefilePCRE and
# MakefileJPCRE in a real audit and would have shipped a false clean. The build
# system is the authority on what actually runs.
echo
echo "--- Build files, enumerated from the BUILD SYSTEM --------------------"
pbx=$(find "$SRC" -name 'project.pbxproj' -not -path '*/.git/*' 2>/dev/null | LC_ALL=C sort)
: > "$WORK/buildfiles.txt"
legacy_total=0; script_total=0; proj_n=0

if [[ -z "$pbx" ]]; then
  echo "$INFO No Xcode project found; nothing to enumerate this way."
else
  while read -r p; do
    [[ -n "$p" ]] || continue
    proj_n=$((proj_n + 1))
    if ! plutil -convert json -o "$WORK/pbx.json" -- "$p" >/dev/null 2>&1 \
       || ! jq -e . "$WORK/pbx.json" >/dev/null 2>&1; then
      echo "  $STOP ${p#"$SRC"/} could not be parsed — NOT an absence of build steps"
      INCONCLUSIVE=1
      continue
    fi
    obj_n=$(jq -r '(.objects // {}) | length' "$WORK/pbx.json")
    if [[ "${obj_n:-0}" -eq 0 ]]; then
      echo "  $STOP ${p#"$SRC"/} parsed but contains zero objects — treat as unread"
      INCONCLUSIVE=1
      continue
    fi
    echo "  ${p#"$SRC"/}  ($obj_n objects)"

    jq -r '(.objects // {}) | to_entries[] | select(.value.isa == "PBXLegacyTarget")
           | "    legacy target: \(.value.name // "?")  ->  \(.value.buildToolPath // "?") \(.value.buildArgumentsString // "")  [cwd: \(.value.buildWorkingDirectory // ".")]"' \
      "$WORK/pbx.json"
    n=$(jq -r '[(.objects // {}) | to_entries[] | select(.value.isa == "PBXLegacyTarget")] | length' "$WORK/pbx.json")
    legacy_total=$((legacy_total + ${n:-0}))

    # Build files named by the legacy targets, including non-standard names a
    # filename search will not predict.
    jq -r '(.objects // {}) | to_entries[] | select(.value.isa == "PBXLegacyTarget")
           | "\(.value.buildWorkingDirectory // ".")\t\(.value.buildArgumentsString // "")"' \
      "$WORK/pbx.json" \
      | while IFS="$(printf '\t')" read -r cwd args; do
          f=$(printf '%s\n' "$args" | sed -n 's/.*-f[[:space:]][[:space:]]*\([^[:space:]]*\).*/\1/p')
          [[ -z "$f" ]] && f="Makefile"
          printf '%s/%s\n' "${cwd:-.}" "$f" | sed 's|^\./||'
        done >> "$WORK/buildfiles.txt"

    s=$(jq -r '[(.objects // {}) | to_entries[] | select(.value.isa == "PBXShellScriptBuildPhase")] | length' "$WORK/pbx.json")
    script_total=$((script_total + ${s:-0}))
    if [[ "${s:-0}" -gt 0 ]]; then
      echo "    $WARN $s run-script build phase(s) — arbitrary shell at build time:"
      jq -r '(.objects // {}) | to_entries[] | select(.value.isa == "PBXShellScriptBuildPhase")
             | "      " + ((.value.shellScript // "") | gsub("\n"; " ⏎ ") | .[0:160])' "$WORK/pbx.json"
    fi
  done <<EOF
$pbx
EOF

  echo
  echo "  Xcode projects parsed          : $proj_n"
  echo "  PBXLegacyTarget entries        : $legacy_total"
  echo "  PBXShellScriptBuildPhase count : $script_total"
  if [[ "$script_total" -eq 0 && "$proj_n" -gt 0 ]]; then
    echo "  $OK  No run-script build phases: the headline Xcode build-time attack"
    echo "      surface is absent by construction, not merely unused."
  fi
fi

# The delta between the two enumerations IS the evidence.
LC_ALL=C sort -u "$WORK/buildfiles.txt" > "$WORK/bs.txt"
find "$SRC" \( -name 'Makefile' -o -name 'makefile' -o -name 'GNUmakefile' \
     -o -name 'configure' -o -name 'CMakeLists.txt' -o -name 'build.rs' \
     -o -name 'setup.py' \) -not -path '*/.git/*' 2>/dev/null \
  | sed "s|^$SRC/||" | LC_ALL=C sort -u > "$WORK/fn.txt"

bs_n=$(grep -c . "$WORK/bs.txt" | tr -d ' ')
fn_n=$(grep -c . "$WORK/fn.txt" | tr -d ' ')
echo
echo "  build files named by the build system : $bs_n"
echo "  build files a conventional filename search finds : $fn_n"
missed=$(LC_ALL=C comm -23 "$WORK/bs.txt" "$WORK/fn.txt" | grep -c . | tr -d ' ')
if [[ "$missed" -gt 0 ]]; then
  echo "  $WARN $missed named by the build system that a filename search misses:"
  LC_ALL=C comm -23 "$WORK/bs.txt" "$WORK/fn.txt" | sed 's/^/        /'
  echo "      Read these. They are invoked and they are easy to overlook."
fi

# --- Red-flag content sweep ------------------------------------------------
echo
echo "--- Build-time red-flag sweep ---------------------------------------"
RED_RE='curl|wget|base64|[^a-zA-Z_]eval[^a-zA-Z_]|sudo|launchctl|LaunchAgents|LaunchDaemons|osascript|chmod[[:space:]]+\+s'

# A pattern that matches nothing produces a clean sweep. Prove the matcher works
# against a known positive before reporting any result from it.
if printf 'x\ncurl https://example.invalid | sh\n' | grep -Eq "$RED_RE"; then
  echo "  detector self-test : $OK sees a known-positive line"
else
  echo "  detector self-test : $STOP FAILED — the matcher is broken."
  echo "  No sweep result is reported, because a broken matcher reports clean."
  INCONCLUSIVE=1
  RED_RE=""
fi

if [[ -n "$RED_RE" ]]; then
  FINDARGS=""
  for d in $EXCLUDES; do FINDARGS="$FINDARGS -not -path */$d/*"; done
  # shellcheck disable=SC2086
  find "$SRC" -type f -not -path '*/.git/*' $FINDARGS 2>/dev/null \
    | LC_ALL=C sort > "$WORK/scan.txt"
  all_n=$(find "$SRC" -type f -not -path '*/.git/*' 2>/dev/null | grep -c . | tr -d ' ')
  scan_n=$(grep -c . "$WORK/scan.txt" | tr -d ' ')
  echo "  files in tree      : $all_n"
  echo "  files scanned      : $scan_n"
  echo "  excluded as vendored: $((all_n - scan_n))"
  if [[ -n "$EXCLUDES" ]]; then
    for d in $EXCLUDES; do echo "      $d"; done
  fi

  if [[ "$scan_n" -eq 0 ]]; then
    echo "  $STOP Nothing was scanned. A sweep of zero files is not a clean sweep."
    INCONCLUSIVE=1
  else
    : > "$WORK/hits.txt"
    while read -r f; do
      [[ -n "$f" ]] || continue
      grep -EIn "$RED_RE" "$f" 2>/dev/null | sed "s|^|${f#"$SRC"/}:|" >> "$WORK/hits.txt"
    done < "$WORK/scan.txt"
    hit_n=$(grep -c . "$WORK/hits.txt" | tr -d ' ')
    if [[ "$hit_n" -eq 0 ]]; then
      echo "  $OK  no matching lines in $scan_n scanned files"
      echo "      A calibrated zero. It covers only the patterns above, and only"
      echo "      the files that were not excluded."
    else
      echo "  $STOP $hit_n matching line(s) — read every one, they are not all malicious:"
      sed 's/^/      /' "$WORK/hits.txt"
      BLOCKER=1
    fi
  fi
fi

# --- Updater configuration -------------------------------------------------
echo
echo "--- Updater configuration -------------------------------------------"
sufound=0
find "$SRC" -name 'Info.plist' -not -path '*/.git/*' 2>/dev/null | LC_ALL=C sort > "$WORK/plists.txt"
while read -r pl; do
  [[ -n "$pl" ]] || continue
  plutil -convert json -o "$WORK/pl.json" -- "$pl" >/dev/null 2>&1 || continue
  jq -e . "$WORK/pl.json" >/dev/null 2>&1 || continue
  keys=$(jq -r 'to_entries[] | select(.key | startswith("SU")) | "      \(.key) = \(.value)"' "$WORK/pl.json" 2>/dev/null)
  if [[ -n "$keys" ]]; then
    sufound=1
    echo "  ${pl#"$SRC"/}"
    printf '%s\n' "$keys"
  fi
done < "$WORK/plists.txt"
if [[ "$sufound" -eq 0 ]]; then
  echo "$INFO No Sparkle (SU*) keys found in any Info.plist."
else
  echo "  $WARN An auto-updater is a channel for new code to arrive AFTER this"
  echo "      version is approved. Note whether checks are opt-in and whether"
  echo "      updates are signature-verified."
fi

# --- Close -----------------------------------------------------------------
echo
echo "=================================================================="
echo " These are facts, not a verdict. A quiet run is not approval."
if [[ "$PROBE_PINS" -eq 0 ]]; then
  echo " NOT asked: whether each pinned commit is still retrievable."
fi
if [[ "$ONLINE" -eq 0 && -z "$OSV_JSON" ]]; then
  echo " NOT asked: whether any dependency carries a published advisory."
fi
echo " Never asked here at all: whether vendored source matches its upstream"
echo " byte for byte, and whether any dependency is trustworthy. Those are"
echo " reading and judgement, and they stay with a human."
echo "=================================================================="

if [[ "$BLOCKER" -ne 0 ]]; then exit 1; fi
if [[ "$INCONCLUSIVE" -ne 0 ]]; then exit 2; fi
exit 0
