#!/bin/bash
# Shared configuration for the Phase 5 kit.
#
# This file is SOURCED, never executed. It exists for two reasons.
#
# 1. Portability. Every script here used to hardcode /Users/Shared/phase5-kit,
#    which blocks running the kit anywhere else.
#
# 2. Correctness, and this is the important one. The canary strings below were
#    previously written out by 01-setup.sh and searched for again, separately,
#    by 03-check-canary.sh. If those two copies ever drifted, the check would
#    hunt for a string that had never been planted and report "canary NOT
#    found" — a false clean, in the single check the Phase 5 finding in this
#    framework's worked example actually turned on. One definition removes the
#    possibility.
#
# Nothing here installs, builds, runs or fetches anything.

# Defaults, each overridable by environment or by a flag.
KIT_ROOT="${ECISF_KIT_ROOT:-$HOME/ecisf-phase5}"
KIT_PORT="${ECISF_LISTENER_PORT:-8000}"
KIT_SUBJECT="${ECISF_SUBJECT:-the artifact under test}"
# Substring used to find the artifact in extension listings, e.g. "qlmarkdown".
KIT_MATCH="${ECISF_MATCH:-}"
# Application group container id, e.g. "group.org.example.app".
KIT_GROUP="${ECISF_GROUP_CONTAINER:-}"
# Extension the probe files are given, so the OS routes them to the previewer
# or parser under test.
KIT_EXT="${ECISF_PROBE_EXT:-md}"
KIT_POSITIONAL=""
KIT_HELP=0

# The canary strings. FAKE by construction — they exist to be searched for, and
# no real secret is ever used. Defined once; see the header for why.
KIT_CANARY_SSH='CANARY-AUDIT-7F3A-NOT-A-REAL-KEY'
KIT_CANARY_AWS='CANARY-AUDIT-9B2C-NOT-REAL-CREDS'
# Used only by 00-calibrate.sh, and deliberately a DIFFERENT string: calibration
# must not depend on 01-setup.sh having run, and a calibration artefact must
# never be mistakable for real evidence from the run itself.
KIT_CANARY_CAL='CANARY-CAL-4D7E-NOT-A-REAL-SECRET'

kit_common_options() {
    cat <<'EOF'
Shared options (all scripts in this kit accept these):
  --kit-root <dir>       Where the kit reads and writes. Default
                         $HOME/ecisf-phase5. For CROSS-ACCOUNT evidence pass a
                         shared path explicitly, e.g. /Users/Shared/ecisf-phase5
                         — writing outside your own home should be a decision,
                         not an accident.
  --listener-port <n>    Local evidence listener port. Default 8000.
  --subject <name>       What is under test, used in headings and logs.
  --match <substring>    How to find the artifact in extension listings.
  --group-container <id> Application group container to inspect, if any.
  --probe-ext <ext>      Extension given to probe files. Default md.
  -h, --help             Show usage.
EOF
}

# Sets the KIT_* globals. The first non-flag argument is left in
# KIT_POSITIONAL. Deliberately a scalar rather than an array: under `set -u`,
# bash 3.2 treats "${arr[@]}" on an EMPTY array as an unbound variable, so an
# array here would fail on every script that takes no positional argument.
kit_parse_common() {
    KIT_POSITIONAL=""
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help) KIT_HELP=1 ;;
            --kit-root)        shift; KIT_ROOT="${1:-}" ;;
            --listener-port)   shift; KIT_PORT="${1:-}" ;;
            --subject)         shift; KIT_SUBJECT="${1:-}" ;;
            --match)           shift; KIT_MATCH="${1:-}" ;;
            --group-container) shift; KIT_GROUP="${1:-}" ;;
            --probe-ext)       shift; KIT_EXT="${1:-}" ;;
            -*) echo "Unrecognised argument: $1" >&2; return 2 ;;
            *)  [ -z "$KIT_POSITIONAL" ] && KIT_POSITIONAL="$1" ;;
        esac
        shift || true
    done
    return 0
}

kit_validate_common() {
    case "$KIT_PORT" in
        ''|*[!0-9]*) echo "--listener-port must be a number, got: $KIT_PORT" >&2; return 2 ;;
    esac
    case "$KIT_EXT" in
        ''|*[!A-Za-z0-9]*) echo "--probe-ext must be alphanumeric, got: $KIT_EXT" >&2; return 2 ;;
    esac
    # Resolved before anything compares it against $HOME. A relative path never
    # matches "$HOME"/*, so without this a directory inside your own home gets
    # reported as readable from another account.
    case "$KIT_ROOT" in
        /*) ;;
        *) KIT_ROOT="$(pwd)/$KIT_ROOT" ;;
    esac
    return 0
}

kit_out() { printf '%s/out\n' "$KIT_ROOT"; }

kit_banner() { # title
    echo "=============================================================="
    echo " $1"
    echo " Subject : $KIT_SUBJECT"
    echo " Account : $(id -un)"
    echo " Kit root: $KIT_ROOT"
    echo " Date    : $(date '+%Y-%m-%d %H:%M:%S')"
    echo "=============================================================="
    echo
}
