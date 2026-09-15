# scripts/ — small, read-only helpers

Helper scripts for the intake framework. Everything here is **read-only by
design**: these tools *gather evidence and answer a question* — they never
install, build, or run the external code you're reviewing. The intake gate stays
on **execution**, and a **human still owns every decision** (see
[`../docs/00-scope-and-boundaries.md`](../docs/00-scope-and-boundaries.md)).

> **The rule every script here obeys:** automation may produce **facts** and
> **cost forecasts**. It may never produce **verdicts**, risk scores, or summary
> judgements — including the phrase "looks clean."
>
> **The tripwire test, before automating any check:** *if this check were broken,
> what would its output look like?* If "broken" is indistinguishable from
> "clean," the check must either carry a calibration step that proves it can see
> a known positive, or not be automated at all.

---

## `intake-triage.sh` — do I even need this, and what will it cost?

**The problem it solves.** The most expensive audit in this repo's history took
**4h09m** and ended in **Reject** — for a tool whose job was already done by
software that was already installed. That answer was available in 30 seconds.
The framework was right about the artifact and had nothing to say about the
*task*. This script asks the task question first.

It implements gates G0–G2 from
[`../docs/02-artifact-triage.md`](../docs/02-artifact-triage.md):

- **G0** — searches your [capability register](../reports/capability-register.md)
  for a tool you already trust that does the job.
- **G1** — guesses the artifact type, flags how it gains privilege, checks
  whether a `*.baseline.txt` already exists (which makes it a cheap **update**,
  not a first intake), and emits a **cost band**.
- **G2** — lays out the three dispositions and prints paste-ready log lines,
  including the `Accepted WITHOUT review` register entry.

### Usage

```bash
scripts/intake-triage.sh <url-or-path> --job "what I need it to do"
```

The `--job` argument is the whole point — without it, G0 cannot be checked and
the script says so rather than quietly skipping it.

### What it tells you

| Band | Meaning | Fits a 15-minute interruption? |
|:----:|---------|:--:|
| **A** | A new version of something already accepted, with a stored baseline | ✅ Yes — go to [`../docs/05-update-audit.md`](../docs/05-update-audit.md) |
| **B** | Fast lane — low privilege, readable, no install scripts | ✅ Yes |
| **C** | Scheduled audit, 1–2 hours | ❌ Schedule it |
| **D** | Expensive, 4+ hours | ❌ Schedule it — and prefer a substitute |

### What it deliberately does **not** do

It never downloads, opens, executes or inspects the artifact. It reasons only
about the name you give it and this repo's own records. The type guess comes
from URL text alone and **can be wrong** — a repository URL says nothing about
what the project actually ships — so the script states that every time. A cost
band is a forecast, not a safety judgement.

Exit code is always `0` on success; it carries no verdict meaning.

---

## `check-build-feasibility.sh` — declared compatibility preflight

**The problem it solves.** Building from source only helps if your toolchain can
compile the version you're reviewing. Your installed **Xcode** sets a ceiling on
the **Swift version** and **SDK** you can build against, and a project's newest
release may require a newer one. Without checking first, you can spend real time
on a build that was never going to succeed — or be tempted into risky
workarounds. This script looks for **declared blockers** in a few seconds,
*before* you commit to the build-from-source path. It cannot prove a build will
succeed: source may use newer Swift features or SDK APIs that static metadata
does not declare.

### Usage

```bash
# default: checks the quarantine/ folder
scripts/check-build-feasibility.sh

# or point it at a specific downloaded project
scripts/check-build-feasibility.sh quarantine/some-project

# if several build files are reported, select the one you intend to use
scripts/check-build-feasibility.sh quarantine/some-project \
  --build-file path/to/Package.swift
```

### What it reads

- **Your selected toolchain** (asks your own tools): developer directory, Xcode
  version, Xcode-selected Swift version, and installed macOS SDK. It warns if a
  different Swift on `PATH` could make results misleading.
- **What the project requires** (plain-text reads only): the
  `swift-tools-version` from the top of `Package.swift`, any `.swift-version` /
  `.xcode-version` pin, Xcode project files, workspaces, `.xcconfig` files, and
  the macOS **deployment target**. The deployment target is reported only as
  the minimum runtime OS; it is not treated as a required SDK version.

### What it tells you

