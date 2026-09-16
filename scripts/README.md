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

### What "read-only" does not cover

Read-only here means these scripts **do not change your machine or the code
under review**, and **compose no network request of their own**. Every URL in
their output is printed for you to visit, never fetched.

It does **not** mean nothing reaches the network. **`spctl -a` does.** Measured
2026-09-16 on macOS 15.7.9 (24G830, x86_64), each command run in isolation:

| Command | Apple system app | Notarized Developer ID app |
|---|:--:|:--:|
| `codesign --verify --deep --strict` | 0 TLS | not tested |
| `xcrun stapler validate` | 0 TLS | not tested |
| **`spctl -a -vvv`** | **3 TLS** | **3 TLS, 3 OCSP** |

`spctl` does not evaluate trust itself — it hands off to `syspolicyd`, which
opened three TLS connections (`connect_time(55ms)`, `rtt(24ms)`, `alpn(h3)`). It
reproduced on a second run three minutes later, so this is not a one-off that
then caches.

The real-world subject cost **more**, not less. Against a notarized Developer ID
app, `trustd` produced **606** records versus **57** for the Apple system app,
added OCSP revocation lookups the Apple app never triggered, and took **3
seconds** rather than under one.

**Why this matters here:** `collect_facts()` calls `spctl -a` on every artifact,
so Phase 4 evidence collection, baseline recording, drift checks and the test
battery all reach the network. **Assessing a file in `quarantine/` can signal to
a third party that you hold it.** For most intake work that is irrelevant; if you
are reviewing something you would rather not announce, it is not.

**What the measurement does not establish.** The destination host was not
identified. `codesign` and `stapler` were tested only against the Apple system
app, so their zero is evidence about that subject on this machine, not proof
that they never connect.

<details>
<summary>Controls — including the one that failed silently</summary>

`syspolicyd` logged **0** records in two windows where nothing was run, so 350
records during `spctl` is signal rather than background. Log visibility was
proven independently: a known-good TLS connection produced 55 `trustd` records,
so a zero would have meant "no traffic," not "blind instrument."

One control was initially void **and looked clean**. `set -- $w` inside a `for`
loop does not word-split in zsh as it does in bash, so `log show` received a
malformed time range, exited **64**, and printed `0 records` — indistinguishable
from "no background traffic." It was caught only because the exit code was read
on the line immediately after the command. Every later query gates on `rc`
before reporting any count.
</details>

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

## `phase1-provenance.sh` — is this the real project, and is it alive?

**The problem it solves.** Phase 1 is the cheapest phase and it rejects most bad
downloads before any effort is spent. Done by hand it took **51 minutes**, of
which roughly **35** was mechanical lookup — counting releases, reading dates,
checking for a `SECURITY.md`, resolving a tag to a commit.

It implements the deterministic half of
[`../docs/phases/phase-1-provenance.md`](../docs/phases/phase-1-provenance.md).

### `--online` is required, not assumed

Unlike the other collectors this one has **no offline half at all** — every
question is remote. So rather than silently needing the network, running without
`--online` prints the exact requests it *would* make, contacts nothing, and exits
2. No evidence gathered is not a clean result.

```bash
scripts/phase1-provenance.sh sbarex/QLMarkdown --online --tag 1.5.0
```

`gh` is optional and is used **only to borrow a token**, never as a second way of
making the request. One request path cannot disagree with itself; two can.

### It refuses to invent findings when it cannot see

A broken or rate-limited API makes every project look like it has no releases, no
contributors and no advisories. Two controls run before anything is reported:

| Control | Proves |
|---|---|
| A known repository reads back correctly | the path works and responses parse |
| A repository that cannot exist returns **404** | *absent* is distinguishable from *broken* |

The negative control is the sharper one. An endpoint that answers `200` to
everything would make "not found" meaningless — and that case is covered by a
test, not just hoped for. If either control fails the script stops rather than
printing findings that cannot be told apart from a bad connection.

### Two places a naive script is confidently wrong

- **An annotated tag does not point at a commit.** It points at a *tag object*.
  Reporting that SHA as "the commit" gives the reviewer the wrong value to paste
  into a clone command. This dereferences it and shows both. Verified against an
  independent `git ls-remote 'refs/tags/X^{}'` oracle: for `git/git v2.39.5` the
  tag object is `a622a3b3…` and the commit is `cc7d11c1…`.
