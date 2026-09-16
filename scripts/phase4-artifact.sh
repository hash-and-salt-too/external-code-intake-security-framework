#!/usr/bin/env bash
# Read-only Phase 4 evidence collector for a macOS artifact.
#
# Gathers the deterministic half of docs/phases/phase-4-binary-artifact.md:
# integrity, quarantine provenance, nested components, signature, identity,
# notarization, entitlements (optionally diffed against the reviewed source),
# linkage, and whether the bundle actually contains the code it runs.
#
# It never mounts, expands, installs, launches or executes anything. Where an
# action is needed, it prints the exact command for a human to run.
#
# It emits FACTS. It does not emit a verdict, and a quiet run is not approval.
set -uo pipefail

# Byte collation, not locale collation: sort and comm must agree or comm
# silently reports unrelated lines as differences. See artifact-facts.sh.
export LC_ALL=C

OK="✅"; WARN="⚠️"; STOP="🛑"; INFO="•"

# The fact collector is shared with verify-known-artifact.sh so that the
# evidence in a Phase 4 report and the baseline stored for later drift checks
# can never describe the same artifact differently.
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
  scripts/phase4-artifact.sh <bundle> [options]

Collects Phase 4 binary/artifact evidence from a bundle that is already on
disk — one you expanded or mounted read-only yourself.

Options:
  --archive <file>          The downloaded archive or disk image <bundle> came
                            out of. Hashed, and checked for a quarantine tag.
  --published-sha256 <hex>  The digest the project published for that archive.
                            Compared character-for-character.
  --source <dir>            The reviewed source tree. Entitlements found in the
                            artifact are diffed against the *.entitlements
                            files in that tree — the highest-value check here,
                            because it asks whether the shipped binary requests
                            privileges the code you read never declared.
  --baseline-out <file>     Also write a known-artifact baseline from THIS run,
                            for verify-known-artifact.sh to compare against
                            later. Same collector, so the report and the
                            baseline cannot disagree.
  -h, --help                Show this message.

What it does NOT do:
  It does not download, expand, mount, install, launch or execute anything.
  Expansion in particular stays a human step, and must use
      ditto -x -k <archive.zip> <destination>
  never `unzip`, which can corrupt signing metadata and make a genuine
  signature look broken.

Exit codes (they describe findings, never approval):
  0  Evidence collected; no blocking fact found.
  1  A blocking fact: published hash mismatch, or the signature does not verify.
  2  Inconclusive: bad arguments, or nothing signed was found to read.
EOF
}

BUNDLE=""; ARCHIVE=""; PUBLISHED=""; SRCDIR=""; BASELINE_OUT=""

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    -h|--help) usage; exit 0 ;;
    --archive)          shift; ARCHIVE="${1:-}";      shift || true ;;
    --published-sha256) shift; PUBLISHED="${1:-}";    shift || true ;;
    --source)           shift; SRCDIR="${1:-}";       shift || true ;;
    --baseline-out)     shift; BASELINE_OUT="${1:-}"; shift || true ;;
    -*) echo "$STOP Unrecognised argument: $1"; echo; usage; exit 2 ;;
    *)
      if [[ -n "$BUNDLE" ]]; then
        echo "$STOP More than one bundle given: $BUNDLE and $1"; exit 2
      fi
      BUNDLE="$1"; shift ;;
  esac
done

[[ -z "$BUNDLE" ]] && { usage; exit 2; }
[[ -e "$BUNDLE" ]] || { echo "$STOP Artifact not found: $BUNDLE"; exit 2; }
[[ -n "$ARCHIVE" && ! -f "$ARCHIVE" ]] && { echo "$STOP Archive not found: $ARCHIVE"; exit 2; }
[[ -n "$SRCDIR"  && ! -d "$SRCDIR"  ]] && { echo "$STOP Source tree not found: $SRCDIR"; exit 2; }
if [[ -n "$PUBLISHED" && -z "$ARCHIVE" ]]; then
  echo "$STOP --published-sha256 needs --archive: a published digest covers the"
  echo "  downloaded file, not the expanded bundle. Expanding changes the bytes."
  exit 2
