#!/usr/bin/env bash
# ECISF shared artifact fact collector.
#
# This file is SOURCED, never executed. It is the single place where facts are
# read off a macOS bundle, so that the evidence presented during a Phase 4 audit
# and the baseline stored for later drift checks cannot describe the artifact
# differently. If the two ever disagree, one of them is wrong and you will not
# find out until the update that mattered.
#
# It only reads: codesign, spctl, stapler, otool, file, find, PlistBuddy.
# It does not mount, expand, install, launch or execute anything.
#
# Output format is one fact per line: <kind><TAB><value>, sorted.
# Per-component facts encode their subject as "<relative-path>|<value>".
#
#   bundle-identifier  <id>
#   notarization       stapled | absent
#   gatekeeper         accepted | rejected
#   persistence        <LaunchAgents|LaunchDaemons>|<relpath>|<label>
#   privileged-helper  <id>
#   component          <relpath>
#   teamid             <relpath>|<team>
#   authority          <relpath>|<authority>
#   cdflags            <relpath>|<0xNNNN>
#   entitlement        <relpath>|<key => value>
#   nonapple-lib       <relpath>|<install-name>
#
# Only facts that TRAVEL WITH THE FILE belong here. Ownership, installed
# launchd jobs and anything else assigned at install time are system state and
# are collected elsewhere — see verify-known-artifact.sh --system-*.

# Bumped when a new record KIND is added, so a comparator reading an older
# baseline can skip record types that baseline could never have contained.
ARTIFACT_FACTS_SCHEMA=2

# Every script that sources this file MUST export LC_ALL=C before comparing
# fact files. sort obeys locale collation; comm compares bytes. Under
# en_US.UTF-8 the two disagree on lines containing punctuation, comm's
# parallel walk desynchronises, and it reports the entire remainder of both
# files as drift. Measured: one removed entitlement produced 29 "NEW
# PRIVILEGE" lines instead of 1. Identical files still align, so the clean
# path looks fine — which is how it went unnoticed.
artifact_facts_require_collation() {
  [[ "${LC_ALL:-}" == "C" ]] && return 0
  echo "LC_ALL is '${LC_ALL:-unset}', not C: fact comparison would be unreliable." >&2
  return 1
}

artifact_facts_require_tools() {
  local t missing=0
  for t in codesign spctl otool file find plutil; do
    command -v "$t" >/dev/null 2>&1 || { echo "Required tool missing: $t" >&2; missing=1; }
  done
  [[ -x /usr/libexec/PlistBuddy ]] || { echo "Required tool missing: PlistBuddy" >&2; missing=1; }
  return "$missing"
}

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

  # Persistence the bundle DECLARES about itself. Deliberately bundle-intrinsic:
  # a baseline taken from a mounted image must equal one taken from /Applications,
  # so installed /Library jobs are reported by --system-persistence instead.
  # SMAppService accepts either a .plist (agent/daemon) or a .app (login item),
  # so both are recorded — and neither is descended into.
  local sub dir item label helper
  for sub in LaunchAgents LaunchDaemons; do
    dir="$bundle/Contents/Library/$sub"
    [[ -d "$dir" ]] || continue
    for item in "$dir"/*; do
      [[ -e "$item" ]] || continue
      case "$item" in
        *.plist)
          label=$(/usr/libexec/PlistBuddy -c 'Print :Label' "$item" 2>/dev/null) ;;
        *.app)
          label=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' \
                    "$item/Contents/Info.plist" 2>/dev/null) ;;
        *) continue ;;
      esac
      [[ -z "$label" ]] && label="(no-label)"
      printf 'persistence\t%s|%s|%s\n' "$sub" "${item#"$bundle"/}" "$label" >> "$out"
    done
  done

  while IFS= read -r helper; do
    [[ -n "$helper" ]] && printf 'privileged-helper\t%s\n' "$helper" >> "$out"
  done < <(/usr/libexec/PlistBuddy -c 'Print :SMPrivilegedExecutables' \
             "$bundle/Contents/Info.plist" 2>/dev/null \
             | sed -n 's/^ *\([A-Za-z0-9._][A-Za-z0-9._-]*\) = .*/\1/p' | sort -u)

  local f rel info team auth flags ent lib entxml
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

    # plutil reports a parse failure on STDOUT, so piping empty codesign output
    # straight into it records "<stdin>: Cannot parse a NULL or zero-length
    # data" AS AN ENTITLEMENT. That made a component with no entitlements
    # indistinguishable from one whose entitlements could not be read — five
    # such records reached a committed baseline. Ask codesign first, and only
    # parse when there is something to parse.
    entxml=$(codesign -d --entitlements - --xml "$f" 2>/dev/null)
    if [[ -n "$entxml" ]]; then
      while IFS= read -r ent; do
        [[ -n "$ent" ]] && printf 'entitlement\t%s|%s\n' "$rel" "$ent" >> "$out"
      done < <(printf '%s\n' "$entxml" | plutil -p - 2>/dev/null | normalize_entitlements)
    fi

    while IFS= read -r lib; do
      [[ -n "$lib" ]] && printf 'nonapple-lib\t%s|%s\n' "$rel" "$lib" >> "$out"
    done < <(otool -L "$f" 2>/dev/null | tail -n +2 | awk '{print $1}' \
               | grep -vE '^/System/Library/|^/usr/lib/')
  done < <(find "$bundle" -type f -perm -u+x 2>/dev/null | sort)

  sort -o "$out" "$out"
}

# Print a baseline file: the collected facts plus the header the comparator
# reads the schema version from. Kept here so --record and a Phase 4 run that
# also emits a baseline produce byte-identical files.
emit_baseline() {
  local bundle="$1" facts="$2"
  echo "# ECISF known-artifact baseline (schema $ARTIFACT_FACTS_SCHEMA)"
  echo "# artifact: $(basename "$bundle")"
  echo "# recorded: $(date '+%Y-%m-%d')"
  echo "# This records what was true at audit time. It is evidence, not permission."
  echo "# schema 2 adds: persistence (bundle-declared launchd jobs), privileged-helper."
  cat "$facts"
}