- **A missing `fork` field must not read as "not a fork."** The script requires
  the field to be *present*, not merely falsy, so an API change or a bad parse
  reports *undetermined* instead of quietly blessing every fork as an original.

### What it will not do

The judgements Phase 1 actually turns on are printed as open questions, not
answered:

> how you arrived here, and whether that path was trustworthy · whether this
> maintainer reads as a careful engineer · whether a missing `SECURITY.md` is
> acceptable for **this** project · whether to pin the newest release or a
> longer-exposed older one

That last one matters: **a script would answer "newest" and be wrong** for the
reasons this framework exists.

### What it tells you

| Exit | Meaning |
|:----:|---------|
| `0` | Evidence collected |
| `1` | The repository does not exist at that `owner/repo` — you cannot audit what is not there, and a near-miss name is what a typosquat relies on |
| `2` | Inconclusive: no `--online`, bad arguments, rate limiting, or a failed calibration |

### `tests/phase1-provenance-tests.sh` — 21 assertions, all offline

The only sockets touched are a closed local port and a local stub server. The
load-bearing assertions prove the script *refuses* to report: with an unreachable
API it never says a repository is missing, never prints a contributor count, and
never claims a project is not a fork.

> **Stated coverage limit.** Response-shape logic — fork-field handling,
> annotated-tag dereferencing, release-note scanning — is **not** unit-tested.
> Mocking it needs a server that serves both `/repos/o/n` and
> `/repos/o/n/releases`, which a static file server cannot do. That logic is
> covered instead by a live smoke test against a known oracle: run against this
> repo's own worked example it independently reproduces eight facts a human
> recorded by hand, including the exact pinned commit
> `b59df6ac…` from [`../reports/qlmarkdown-v1.5.0-intake.md`](../reports/qlmarkdown-v1.5.0-intake.md).

---

## `phase2-supplychain.sh` — what does it pull in, and what runs at build time?

**The problem it solves.** Phase 2 is where the real defect hid in this repo's
worked example, and where the method failed twice in ways that *looked fine*.
This script does the deterministic half: dependency pins, submodule inventory,
the build files the build system actually invokes, a content sweep for build-time
red flags, and — behind explicit opt-in — whether each pinned commit can still be
retrieved and whether it carries a published advisory.

It implements
[`../docs/phases/phase-2-supply-chain.md`](../docs/phases/phase-2-supply-chain.md).

### Three offline rules, each from a real miss

- **Submodules come from `git ls-tree -r HEAD` gitlinks, not `git submodule
  status`.** On an uninitialised clone the latter reported **1 of 4**. Gitlinks
  live in the tree object whether or not anything is checked out. Mismatches are
  reported in *both* directions: a pinned commit with no declared origin, and a
  declared submodule with no gitlink.
- **Build files are enumerated from the build system, never from filenames.** A
  filename search for `Makefile` missed `dependencies/MakefilePCRE` and
  `MakefileJPCRE` entirely, and a script built on filename patterns would have
  shipped a false clean. This reads `PBXLegacyTarget` entries out of every
  `project.pbxproj` and prints the **difference** between the two enumerations —
  the difference is the evidence.
- **Exclusions are counted and named, never silent.** An exclusion list that
  quietly swallows the whole tree produces a beautifully clean sweep of nothing.

### Why an unparseable project is not a quiet zero

`project.pbxproj` is an OpenStep plist, converted with `plutil` and queried with
`jq`. Both are checked: `plutil` must exit 0 **and** its output must parse as
JSON, because `plutil` writes parse errors to *stdout* and would otherwise hand
back an error string that looks like data.

If a project cannot be parsed, or parses to zero objects, the script says
**inconclusive** and exits 2. It never reports "no build steps," because a
broken parser and a project with no build steps produce identical output.

The red-flag matcher likewise **self-tests against a known-positive line** before
any sweep result is reported, and a sweep that scanned zero files is refused as
a clean result.

### Usage

```bash
# stage the tree YOURSELF first — and never let the clone pull submodules
git clone --depth 1 --no-recurse-submodules -b 1.5.0 <url> quarantine/proj

# offline by default
scripts/phase2-supplychain.sh quarantine/proj \
  --expect-sha <the-commit-you-pinned> \
  --exclude boost --exclude lua-5.5.0

# opt in to the network when you want the two questions offline cannot answer
scripts/phase2-supplychain.sh quarantine/proj --online --probe-pins
```