fi
artifact_facts_require_tools || exit 2
artifact_facts_require_collation || exit 2

BUNDLE="${BUNDLE%/}"
BLOCKER=0

WORK=$(mktemp -d) || { echo "$STOP Could not create a temporary directory."; exit 2; }
trap 'rm -rf "$WORK"' EXIT

FACTS="$WORK/facts.txt"
collect_facts "$BUNDLE" "$FACTS"

if [[ ! -s "$FACTS" ]]; then
  echo "$STOP No signed Mach-O components found in: $BUNDLE"
  echo "$INFO Point this at an expanded .app bundle, not at an archive or an"
  echo "  unmounted disk image. Expand it yourself first with ditto -x -k."
  exit 2
fi

fact() { awk -F'\t' -v k="$1" '$1==k {print $2}' "$FACTS"; }
# Per-component facts are stored as "<relative-path>|<value>"; most sections
# want the value side only.
fact_values() { fact "$1" | sed 's/^[^|]*|//'; }

echo "=================================================================="
echo " Phase 4 — binary / artifact evidence (read-only)"
echo " Artifact: $BUNDLE"
[[ -n "$ARCHIVE" ]] && echo " Archive:  $ARCHIVE"
echo " Collected: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=================================================================="

# --- 4.1 / 4.2  Acquisition and integrity ---------------------------------
echo
echo "--- Acquisition & integrity -----------------------------------------"
if [[ -n "$ARCHIVE" ]]; then
  arc_sha=$(shasum -a 256 "$ARCHIVE" 2>/dev/null | awk '{print $1}')
  echo "  archive bytes : $(stat -f '%z' "$ARCHIVE" 2>/dev/null)"
  echo "  sha-256       : ${arc_sha:-<unreadable>}"
  if [[ -n "$PUBLISHED" ]]; then
    want=$(printf '%s' "$PUBLISHED" | tr 'A-Z' 'a-z' | tr -cd '0-9a-f')
    got=$(printf '%s' "${arc_sha:-}" | tr 'A-Z' 'a-z' | tr -cd '0-9a-f')
    if [[ ${#want} -ne 64 ]]; then
      echo "$STOP --published-sha256 is not a 64-character SHA-256 value."
      echo "  Got ${#want} hex characters. Nothing was compared."
      BLOCKER=1
    elif [[ "$want" == "$got" ]]; then
      echo "$OK  published digest  : MATCHES"
      echo "$INFO A match proves the download was not altered in transit. It does"
      echo "  not prove the release itself is honest — the same page usually"
      echo "  serves both the file and the digest."
    else
      echo "$STOP published digest  : MISMATCH"
      echo "      published: $want"
      echo "      computed : $got"
      echo "  This is not the file the maintainer released. Stop here."
      BLOCKER=1
    fi
  else
    echo "$WARN No --published-sha256 given, so integrity was NOT verified."
    echo "  An unchecked hash is not a passed check. If the project publishes"
    echo "  digests, fetch one and re-run; if it publishes none, record that"
    echo "  absence as a finding."
  fi
else
  echo "$WARN No --archive given, so integrity was NOT verified and the"
  echo "  quarantine tag was not read. A bundle on disk cannot be compared"
  echo "  against a published digest — expanding changes the bytes."
fi

qtag=""
for target in "$ARCHIVE" "$BUNDLE"; do
  [[ -n "$target" ]] || continue
  qtag=$(xattr -p com.apple.quarantine "$target" 2>/dev/null)
  if [[ -n "$qtag" ]]; then
    echo "$INFO quarantine tag on $(basename "$target"): set by \
$(printf '%s' "$qtag" | cut -d';' -f3)"
    break
  fi
done
if [[ -z "$qtag" ]]; then
  echo "$INFO No com.apple.quarantine tag found."
  echo "  Absent is NOT evidence of tampering — curl, git clone, USB and file"
  echo "  shares never set one. It does mean Gatekeeper will not evaluate this"
  echo "  on first open, so you know which case you are in."
fi

# --- 4.4  Nested signable components --------------------------------------
# Checking only the top-level .app missed an unsandboxed .xpc in a real audit,
# so nested components are enumerated explicitly rather than assumed absent.
echo
echo "--- Nested signable components --------------------------------------"
find "$BUNDLE" \( -name '*.app' -o -name '*.appex' -o -name '*.xpc' \
     -o -name '*.framework' -o -name '*.systemextension' -o -name '*.bundle' \
     -o -name '*.plugin' -o -name '*.qlgenerator' -o -name '*.pkg' \
     -o -name '*.mpkg' -o -name '*.dmg' \) 2>/dev/null \
  | grep -v "^$BUNDLE\$" | sort > "$WORK/nested.txt"
nested_n=$(grep -c . "$WORK/nested.txt" | tr -d ' ')
mach_n=$(grep -c '^component' "$FACTS" | tr -d ' ')
echo "  nested bundles    : $nested_n"
echo "  Mach-O components : $mach_n   (every one is signed and read below)"
if [[ "$nested_n" -gt 0 ]]; then
  sed "s|^$BUNDLE/|      |" "$WORK/nested.txt"
else
  echo "$INFO None. Normal for a single-binary app — and confirmed against"
  echo "  $mach_n Mach-O components, so the enumeration did read the bundle."
fi
if grep -qE '\.(pkg|mpkg|dmg)$' "$WORK/nested.txt"; then
  echo
  echo "$STOP This bundle carries an installer payload. Installer scripts run as"
  echo "  admin and are a favoured malware vector. Expand and read it yourself,"
  echo "  without running it:"
  echo "      pkgutil --check-signature <pkg>"
  echo "      pkgutil --expand <pkg> <outdir>   # then read preinstall/postinstall"
fi

# --- 4.4  Signature integrity ---------------------------------------------
echo
echo "--- Signature integrity ---------------------------------------------"
# codesign reports on stderr; discarding it has already made a real result look
# like a tool failure in this project's history.
cs_out=$(codesign --verify --deep --strict --verbose=2 "$BUNDLE" 2>&1)
cs_rc=$?
if [[ $cs_rc -eq 0 ]]; then
  echo "$OK  codesign --verify --deep --strict: valid, not modified"
else
  echo "$STOP codesign --verify --deep --strict: FAILED (exit $cs_rc)"
  printf '%s\n' "$cs_out" | sed 's/^/      /'
  echo "  A broken signature on an artifact you have not run yet usually means"
  echo "  the bytes changed after signing — including by expanding with unzip"
  echo "  instead of ditto -x -k. Rule that out before treating it as tampering."
  BLOCKER=1
fi

# --- 4.4 / 4.5  Identity, notarization, Gatekeeper -------------------------
echo
echo "--- Identity, notarization, Gatekeeper ------------------------------"
echo "  bundle identifier : $(fact bundle-identifier | head -1)"
echo "  notarization      : $(fact notarization)"
echo "  Gatekeeper        : $(fact gatekeeper)"
fact_values teamid    | sort -u | sed 's/^/  Team ID           : /'
fact_values authority | sort -u | sed 's/^/  authority         : /'
if [[ $(fact_values teamid | sort -u | grep -c .) -gt 1 ]]; then
  echo "$WARN More than one Team ID signs this bundle. That can be legitimate"
  echo "  (a vendored framework), but each one is a separate party you are"
  echo "  trusting, and Phase 1 vetted only the maintainer."
fi
unhardened=$(fact cdflags | while IFS='|' read -r rel flags; do
               [[ -n "$flags" ]] || continue
               (( (flags & 0x10000) == 0 )) && echo "$rel"
             done)
if [[ -n "$unhardened" ]]; then
  echo "$WARN Components WITHOUT the hardened runtime (flag 0x10000):"
  printf '%s\n' "$unhardened" | sed 's/^/      /'
else
  echo "$OK  hardened runtime  : set on all $(grep -c '^cdflags' "$FACTS" | tr -d ' ') signed components"
fi
echo "$INFO A valid signature and notarization answer \"is this the file the"
echo "  maintainer released?\" — not \"is it safe?\". Apple's scan is automated."

# --- 4.6  Entitlements ----------------------------------------------------
echo
echo "--- Entitlements (what powers it asks for) --------------------------"
ent_n=$(grep -c '^entitlement' "$FACTS" | tr -d ' ')
echo "  entitlement records: $ent_n"
if [[ "$ent_n" -eq 0 ]]; then
  echo "$WARN Not one component declares an entitlement."
  echo "  On this macOS version codesign -d --entitlements output shape varies,"
  echo "  and an empty read looks exactly like a genuinely empty dict. Confirm"
  echo "  by hand on one component before believing this:"
  echo "      codesign -d --entitlements - --xml \"$BUNDLE\" | plutil -p -"
else
  fact entitlement | cut -d'|' -f1 | sort -u | while IFS= read -r rel; do
    echo "      $rel"
    awk -F'\t' -v r="$rel" '$1=="entitlement" && index($2, r "|")==1 {
      sub(/^[^|]*\|/, "", $2); print "          " $2 }' "$FACTS"
  done
fi

# A component with no entitlements at all is unsandboxed. That is a fact, and
# in a real audit it was also the fact that corrected an earlier over-reading.
noent=$(fact component | while IFS= read -r rel; do
          grep -q "^entitlement	$(printf '%s' "$rel" | sed 's/[[\.*^$/]/\\&/g')|" "$FACTS" \
            || echo "$rel"
        done)
if [[ -n "$noent" ]]; then
  echo
  echo "$INFO Components declaring NO entitlements — that means no App Sandbox:"
  printf '%s\n' "$noent" | sed 's/^/      /'
  echo "  Unsandboxed is not automatically a finding. Read Info.plist first:"
  echo "  an XPC service with ServiceType = Application runs inside its host's"
  echo "  sandbox, and calling it unsandboxed overstates the exposure."
fi

relax=$(fact_values entitlement | grep -E \
  'get-task-allow|cs\.allow-jit|cs\.disable-library-validation|cs\.allow-dyld-environment-variables|cs\.allow-unsigned-executable-memory|cs\.debugger' \
  | sort -u)
if [[ -n "$relax" ]]; then
  echo
  echo "$WARN Hardened-runtime relaxations requested:"
  printf '%s\n' "$relax" | sed 's/^/      /'
  echo "  These widen what the process may do to its own memory and libraries."
  echo "  get-task-allow in a shipping build is the sharpest of them. Weigh"
  echo "  each against what the software claims to do; none is pass/fail."
fi

# --- 4.6  Entitlements vs the reviewed source -----------------------------
echo
echo "--- Entitlements vs reviewed source ---------------------------------"
if [[ -z "$SRCDIR" ]]; then
  echo "$INFO Not run — no --source given. This is the highest-value check in"
  echo "  the phase: it asks whether the shipped binary requests privileges the"
  echo "  source you reviewed never declared. Re-run with --source <dir>."
else
  find "$SRCDIR" -type f -iname '*.entitlements' 2>/dev/null | sort > "$WORK/entfiles.txt"
  entfile_n=$(grep -c . "$WORK/entfiles.txt" | tr -d ' ')
  echo "  .entitlements files in source: $entfile_n"
  if [[ "$entfile_n" -eq 0 ]]; then
    echo "$STOP The diff did NOT run. A source tree with no .entitlements files"
    echo "  produces \"no differences\" — identical to a clean comparison, and"
    echo "  meaningless. Check you pointed --source at the right tree, and that"
    echo "  the project declares entitlements in files rather than in build"
    echo "  settings. Do not record this as a clean result."
  else
    sed 's|^|      |' "$WORK/entfiles.txt"
    # Both sides go through the SAME normalizer the baseline uses, so the
    # comparison is like-for-like. Entries are key AND value, so a widened
    # value (read-only becoming read-write) shows up as well as a new key.
    : > "$WORK/src-ents.txt"
    while IFS= read -r ef; do
      plutil -p "$ef" 2>/dev/null | normalize_entitlements >> "$WORK/src-ents.txt"
    done < "$WORK/entfiles.txt"
    sort -u -o "$WORK/src-ents.txt" "$WORK/src-ents.txt"
    fact_values entitlement | sort -u > "$WORK/art-ents.txt"

    src_n=$(grep -c . "$WORK/src-ents.txt" | tr -d ' ')
    art_n=$(grep -c . "$WORK/art-ents.txt" | tr -d ' ')
    echo "  normalized entries: source $src_n   artifact $art_n"
    if [[ "$src_n" -eq 0 ]]; then
      echo "$STOP The diff did NOT run: $entfile_n .entitlements file(s) were"
      echo "  found but none parsed into a single entry. Treat this as a tool"
      echo "  failure, not a clean result."
    else
      extra=$(comm -13 "$WORK/src-ents.txt" "$WORK/art-ents.txt")
      missing=$(comm -23 "$WORK/src-ents.txt" "$WORK/art-ents.txt")
      if [[ -n "$extra" ]]; then
        echo "$STOP In the ARTIFACT but not in the reviewed source:"
        printf '%s\n' "$extra" | sed 's/^/      /'
        echo "  The binary asks for privilege the code you read does not explain."
      else
        echo "$OK  No entitlement entry in the artifact is absent from the source."
      fi
      if [[ -n "$missing" ]]; then
        echo "$INFO In the source but not in the artifact (usually a build variant"
        echo "  or a debug-only file — check which file declared it):"
        printf '%s\n' "$missing" | sed 's/^/      /'
      fi
    fi
  fi
fi

# --- 4.7  Linkage ---------------------------------------------------------
echo
echo "--- Non-Apple linked libraries --------------------------------------"
lib_n=$(grep -c '^nonapple-lib' "$FACTS" | tr -d ' ')
if [[ "$lib_n" -eq 0 ]]; then
  echo "$INFO None: every component links only /System/Library and /usr/lib."
  echo "  Common and usually unremarkable — but a zero here cannot tell you"
  echo "  the detector works. It has to be proven against an app that DOES"
  echo "  link non-Apple libraries before a zero means anything."
else
  echo "  linked non-Apple library records: $lib_n"
  fact_values nonapple-lib | sort | uniq -c | sort -rn | sed 's/^/      /'
fi

# --- Bundle completeness --------------------------------------------------
# A one-line version of this produced a real finding: the artifact did not
# contain all the code it runs, because the renderer fetched JS from a CDN.
echo
echo "--- Does the bundle contain the code it runs? -----------------------"
find "$BUNDLE" -type f \( -iname '*.js' -o -iname '*.mjs' -o -iname '*.cjs' \
     -o -iname '*.py' -o -iname '*.rb' -o -iname '*.pl' -o -iname '*.sh' \
     -o -iname '*.php' -o -iname '*.lua' -o -iname '*.wasm' -o -iname '*.jar' \) \
     2>/dev/null | sort > "$WORK/interp.txt"
interp_n=$(grep -c . "$WORK/interp.txt" | tr -d ' ')
echo "  interpreted / bytecode assets shipped: $interp_n"
if [[ "$interp_n" -gt 0 ]]; then
  sed 's/.*\.//' "$WORK/interp.txt" | tr 'A-Z' 'a-z' | sort | uniq -c \
    | sort -rn | sed 's/^/      /'
fi

find "$BUNDLE" -type f \( -iname '*.html' -o -iname '*.htm' -o -iname '*.js' \
     -o -iname '*.css' \) 2>/dev/null > "$WORK/webassets.txt"
web_n=$(grep -c . "$WORK/webassets.txt" | tr -d ' ')
if [[ "$web_n" -gt 0 ]]; then
  # A homepage link in an about-box is not remote code. Only references that
  # actually LOAD something — script/stylesheet sources, CSS or module imports
  # — carry the "code I did not audit" meaning.
  LOADER_RE='(<script[^>]*src[^>]*|<link[^>]*href[^>]*|@import[^;]*|importScripts\([^)]*|import[[:space:]]*[("'\''][^;]*)'
  ORIGIN_RE='https?://[A-Za-z0-9._~-]+'
  # Prove the detector can see a known positive before believing a zero. An
  # earlier version of this pattern exceeded BSD grep's 255-repetition limit
  # and failed silently, reporting "no remote loaders" for a bundle that had one.
  selftest=$(printf '%s\n' '<script src="https://known.positive/x.js"></script>' \
               | grep -ohiE "$LOADER_RE" | grep -ohE "$ORIGIN_RE")
  if [[ "$selftest" != "https://known.positive" ]]; then
    echo "$STOP The remote-loader detector FAILED its self-test — it did not"
    echo "  match a known-positive script tag. Any result below is meaningless."
    echo "  Do not record this section. (grep returned: '${selftest:-<nothing>}')"
  fi
  : > "$WORK/all-origins.txt"; : > "$WORK/load-origins.txt"
  while IFS= read -r wa; do
    grep -ohE "$ORIGIN_RE" "$wa" 2>/dev/null >> "$WORK/all-origins.txt"
    grep -ohiE "$LOADER_RE" "$wa" 2>/dev/null \
      | grep -ohE "$ORIGIN_RE" >> "$WORK/load-origins.txt"
  done < "$WORK/webassets.txt"
  sort -u -o "$WORK/all-origins.txt" "$WORK/all-origins.txt"
  sort -u -o "$WORK/load-origins.txt" "$WORK/load-origins.txt"
  load_n=$(grep -c . "$WORK/load-origins.txt" | tr -d ' ')
  other_n=$(comm -23 "$WORK/all-origins.txt" "$WORK/load-origins.txt" | grep -c . | tr -d ' ')
  echo "  shipped web assets: $web_n"
  if [[ "$load_n" -gt 0 ]]; then
    echo "$WARN Remote origins referenced by a LOADER (script src, stylesheet"
    echo "  href, @import, module import) — code or style this bundle does not"
    echo "  contain and your source review did not cover:"
    sed 's/^/      /' "$WORK/load-origins.txt"
  else
    echo "$INFO No loader in the shipped web assets points at a remote origin."
  fi
  if [[ "$other_n" -gt 0 ]]; then
    echo "$INFO $other_n further origin(s) appear as plain text — typically"
    echo "  homepage, support or documentation links. Listed as context, NOT"
    echo "  as a finding:"
    comm -23 "$WORK/all-origins.txt" "$WORK/load-origins.txt" | sed 's/^/      /'
  fi