| Exit | Meaning | Next step |
|:----:|---------|-----------|
| `0` | **No declared blocker found** | Continue Phase 2 + Phase 3 review. This is neither proof of build success nor permission to build; wait for the recorded human decision. |
| `1` | **Declared blocker found** | Do not force the build. Keep reviewing readable source. A pre-built artifact needs Phase 4 and risk-appropriate Phase 5, and may still end in Hold or Reject. |
| `2` | **Inconclusive** | Resolve the warnings before choosing a build path. Do not build or run anything. |

If you consider an **older release**, pin and review that exact version. Check
advisories and the changelog for security fixes made after it. Reviewing older
source does not establish that a newer pre-built binary matches that source.

### Why it's safe to run on quarantined code

A SwiftPM `Package.swift` is itself Swift code. Asking SwiftPM to parse it
(`swift package …`) would **execute** it — exactly what the framework tells you
not to do before a decision. This script **never** does that: it reads the
required version from the file's header comment as plain text. It runs no part of
the target project, so it's safe to use on code sitting in
[`../quarantine/`](../quarantine/) during Phase 1–3 review.

> **Your selected Xcode sets the ceiling.** The script detects the currently
> selected versions instead of relying on a hardcoded machine configuration.
> A dated record of the environment that prompted this helper lives in the
> [Xcode design record](../docs/design-decisions-Xcode.md).

### Test the helper

```bash
scripts/tests/check-build-feasibility-tests.sh
```

The test suite uses temporary fixtures and mocked tool-version output. It does
not build or execute external code.

---

## `verify-known-artifact.sh` — has an approved artifact drifted?

**The problem it solves.** Approval applies to the **exact version you reviewed**
— but most macOS apps update themselves, so the thing you audited can quietly
replace itself with something you never saw. Re-running a full audit on every
point release does not scale, and pretending otherwise is how a framework turns
into the reason work stalls. The expensive part of an audit is *establishing what
normal looks like*; once that is recorded, checking a new version against it
takes seconds. This script does that check.

It compares the invariants that actually matter for trust: **Team ID**, **signing
authority**, **notarization**, **Gatekeeper verdict**, **code-directory flags**,
**entitlements**, **bundle-declared persistence**, **privileged helpers**, the
**component list**, and any **non-Apple linked libraries**.

> 🔑 **Known schema gap — ownership and permissions are NOT recorded.** A bundle whose
> owner changes from `root` to a local user account produces a clean **"no drift"**
> result, because POSIX ownership is not part of a code signature and is not in the
> baseline. This is not hypothetical: a real install silently transferred a security
> tool's bundle to an unrelated local account while signature, notarization, Gatekeeper,
> drift and byte-for-byte hashes all passed. **Check ownership by hand after any
> install** until the schema is extended:
>
> ```bash
> find "/Applications/<App>.app" ! -user root | wc -l   # expect 0
> ```
>
> The lesson generalises beyond this script: a check can be perfectly correct and still
> be mistaken for a complete one.

### Usage

```bash
# 1. At audit time, record a baseline and keep it with the report
scripts/verify-known-artifact.sh --record "/Volumes/SomeApp/Some.app" > baseline.txt

# 2. When a new version appears, mount it read-only YOURSELF, then compare
hdiutil attach -readonly -nobrowse -noautoopen NewVersion.dmg
scripts/verify-known-artifact.sh --baseline baseline.txt "/Volumes/SomeApp/Some.app"
hdiutil detach /Volumes/SomeApp

# 3. AFTER installing, list what the app actually registered on the system
scripts/verify-known-artifact.sh --system-persistence "/Applications/Some.app"
```

### Persistence records (schema 2)

Persistence **is** privilege: a new `LaunchDaemon` is a root-at-boot foothold. Two
different questions are involved, and the script keeps them apart on purpose.

| | What it captures | Scope |
|---|---|---|
| **Baseline** — `persistence`, `privileged-helper` | What the bundle **declares** about itself: `SMAppService` plists and login-item `.app`s under `Contents/Library/Launch{Agents,Daemons}`, plus `SMPrivilegedExecutables` | **Bundle-intrinsic**, so a baseline taken from a mounted image equals one taken from `/Applications` |
| **`--system-persistence`** | What is actually **installed** in `/Library/Launch{Agents,Daemons}` and `~/Library/LaunchAgents` | System state — only meaningful *after* an install |

Mixing the two would break baselines outright: a disk image has no `/Library` jobs,
so a DMG-recorded baseline could never match an installed app.