### Two network flags, not one

**Offline is the default.** Every network-dependent check is skipped and named as
unasked, never quietly passed over.

| Flag | Who picks the destination | Risk |
|---|---|---|
| `--online` | **This script** — `api.osv.dev`, fixed | Low. Responses are parsed as JSON, never executed |
| `--probe-pins` | **The artifact** — URLs out of its own `.gitmodules` | Real, and it gets its own keystroke |

They are separate because of that second row. Git's `ext::` transport *executes a
command*, and `.gitmodules` is attacker-controlled input — handing one to `git`
unchecked would cross the line this whole framework draws. So the probe accepts
**`https://` only**, checked before `git` is ever invoked, and prints every URL
before contacting anything. Git is additionally run with `protocol.allow=never`,
`core.hooksPath=/dev/null`, no credential helper, no terminal prompt, into a bare
repository with no checkout.

`--osv-json <file>` classifies a response you fetched yourself, so a fully
offline run is a real mode rather than a degraded one.

### The probe asks two questions, not one

```
deps/cmark-gfm — origin is reachable but the pinned commit is NOT
```

A single `git fetch` cannot tell *your network is down* from *that commit is
gone*, and those are completely different findings. So each pin gets an
`ls-remote` (is the origin up?) and then a `fetch` (is this commit there?):

| Reachable | Commit retrievable | Reported as |
|:--:|:--:|---|
| yes | yes | retrievable |
| yes | **no** | **blocking** — the pinned code cannot be read, diffed or version-matched |
| no | — | inconclusive, not a finding about the artifact |

That middle row is exactly the shape of the one material defect in this repo's
worked example.

### Zero advisories is not a pass, and it is proved every run

Before any advisory result is reported, `--online` runs a live calibration
against a package with a **known** advisory, plus a fixed version as a negative
control. Measured 2026-09-16:

```
positive control lodash@4.17.15  -> 6 record(s)
negative control lodash@4.17.21 -> 3 record(s)
✅ calibration PASSED
```

Note the fixed release still returns **3**. An absolute "the negative control must
return zero" would fail here — the assertion is *relative*, which is what makes it
survive upstream adding records.

If calibration fails, **every** advisory result is declared unbelievable and the
run exits 2. A broken query and a clean dependency both return zero, so the only
thing separating them is evidence that the path can see a positive.

Pins are queried **by commit**, not by package name. Both submodule gitlinks and
SwiftPM entries carry an immutable revision, so no name-to-ecosystem guess is
needed — and a wrong guess would have produced a confident, empty answer.

> **Known limit:** only submodule gitlinks are advisory-queried today. Revisions
> in `Package.resolved` are listed but not yet queried.

### What it tells you

| Exit | Meaning |
|:----:|---------|
| `0` | Evidence collected; no blocking fact found |
| `1` | A build file matched a fetch-and-run / privilege pattern, **or** a pinned commit could not be retrieved from an origin that *is* reachable. Outranks `2` |
| `2` | Inconclusive: not a git repo, an unparseable build system, a sweep that scanned nothing, or an advisory calibration that failed |

### What it deliberately does **not** do

It does not clone, fetch, build, install or execute anything **from the tree** —
acquisition stays a human step, the same line Phase 4 draws at `ditto -x -k`.
`--probe-pins` asks whether a commit *exists*; it never checks one out. Whether
vendored source matches its upstream byte for byte, and whether any dependency is
trustworthy, are reading and judgement, and stay with a human.

### `tests/phase2-supplychain-tests.sh` — 51 assertions on throwaway repos

Fixtures are real git repositories built with known, countable defects, including
a hostile one whose `.gitmodules` carries `ext::`, `file://` and `git://` URLs.
Nothing in any fixture is ever executed. **Every assertion is offline** — the only
socket touched is a closed local port, used to prove that a failed query reports
inconclusive rather than zero.

Verified by mutation, each against an unmutated control run in the same harness:

