# Design Decisions — Xcode Build Feasibility

> **What this file is.** A durable follow-on design record for the project. It
> documents the working sessions, reasoning, review, and resulting changes
> behind the build-feasibility helper.

| | |
|---|---|
| **Date** | 2026-08-03 |
| **Model** | Claude Opus 4.8 |
| **Topic** | How an older-than-latest Xcode limits building externally sourced code locally, and automating a pre-build feasibility check |
| **Environment** | macOS Sequoia 15.7.8 → max Xcode **26.3** (Swift **6.2.3**, macOS **26.2** SDK); latest public Xcode is 26.6 |
| **Outcome** | Added a read-only helper script + wired it into the methodology |

---

## Session 1 — Initial implementation (Opus 4.8)

This section records the first session as it occurred. Session 2 below reviews
and corrects places where its implementation or wording was too confident.

### 1. The question that started it

*The repo is maintained on a Mac capped at macOS Sequoia 15.x, so the highest
usable Xcode is 26.3. Given the framework's goal is to review the **latest
stable release** of external code, what limitations does an older Xcode impose,
and will there be cases where a local build is impossible — forcing a fall back
to testing a pre-built binary — even when Phase 1 points toward building from
source?*

### 2. Key technical findings

- **The real ceiling is your Xcode, not your macOS.** The SDK and Swift toolchain
  you can *compile against* are set by the installed Xcode. Xcode 26.3 bundles
  **Swift 6.2.3** and the **macOS 26.2 SDK** and runs on Sequoia 15.6+. So even
  on 15.7.8 you can build against the macOS 26.2 SDK — the cap is
  **Swift ≤ 6.2.3 / SDK ≤ macOS 26.2**.
- **Three things actually block a local build** when you're behind:
  1. **`swift-tools-version` too high** — a `Package.swift` requiring a newer
     tools-version is *refused outright* by SwiftPM (most common hard stop).
  2. **Newer Swift language/stdlib features** the toolchain doesn't have.
  3. **Newer SDK symbols** (APIs added after macOS 26.2) that won't link.
- **Yes, you will occasionally be forced to a pre-built artifact** — specifically
  for bleeding-edge projects targeting the newest OS, releases that bump
  `swift-tools-version` past yours, or apps only ever shipped as notarized
  binaries. This is the *exception*, not the rule; most current releases stay
  buildable on a toolchain a few versions back for months.
- **What you lose when forced to pre-built**, and how the framework absorbs it:
  - You lose **source↔binary correspondence** and **dynamic inspection of your
    own build**.
  - **Phase 3** (source review) still works fully — reading needs no toolchain.
  - Shift weight onto **Phase 4** (signature, notarization, entitlements, hash)
    and **Phase 5** (runtime isolation).
  - Treat *"can't build on my toolchain"* as a **triage branch, not a Hold** — a
    known, bounded environment limitation, not an unresolved risk in the code.

### 3. What was built this session

A small, **read-only** automation so a beginner never wastes time on an
impossible build (or reaches for risky workarounds):

**`scripts/check-build-feasibility.sh`** — compares your installed toolchain
(macOS, Xcode, Swift, highest SDK) against what a downloaded project requires
(`swift-tools-version`, `.swift-version`/`.xcode-version` pins, Xcode deployment
target) and prints a clear verdict:

| Exit | Verdict | Next step |
|:---:|---|---|
| `0` | Build looks feasible | Proceed with Method 1 (Phase 2 + Phase 3) |
| `1` | Build **not possible** | Fall back to pre-built (Phase 4) or an older buildable release |
| `2` | Inconclusive / not a Swift-Xcode tree | Resolve by hand |

**Safety property (framework-critical):** it **never executes the code under
review**. A `Package.swift` is itself Swift code, so it reads the required
version from the file's header comment as *plain text* rather than invoking
`swift package …` (which would run it). Safe to use on code in `quarantine/`.

Verified working on this machine: correctly **blocks** a fixture requiring
`swift-tools-version 6.9` (exit 1) and **passes** one requiring 5.7 (exit 0).

### 4. Files changed