> ⚠️ **`--system-persistence` output describes your machine, not the artifact.** It
> reports what is installed on *this* system, so it can carry local paths and job
> labels. **Summarise it in a report rather than pasting it raw**, and apply the
> redaction convention in [`../reports/README.md`](../reports/README.md). Everything
> else this script emits is artifact-intrinsic and safe to publish.

`--system-persistence` flags any job whose program lives **outside** the audited
bundle. Little Snitch is the worked example — its root daemon runs from
`/Library/Application Support/…`, which the baseline does **not** cover, and which
is therefore a separate link in the *audited → installed → staged → running* chain.

> 🔑 **Why this exists.** The 6.4.1 intake report originally listed three launchd
> plists that **do not exist on the system** — 3.x/4.x-era names carried in from the
> vendor's CVE history rather than enumerated from the machine, and given a ✅. The
> rule it produced: **persistence paths are enumerated, never recalled.** See the
> correction note in
> [`../reports/little-snitch-v6.4.1-intake.md`](../reports/little-snitch-v6.4.1-intake.md).

**Schema compatibility.** A schema-1 baseline contains no persistence records, so the
script reads the version from the baseline header and skips the newer record types
rather than reporting them as drift. It says so when it does. Re-record the baseline
to gain persistence coverage.

**Calibrating this check.** Little Snitch declares **zero** bundled launchd plists, so
its baseline cannot exercise the collector at all — the same silent-failure shape as
the non-Apple-library detector. Validate against apps that *do* declare persistence
(on a typical Mac, Microsoft Teams ships two `SMAppService` agents and Zoom ships a
login-item app plus two `SMPrivilegedExecutables`) before believing a zero.

### What it tells you

| Exit | Meaning | Next step |
|:----:|---------|-----------|
| `0` | **No drift** — every recorded invariant still holds | Read the release notes and record a human decision. A clean result is *not* proof the update is safe and *not* permission to install. |
| `1` | **Drift found** | If the **trust anchor or privilege** changed (Team ID, authority, notarization, a new entitlement, a new non-Apple library), do not install — run a full re-audit. If only **composition** changed (components added/removed), confirm the release notes explain it. |
| `2` | **Inconclusive** — bad arguments, missing baseline, or no signed Mach-O components found | Fix the input. Point it at an `.app`, not a disk image or archive. |

### ⚠️ Calibrate it before you trust a clean result

**A drift checker that read nothing prints "No drift" — exactly what a genuinely
clean update prints.** The two are indistinguishable unless you prove the
instrument can see a change. Calibrate **once per script version**:

| Test | How | Must produce |
|---|---|---|
| Known-negative | Compare the *old* version against its own baseline | "No drift" |
| Known-positive (gross) | Compare a completely different app | Loud, obvious drift |
| Known-positive (targeted) | Copy the baseline, delete one entitlement line | **"NEW PRIVILEGE"**, naming that entitlement |
| Known-positive (identity) | Copy the baseline, alter the Team ID | Team-ID / authority drift |

Perturbing **copies of the baseline** tests exactly the detections your
escalation triggers depend on, costs seconds, and touches no binaries.

**Watch for checks the artifact cannot exercise.** Little Snitch links *zero*
non-Apple libraries, so its baseline could not test the "new library" detector
at all — a broken parser and a genuinely clean app produce identical output.
That path had to be validated against other apps that *do* link such libraries
before the zero could be believed. See the calibration record in
[`../reports/little-snitch-v6.5-update-audit.md`](../reports/little-snitch-v6.5-update-audit.md).

**Also prove it read the new bytes.** Compare a few `CDHash` values between old
and new: every binary changing while no invariant changes is the ideal shape for
a point release. Identical hashes mean you compared something to itself.

### Why it's safe to run

It only ever *reads*: `codesign`, `spctl`, `stapler`, `otool` and `file` are
inspection tools. The script **does not mount disk images, install, launch or
execute anything** — you mount read-only yourself, so the one action with any
attack surface stays an explicit human step. It writes nothing except the
baseline you redirect to a file.

> **This is a Tier 1 check, not an audit.** It answers *"did the trust anchor or
> the privilege change?"* — not *"is this version safe?"* Nothing here replaces
> reading the release notes, and a **human still records every decision.**
> Full workflow: [`../docs/05-update-audit.md`](../docs/05-update-audit.md).
> Worked examples: [`../reports/little-snitch-v6.4.1-intake.md`](../reports/little-snitch-v6.4.1-intake.md)
> (baseline recorded) and [`../reports/little-snitch-v6.5-update-audit.md`](../reports/little-snitch-v6.5-update-audit.md)
> (baseline used).