| Deliberate break | Detected by | Degrades to |
|---|:--:|---|
| Build-system selector finds no targets | 3 assertions | `MakefilePCRE` silently lost |
| Gitlink parser finds nothing | 4 assertions | **inconclusive**, not clean |
| Red-flag pattern can never match | 6 assertions | **inconclusive** — self-test fires |
| `url_is_safe` accepts any URL | 4 assertions | **the `ext::` URL reaches git** |

> The control run matters as much as the mutant. A first attempt at the last row
> "detected" 10 failures — but 6 of them were the throwaway copy failing to find
> its own library, not the mutation. Harness breakage reads exactly like a caught
> bug unless you run the unmutated copy first.

The exclusion logic carries a positive **and** a negative control: one run proves
the vendored hit is excluded, a second over the same tree proves it is found when
it is not. Without the second, a bug that hid everything would pass.

---

## `phase4-artifact.sh` — Phase 4 evidence, gathered in one pass

**The problem it solves.** Phase 4 is the most script-ready phase in the
framework: a fixed sequence of commands with deterministic answers. Done by
hand it took **38 minutes**, and its friction was never the thinking — it was
`codesign` writing to stderr, entitlement output changing shape between macOS
versions, and nested components that have to be enumerated or they are missed.
This script runs that sequence and fills in the evidence table.

It implements the mechanical half of
[`../docs/phases/phase-4-binary-artifact.md`](../docs/phases/phase-4-binary-artifact.md):
integrity, quarantine provenance, nested components, signature validity,
identity, notarization, Gatekeeper, entitlements, linkage, and whether the
bundle actually contains the code it runs.

### Usage

```bash
# expand the download YOURSELF first — ditto, never unzip
ditto -x -k QLMarkdown.zip quarantine/qlmarkdown/

scripts/phase4-artifact.sh quarantine/qlmarkdown/QLMarkdown.app \
  --archive quarantine/QLMarkdown.zip \
  --published-sha256 <digest-from-the-release-page> \
  --source quarantine/qlmarkdown-src \
  --baseline-out reports/qlmarkdown-v1.5.0.baseline.txt
```

Every option is optional, and each one it is missing is reported as **not
checked** rather than quietly skipped.

| Option | What it adds |
|---|---|
| `--archive` | Hashes the downloaded file and reads its `com.apple.quarantine` tag |
| `--published-sha256` | Compares that hash to the digest the project published |
| `--source` | **The highest-value check:** diffs the artifact's entitlements against the `.entitlements` files in the source you reviewed |
| `--baseline-out` | Writes the drift baseline from the *same* collection as the evidence |

### Why `--source` matters most

Signature and notarization answer *"is this the file the maintainer released?"*
They say nothing about whether the shipped binary asks for more privilege than
the code you read. That question is only answerable by comparison, and it is
exactly the comparison a human is least likely to do by hand across every
nested component.

> ⚠️ **A source tree with no `.entitlements` files produces "no differences"** —
> identical to a clean result and completely meaningless. The script refuses to
> report that as clean and says the diff did not run.

### What it deliberately does **not** do

It does not download, expand, mount, install, launch or execute anything.
Expansion stays a human step and must use `ditto -x -k`; plain `unzip` can
corrupt signing metadata and make a valid signature look broken. Reading
installer scripts also stays human — the script detects a `.pkg`/`.dmg` payload
and prints the `pkgutil --expand` commands rather than running them.

| Exit | Meaning | Next step |
|:----:|---------|-----------|
| `0` | Evidence collected; no blocking fact | Read it. It is evidence, not a verdict — the judgement calls are still yours. |
| `1` | **Blocking fact:** published hash mismatch, or the signature does not verify | A hash mismatch means this is not the file the maintainer released. Rule out an `unzip` expansion before concluding tampering. |
| `2` | Inconclusive — bad arguments, or nothing signed found to read | Point it at an expanded `.app`. |

---

## `lib/artifact-facts.sh` — the one fact collector

`phase4-artifact.sh` and `verify-known-artifact.sh --record` **share this
file**. That is the whole point: the evidence quoted in an audit report and the
baseline stored for future drift checks are produced by the same code, so they
cannot describe the same artifact differently. If they could drift apart, the
disagreement would surface during the update that mattered.

The library is sourced, never run. It also holds the rule about what may be
recorded: **only facts that travel with the file.** Ownership and installed
launchd jobs are assigned at install time, so they live in the `--system-*`
modes instead.