| File | Change |
|------|--------|
| `scripts/check-build-feasibility.sh` | **New.** Read-only build-feasibility checker |
| `scripts/README.md` | **New.** Usage, exit codes, and safety rationale |
| `docs/03-install-methods-explained.md` | Method 1 "reality check" callout; feasibility gate in the decision guide; QLMarkdown build note |
| `docs/checklists/full-audit.md` | Step 0 checkbox: confirm the toolchain can build the pinned version |
| `quarantine/README.md` | Clarified the read-only feasibility check is a safe exception to "never build/run" |
| `AGENTS.md` | Repo map now lists `scripts/`; noted read-only helpers exist; bumped *Last reviewed* |

### 5. Original usage guidance

1. During triage, when the artifact routes toward **build-from-source**, run:
   ```bash
   scripts/check-build-feasibility.sh quarantine/<project>
   ```
2. **Exit 1** → don't force it: take the pre-built path (Phase 4) or review an
   older release the toolchain can build, and record that the source↔binary link
   wasn't self-verified.
3. Keep this in mind whenever the Mac's Xcode falls further behind the latest —
   the set of "can't build locally" releases grows over time.

---

## Session 2 — Cross-model review and hardening (GPT-5.6 Sol)

### 1. Review process

The second session read the complete Opus 4.8 transcript, this summary, the
actual seven-file change set, and the surrounding scope, phase, checklist, and
report guidance. It evaluated whether the automation added friction, weakened
the execution gate, or could produce unreliable outcomes. The review then used
small fixtures and mocked Apple tool output to test each proposed correction.

### 2. Weaknesses found

- Exit `0` claimed a build looked feasible even though metadata cannot detect
  newer Swift language features or SDK API use.
- Swift from `PATH` could be combined with a different Xcode-selected
  toolchain, creating a misleading result.
- Missing Xcode or SDK details could still lead to a successful verdict.
- `MACOSX_DEPLOYMENT_TARGET` was incorrectly compared with the SDK even though
  it describes the minimum runtime OS, not the SDK APIs source code requires.
- Only one root package or first Xcode project was checked, so nested or
  multiple build files could be missed or silently ignored.
- Fallback wording could sound like approval to use a pre-built or older
  release, weaken the human execution gate, or omit continuing source review.
- Reusable docs hardcoded a time-sensitive machine/toolchain ceiling, and the
  script's executable state was not guaranteed in a fresh clone.

### 3. Resultant changes

- Renamed exit `0` to **No declared compatibility blocker found** and made it
  explicit that this is neither proof of success nor permission to build.
- Bound compatibility checks to Swift selected by `xcrun`; a differing Swift on
  `PATH` now makes the result inconclusive.
- Xcode projects now require detectable full-Xcode, developer-directory, and
  SDK evidence; incomplete evidence returns exit `2`.
- Deployment targets are informational only. The helper explicitly states that
  static metadata cannot detect all newer language or SDK usage.
- The helper finds nested packages/projects and workspaces. Multiple build files
  return exit `2` until one is selected with `--build-file`; `.xcconfig` files
  are flagged for manual review.
- Blocked builds retain Phase 3 source review. Exact pre-built artifacts require
  Phase 4 and risk-appropriate Phase 5, with Hold or Reject still available.
- Older releases require their own pinned review plus advisory/changelog checks;
  older source cannot establish correspondence for a newer binary.
- Removed machine-specific Xcode facts from reusable guidance and linked back
  to this dated environment record instead.
- Added build-preflight and source↔binary fields to the audit report template,
  committed executable modes, and added a focused test suite.

### 4. Validation

`scripts/tests/check-build-feasibility-tests.sh` covers newer and older tools
versions, numeric dotted-version ordering, missing Xcode/SDK, selected-vs-PATH
Swift mismatch, nested and multiple build files, explicit selection, malformed
manifest headers, version pins, quoted deployment settings, `.xcconfig`, and
paths containing spaces. All **15 tests passed** on 2026-08-03.

### 5. Final process rule

The helper is a conservative **preflight**, not a build oracle or intake
decision. It may identify a declared reason not to build; it can never authorize
execution or automatically approve a fallback artifact. The human-reviewed,
recorded decision remains the gate.
