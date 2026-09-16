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
# This is the OFFLINE half. Advisory lookups and the submodule resolvability
# probe need the network and arrive behind explicit opt-in flags.
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
  -h, --help           Show this message.

What it does NOT do:
  It does not clone, fetch, build, install or execute anything. Stage the tree
  yourself first, and never let the clone pull submodules:
      git clone --depth 1 --no-recurse-submodules -b <tag> <url> quarantine/x
  Submodules stay uninitialised on purpose: an uninitialised submodule is a
  pointer you can read, not code you have fetched.

Exit codes (they describe findings, never approval):
  0  Evidence collected; no blocking fact found.
  1  A blocking fact: a build file matched a fetch-and-run / privilege pattern.
     This outranks 2 — inconclusive sections are still printed.
  2  Inconclusive: bad arguments, not a git repository, a build system that
     could not be parsed, or a content sweep that scanned nothing.
EOF
}

SRC=""; EXPECT_SHA=""; EXCLUDES=""
while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    -h|--help) usage; exit 0 ;;
    --expect-sha) shift; EXPECT_SHA="${1:-}"; shift || true ;;
    --exclude)    shift; EXCLUDES="$EXCLUDES ${1:-}"; shift || true ;;
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

if [[ "$gl_n" -gt 0 ]]; then
  echo
  while IFS="$(printf '\t')" read -r sha p; do
    [[ -n "$p" ]] || continue
    url=$(git config -f "$SRC/.gitmodules" --get-regexp '^submodule\..*\.path$' 2>/dev/null \
          | awk -v want="$p" '$2==want {print $1}' \
          | sed 's/\.path$/.url/' \
          | while read -r key; do git config -f "$SRC/.gitmodules" --get "$key" 2>/dev/null; done)
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
  echo "  is a network question and is not answered here. That probe found the"
  echo "  only material supply-chain defect in this framework's worked example."
fi

# --- SwiftPM pins ----------------------------------------------------------
echo
echo "--- SwiftPM pins (Package.resolved) ---------------------------------"
resolved=$(find "$SRC" -name 'Package.resolved' -not -path '*/.git/*' 2>/dev/null | LC_ALL=C sort)
if [[ -z "$resolved" ]]; then
  echo "$INFO No Package.resolved found. Absent is normal for projects that use"
  echo "  no SwiftPM dependencies; it is a finding only if the project declares"
  echo "  them in Package.swift without committing a lockfile."
else
  printf '%s\n' "$resolved" | while read -r rf; do
    [[ -n "$rf" ]] || continue
    echo "  ${rf#"$SRC"/}"
    if ! jq -e . "$rf" >/dev/null 2>&1; then
      echo "    $STOP not valid JSON — not read"
      continue
    fi
    jq -r '
      ((.pins // .object.pins) // []) as $p
      | if ($p | length) == 0 then "    (no pins recorded)"
        else ( $p[]
               | "    \(.identity // .package // "?")  \(.state.version // .state.branch // "NO VERSION")  \(.state.revision // "NO REVISION")" )
        end' "$rf" 2>/dev/null
    unpinned=$(jq -r '((.pins // .object.pins) // []) | map(select((.state.revision // "") == "")) | length' "$rf" 2>/dev/null)
    if [[ "${unpinned:-0}" -gt 0 ]]; then
      echo "    $WARN $unpinned dependency/ies carry no immutable revision. A version"
      echo "      range can resolve to different code than the one reviewed."
    fi
  done
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
echo " These are facts, not a verdict. A quiet run is not approval, and"
echo " this half of Phase 2 asked no network questions at all:"
echo " whether each pinned commit is still RETRIEVABLE, and whether any"
echo " dependency carries a published advisory, are both unanswered."
echo "=================================================================="

if [[ "$BLOCKER" -ne 0 ]]; then exit 1; fi
if [[ "$INCONCLUSIVE" -ne 0 ]]; then exit 2; fi
exit 0