### `tests/artifact-facts-tests.sh` — prove the instruments still see

```bash
scripts/tests/artifact-facts-tests.sh                 # picks a signed app itself
scripts/tests/artifact-facts-tests.sh /Applications/Some.app
```

**Run this after any change to the collector or the comparator.** A
silently-broken collector is this project's recurring failure mode, and the
battery exists because every case asserts an **exact count** rather than the
presence of an expected string — a detector that fires once among 28 false
alarms passes a presence test.

It also validates its own fixtures before trusting them. Three hand-built
fixtures gave misleading results while this was being written: one deleted all
29 entitlement lines instead of one, one was a stale file from an earlier run,
and one removed a key from a single source file when the comparison takes the
union across all of them. Each would have been read as a finding about the code.

> **Three real defects this battery caught**, all of which produced output that
> looked clean:
> 1. BSD `grep` rejects a `{0,400}` repetition (the cap is 255). The error went
>    to stderr, a `2>/dev/null` swallowed it, and a bundle with a CDN `<script
>    src>` reported **no remote loaders**. The detector now self-tests against a
>    known-positive string before reporting.
> 2. `sort` honours locale collation while `comm` compares bytes. Under
>    `en_US.UTF-8` they disagree, `comm` desynchronises, and it reports unrelated
>    lines as drift. Both scripts now force `LC_ALL=C` and assert byte order
>    before comparing.
> 3. `plutil` writes its parse error to **stdout**, so a component with *no*
>    entitlements had `"Cannot parse a NULL or zero-length data"` recorded **as an
>    entitlement** — making "asks for nothing" and "could not be read"
>    indistinguishable. Five such records reached a committed baseline. The
>    collector now checks for content before parsing, and the comparator ignores
>    those records in baselines that already contain them.

---

## `lib/advisory-query.sh` — the one advisory classifier

Sourced, never run. Turns a raw OSV response into classified facts, so a Phase 1
reputation check and a Phase 2 dependency check can never describe the same
advisory picture differently.

**Two real misses shaped it**, both from the QLMarkdown audit:

- **Wrong ecosystem.** Three "unfixed" `cmark-gfm` advisories were `UBUNTU-CVE-`
  records about Ubuntu's *distribution packages*. For a C library vendored as
  source into a macOS app they do not apply at all. Distro records are counted
  and named, never dropped silently — the filtering has to stay auditable.
- **Duplicate CVE.** `CVE-2024-22051` is the same defect as `CVE-2022-24724`,
  re-issued by a different CNA. Counting IDs instead of defects inflated one bug
  into two, so records are de-duplicated into **alias groups**.

`related` links are reported but **never merged automatically** — "related" does
not reliably mean "same defect," and silently merging would trade one counting
error for the opposite one. The human decides; the script surfaces the link.

### Zero is not a pass

A failed API call returns nothing, and nothing reads as "no advisories found."
Four outcomes are kept distinct:

| Situation | Reported as |
|---|---|
| Query not attempted (offline) | `NOT CHECKED` |
| Empty body, malformed JSON, unreadable | **`INCONCLUSIVE`**, exit 2 |
| Valid `{}` no-match response | zero records **plus a demand for calibration** |
| Records returned | classified counts and groups |

> ⚠️ A zero only becomes evidence once a **calibration query against a
> known-vulnerable version** has returned a positive through the same code path.
> The library states this every time rather than trusting the caller to remember.

**`jq` is required and there is no fallback.** It ships at `/usr/bin/jq` on
macOS 15+. `plutil` is explicitly rejected as a substitute: it writes parse
errors to *stdout*, so an unreadable response would arrive looking like data.

### `tests/advisory-query-tests.sh` — 28 offline assertions

Fixtures only; no network, no external code. The load-bearing tests are the
**negative controls**, because the positive ones can be satisfied by broken code:

- a filter that drops *everything* looks identical to a clean result, so one test
  proves records **survive** the filter as well as one proving they are removed;
- a grouper that merges *everything* would satisfy any "these two ended up
  together" test, so one test proves two unrelated defects stay **apart**.

Verified by mutation — the suite was shown to go **red**, not merely green:

| Deliberate break | Result |
|---|---|
| Filter classifies every record as distro | 10 failures, incl. the positive control |
| Grouper merges every record into one group | 3 failures, incl. the negative control |

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

> 🔑 **Ownership is deliberately NOT a baseline record — and that is not an oversight.**
> A baseline answers *"is this the same artifact I audited?"*, so it may only contain
> facts that **travel with the file**: hashes, signatures, Team IDs, entitlements. Those
> are identical on any Mac. **Ownership does not travel with the file** — it is assigned
> at install time, differs by install method, and a disk image mounted `noowners` reports
> the *mounting user* rather than the value recorded in the image. The same image was
> read as uid 502 by a normal user and uid 504 by root in a single session. Baselining
> that would record a reading artifact and break every image-to-installed comparison.
>
> Ownership is therefore **system state**, checked after installing with
> `--system-ownership` — the same reasoning that puts installed launchd jobs in
> `--system-persistence` rather than in the baseline.

### `--system-ownership` — can a lesser account rewrite privileged code?

This is the check that would have caught a real regression: `sudo ditto` preserved a
vendor's build-machine uid, handing a firewall's bundle to an unrelated local account
while **signature, notarization, Gatekeeper, drift and byte-for-byte hashes all passed.**

It reports owner/group/mode, counts non-root-owned and group/world-writable files and
setuid/setgid binaries, then correlates that against the privileged components the
bundle carries — because **non-root ownership only matters when the bundle holds code
that runs with more authority than the account able to rewrite it.** A drag-installed
user application owned by you is normal, and is reported without alarm.

**Three limits, stated plainly:**

1. **It reports state, not change.** It cannot know what the ownership *used to* be.
   Record the figure in the report at install time so the next update can compare.
2. **It counts privileged components the bundle *declares*.** Code installed outside
   the bundle is invisible to it — run `--system-persistence` alongside it. **Neither
   check alone is sufficient.**
3. **It must be run against the installed copy.** Pointed at `/Volumes/…` it refuses
   and explains why, rather than returning a confident wrong answer.

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