fi
echo "$INFO Read this as a completeness question, not a count. If the software
  renders with a library that does not appear above, it is loading that
  library from somewhere else — and you have audited only part of it."
echo "  A zero above is NOT proof of no remote loading: a URL assembled at
  runtime, or a fetch from compiled code, is invisible to a text search."

# --- Baseline -------------------------------------------------------------
echo
echo "--- Baseline --------------------------------------------------------"
if [[ -n "$BASELINE_OUT" ]]; then
  if emit_baseline "$BUNDLE" "$FACTS" > "$BASELINE_OUT"; then
    echo "$OK  Wrote schema-$ARTIFACT_FACTS_SCHEMA baseline: $BASELINE_OUT"
    echo "$INFO From the same collection as the evidence above, so the report and"
    echo "  the baseline cannot disagree. Keep it beside the decision record;"
    echo "  verify-known-artifact.sh --baseline uses it to check the next version"
    echo "  in seconds instead of hours."
  else
    echo "$STOP Could not write baseline: $BASELINE_OUT"
  fi
else
  echo "$INFO No baseline written. If this artifact is accepted, record one now —"
  echo "  it is what makes the next update a ~10-minute check:"
  echo "      scripts/verify-known-artifact.sh --record \"$BUNDLE\" > <name>.baseline.txt"
fi

echo
echo "=================================================================="
echo " These are facts, not a verdict. Phase 4 cannot tell you the"
echo " software is safe — only whether it is the file the maintainer"
echo " released and what privileges it asks for."
echo
echo " Not covered here, and still yours to do:"
echo "   - reading any installer script before it runs (4.8)"
echo "   - the source review this diff is measured against (Phase 3)"
echo "   - what it does when it runs (Phase 5)"
echo "   - ownership and installed launchd jobs, AFTER installing"
echo "     (verify-known-artifact.sh --system-ownership / --system-persistence)"
echo "=================================================================="

exit "$BLOCKER"