It only ever *reads* the artifact: `codesign`, `spctl`, `stapler`, `otool` and
`file` are inspection tools. The script **does not mount disk images, install,
launch or execute anything** — you mount read-only yourself, so the one action
with any attack surface stays an explicit human step. It writes nothing except
the baseline you redirect to a file, and composes no network request — though
`codesign`/`spctl` can still make macOS contact Apple, per
[what "read-only" does not cover](#what-read-only-does-not-cover).

> **This is a Tier 1 check, not an audit.** It answers *"did the trust anchor or
> the privilege change?"* — not *"is this version safe?"* Nothing here replaces
> reading the release notes, and a **human still records every decision.**
> Full workflow: [`../docs/05-update-audit.md`](../docs/05-update-audit.md).
> Worked examples: [`../reports/little-snitch-v6.4.1-intake.md`](../reports/little-snitch-v6.4.1-intake.md)
> (baseline recorded) and [`../reports/little-snitch-v6.5-update-audit.md`](../reports/little-snitch-v6.5-update-audit.md)
> (baseline used).

---

## `phase5-kit/00-calibrate.sh` — prove the instruments work first

**The problem it solves, measured not assumed.** In this framework's worked
example, **15 of the 24 minutes** of Phase 5 preparation went on repairing
instruments rather than auditing:

| What failed | How it failed |
|---|---|
| `log stream` | refused — admin only |
| `log show` | refused — a standard account has no log-store access |
| admin-side live capture | ran, and **silently dropped every message** |
| `qlmanage -m plugins` | printed nothing; it structurally cannot see a modern `.appex` — which prompted **three unnecessary reinstalls** |

Every one of those produced **silence**, and silence reads as clean. This script
proves each instrument can see a **known positive** before you rely on it, and
names the ones that are blind.

### Safe to run anywhere, on purpose

The account checks are **reported, not enforced** here, so one run tells you
about every broken instrument at once instead of one per account switch.
`01-setup.sh` keeps the hard refusal, because that is the script that writes
decoy credentials.

```bash
scripts/phase5-kit/00-calibrate.sh --kit-root /Users/Shared/ecisf-phase5
```

`--kit-root` defaults to `$HOME/ecisf-phase5`. Writing outside your own home is
deliberately **not** the default — for cross-account evidence you pass a shared
path explicitly, so it is a decision rather than an accident.

### What it calibrates

| | Check | Known positive used |
|---|---|---|
| A | Account isolation | non-admin, no passwordless `sudo`, no readable other homes, no real keys — including `id_ed25519`, since a missing `id_rsa` proves nothing |
| B | Unified log | writes a unique marker with `logger` and reads it back |
| C | Local listener | requests `/ecisf-calibration` and reports the HTTP code; a **404 is correct** |
| D | Canary detectability | finds a plaintext **and** a base64 canary, and confirms a never-written string is *not* found |
| E | Extension enumeration | counts what `pluginkit` returns; zero means the tool is blind, not that nothing is installed |
| F | Snapshot commands | `launchctl list`, and login items — which need an Automation permission you want granted *before* an audit, not midway |
| G | Kit root | writable, and correctly reported as inside or outside this account's home |

> **D is the one the worked example turned on.** The Phase 5 finding depended on
> spotting a **base64** copy of a decoy inside rendered HTML. A previewer that
> embeds a file usually encodes it, so the plain words never appear — and a
> broken search would make "no canary found" indistinguishable from "nothing was
> taken."

### What it tells you

| Exit | Meaning |
|:----:|---------|
| `0` | Every instrument saw a known positive |
| `1` | Stop — administrator account, or real credentials present |
| `2` | At least one instrument is blind; the blind spot is named |

### `tests/phase5-calibrate-tests.sh` — 23 assertions

Offline, and writes only to a temporary directory — never `$HOME`, never
`/Users/Shared` — so running the suite cannot disturb a real Phase 5 account.
Mutation-verified against an unmutated control run:

| Deliberate break | Detected by |
|---|:--:|
| Listener check always reports "up" | 2 assertions — the **negative** control |
| Admin-account detection never fires | 3 assertions |

The listener pair is the point: a check that always says "working" passes the
positive control alone.

> **Not yet done:** nothing in this kit is artifact-specific any more, but the
> probe files themselves are still a **Markdown / Quick Look probe pack**.
> Auditing a different kind of artifact means writing probes for it; the
> plumbing around them is now reusable.

---

## `phase5-kit/kit-common.sh` — one configuration, one canary

Sourced by every script in the kit. It exists for two separate reasons, and the
second one is a bug fix rather than a tidy-up.

**Portability.** Every script used to hardcode `/Users/Shared/phase5-kit`, which
blocked running the kit anywhere else. All of them now take the same options:

| Option | Purpose |
|---|---|
| `--kit-root <dir>` | Where the kit reads and writes. Default `$HOME/ecisf-phase5` |
| `--listener-port <n>` | Local evidence listener. Default 8000 |
| `--subject <name>` | What is under test, used in headings and logs |
| `--match <substring>` | How to find the artifact in extension listings |
| `--group-container <id>` | Application group container to inspect, if any |
| `--probe-ext <ext>` | Extension given to probe files, so the OS routes them to the right previewer |

**Correctness — the reason this is not cosmetic.** `01-setup.sh` *plants* the
canary decoys and `03-check-canary.sh` *searches* for them. Those were two
separate string literals in two files. Had they ever drifted, the check would
have hunted for a string that was never planted and reported **"canary NOT
found"** — a false clean, in the single check the Phase 5 finding actually
turned on. One definition removes the possibility, and a test fails if a second
copy is ever reintroduced.

A third, deliberately *different* canary belongs to calibration alone, so that
`00-calibrate.sh` never depends on `01-setup.sh` having run and never leaves an
artefact that could be mistaken for real evidence.

### `tests/phase5-kit-common-tests.sh` — 35 assertions

`HOME` is redirected to a temporary directory before any kit script is invoked,
so the suite cannot plant decoys in a real account. Mutation-verified against an
unmutated control run:

| Deliberate break | Caught by |
|---|:--:|
| Duplicate canary literal reintroduced in `03-check-canary.sh` | 1 assertion |
| Hardcoded `/Users/Shared/phase5-kit` reintroduced in `02-capture.sh` | 1 assertion |

> The canary assertion is source-level on purpose. A behavioural test cannot run
> `01-setup.sh` to completion from an administrator account — and a reintroduced
> literal is precisely what would cause the drift, which *is* detectable by
> reading the file.
