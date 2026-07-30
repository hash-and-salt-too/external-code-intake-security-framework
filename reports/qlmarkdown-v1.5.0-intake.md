# Intake Review — QLMarkdown v1.5.0

> **Status: in progress.** This report is filled in phase by phase and doubles as the
> checkpoint for the review — if the session is interrupted, resume from the first
> section still marked *pending*.
>
> **Result key:** ✅ pass · ⚠️ concern · 🛑 dealbreaker · ➖ N/A · ⏳ pending.
> An unknown that can't be resolved is a ⚠️ or 🛑 — never a ✅.

---

## Summary (fill last)

| Field | Value |
|-------|-------|
| **Software** | QLMarkdown — macOS Quick Look extension for Markdown previews |
| **Repository** (`owner/repo` + URL) | `sbarex/QLMarkdown` — https://github.com/sbarex/QLMarkdown |
| **Exact version audited** (tag / commit hash) | Release tag `1.5.0`, commit `b59df6acb713881a9a3d30352c5c6a93e6218d7f` — https://github.com/sbarex/QLMarkdown/releases/tag/1.5.0 (deliberately **not** the latest release, 1.5.2) |
| **Artifact type** (from triage) | **Type 4 — system extension / OS add-on** (Quick Look extension) |
| **Install method** (source / pre-built / package mgr) | ⏳ pending |
| **Date of audit** | 2026-07-29 |
| **Reviewer** (you; AI may assist with evidence) | Repo maintainer (human). AI assistant gathered and explained evidence only. |
| **Overall risk rating** | ⏳ pending |
| **DECISION** | ⏳ pending — Accept · Accept with restrictions · Reject · Hold |
| **Decision made by** (a human — not the AI) | ⏳ pending |
| **One-line rationale** | ⏳ pending |
| **Re-audit trigger** | ⏳ pending |

> **Decision model:** **Accept** · **Accept with restrictions** (use only under limits written down — never to wave through a risk that can't be explained) · **Reject** (reviewed, not safe) · **Hold — needs a second look** (something unresolved; use/sharing blocked until it is). Unresolved *high-impact* questions default to blocked (*fail closed*). The AI gathers evidence; a **human owns the decision.** See [`../docs/00-scope-and-boundaries.md`](../docs/00-scope-and-boundaries.md).

---

## Step 0 — Triage ✅ complete

- **Artifact type & why:** **Type 4 — system extension / OS add-on.** QLMarkdown is a
  Quick Look extension: it ships compiled (not directly readable), macOS invokes it
  **automatically** when a file is previewed in Finder, and it **parses untrusted input** —
  any Markdown file that gets previewed, including ones received from other people.
  Per [`../docs/02-artifact-triage.md`](../docs/02-artifact-triage.md) this is the
  highest-risk routine category.
- **Primary phases for this type:** **All five**, in order
  **P1 provenance → P2 supply chain → P3 source review → P4 binary/artifact → P5 runtime**.
  Primary focus (●●) on **P1, P4, P5**; **P2 and P3** carry extra weight here because the
  project bundles third-party **C** parsing code that untrusted input reaches directly.
  Quick Triage ([`../docs/checklists/quick-triage.md`](../docs/checklists/quick-triage.md))
  runs first as a go/no-go filter.
- **Chosen install method & trade-off accepted:** ⏳ pending — to be decided by the reviewer
  between (a) pre-built signed/notarized release (leans on P4) and (b) build from source with
  Xcode (leans on P2/P3). Either path still requires P5.

---

## Phase 1 — Provenance & reputation ✅ complete

**Reviewer verdict: proceed.** Strong, corroborated signals across all six sub-steps; one
noted gap (no `SECURITY.md`) consciously accepted. Completed 2026-07-29, ~51 min.

| Check | Result | Evidence / note |
|-------|:------:|-----------------|
| Genuine `owner/repo`, trustworthy link, fork justified | ✅ | Owner/repo is `sbarex/QLMarkdown`, public, **no "forked from" banner** — this is the original, not a copy. Repo URL was originally reached via a **web search**, which is the weakest arrival path; upgraded by an **independent cross-check**: `brew info --cask qlmarkdown` (read-only, no install) resolves to the same project. No typosquat/lookalike indicators. |
| Commit history real & spread over time | ✅ | Continuous history spanning ~6 years, with files last touched anywhere from 6 years to 3 weeks ago. Not a single "initial commit" dump. |
| Maintenance recency / release history | ✅ | **51 tagged releases** with written changelogs; latest commit ~3 weeks before audit. Actively maintained, so security fixes are plausible. |
| Contributors (bus factor) & issue activity | ✅ | **18 contributors** (dominated by `sbarex`). Issues **enabled** with 28 open, 6 open PRs, Discussions enabled — public scrutiny is not suppressed. Reviewer specifically noticed `@claude` in the contributor list, followed through to that profile, and judged it legitimate. |
| Maintainer identity & track record; no takeover signs | ✅ | `sbarex`: established account with a body of related macOS QuickLook-family projects; consistent identity across GitHub Sponsors and a public buymeacoffee page. No sudden maintainer change, rewritten history, or out-of-character commit bursts. |
| Security posture (`SECURITY.md`, `LICENSE`, advisories) | ✅ ¹ | `LICENSE.txt` present (**GPL-3.0**). README carries an explicit [Note about security](https://github.com/sbarex/QLMarkdown#note-about-security) that *volunteers* its own entitlement exceptions (system-wide read access for local-image previews; a `com.apple.security.temporary-exception.mach-lookup.global-name` entitlement to work around a Big Sur WebKit bug) and states no data about the system or processed files is collected — self-disclosure is a maturity signal. Release 1.5.0 notes state **"Application is now codesigned and notarized!"** — i.e. 1.5.0 is the first release for which Phase 4 signature checks should succeed. **¹ Known gap: no `SECURITY.md` and no documented vulnerability-reporting path.** Reviewer weighed this and accepted it on the basis of the maintainer's high activity, demonstrated responsiveness, and the absence of any past advisories. Recorded here rather than waved through. |
| External reputation search | ✅ | Web searches for `"QLMarkdown" malware` / `security` / `vulnerability` / `attack chain` → **no meaningful hits**. **GitHub Advisories → none.** **OSV → clean for QLMarkdown itself.** OSV for the bundled parser **`cmark-gfm` → 30 vulnerabilities** dating from July 2020, most recent December 2025, of which **3 have no fix**. Historical parser CVEs are expected and not disqualifying on their own; what matters is which ones the bundled version is exposed to. **Not completed:** mapping NVD/OSV `cmark-gfm` advisories onto the version actually bundled in QLMarkdown 1.5.0 — the reviewer could not determine how to connect the two and deliberately deferred it rather than burn phase time. **Carried into Phase 2 as an open question** (the submodule commit gets pinned there). |
| **Version pinned** | ✅ | **Tag `1.5.0`**, commit **`b59df6acb713881a9a3d30352c5c6a93e6218d7f`**, released 2026-04-08. Deliberately **not** the latest (1.5.2, released ~June 2026). Rationale: (a) caution about AI-assisted contributions / supply-chain poisoning in very recent code — an older, longer-exposed tag has had more time under public eyes; (b) it sets up a follow-on exercise of auditing only the **diff** from 1.5.0 → 1.5.2 using this framework. Trade-off explicitly accepted: any defect fixed in 1.5.1/1.5.2 remains present in the audited version. |

## Phase 2 — Supply chain ⏳ pending

| Check | Result | Evidence / note |
|-------|:------:|-----------------|
| Direct dependencies listed | ⏳ | |
| Lockfile present / versions pinned | ⏳ | |
| Notable dependencies triaged; no typosquats/odd forks | ⏳ | |
| Vendored code & submodules match trusted upstream | ⏳ | |
| Build/install scripts read & benign (no fetch-and-run, no `sudo`, no blobs) | ⏳ | |
| Dependencies vs. advisory DBs (GH/OSV/NVD) | ⏳ | |

## Phase 3 — Source review ⏳ pending

| Check | Result | Evidence / note |
|-------|:------:|-----------------|
| Network access accounted for | ⏳ | |
| Command/process execution accounted for | ⏳ | |
| No dynamic/remote code execution (or justified) | ⏳ | |
| No sensitive-file/credential access (or justified) | ⏳ | |
| No unsafe deserialization | ⏳ | |
| No unjustified persistence mechanisms | ⏳ | |
| No unjustified privilege escalation | ⏳ | |
| No obfuscation / hidden payloads | ⏳ | |
| Telemetry disclosed & proportionate (or none) | ⏳ | |
| Untrusted-input handling (memory safety / sanitization) | ⏳ | |
| Fork diff reviewed (if applicable) | ⏳ | |

## Phase 4 — Binary / artifact ⏳ pending

| Check | Result | Evidence / note |
|-------|:------:|-----------------|
| Official HTTPS source | ⏳ | |
| SHA-256 hash matches published | ⏳ | |
| Signature valid & trusted key (if provided) | ⏳ | |
| Code signing valid; Team ID matches maintainer | ⏳ | |
| Notarized / Gatekeeper accepted / stapled | ⏳ | |
| Entitlements minimal & sensible; sandbox status | ⏳ | |
| Mach-O quick look (`otool`/`strings`/`nm`) clean | ⏳ | |
| `.pkg`/`.dmg` inspected w/o installing; scripts read | ⏳ | |

## Phase 5 — Runtime / sandbox ⏳ pending

| Check | Result | Evidence / note |
|-------|:------:|-----------------|
| Isolation level used | ⏳ | |
| Network behavior (destinations contacted) | ⏳ | |
| File access (only expected paths) | ⏳ | |
| Process spawning (nothing unexpected) | ⏳ | |
| Behavior with hostile/malformed input | ⏳ | |
| Persistence check (launch agents, login items, QL plugins, rc) | ⏳ | |
| Clean uninstall / snapshot reverted | ⏳ | |

---

## Findings & open questions

**From Phase 1:**

1. **No `SECURITY.md` / no vulnerability-reporting path.** ⚠️ Known gap, accepted by the
   reviewer given maintainer activity, responsiveness, and a clean advisory history. Means
   there is no defined channel if *you* ever find something.
2. **`cmark-gfm` CVE exposure is the headline risk.** OSV lists 30 advisories for the bundled
   parser (Jul 2020 – Dec 2025), 3 with no fix. This C library parses every file previewed,
   including files received from other people. **Open:** pin the exact `cmark-gfm` submodule
   commit at tag `1.5.0` and determine which advisories that commit is exposed to. → Phase 2.
3. **Method gap to close:** how to connect an NVD/OSV advisory for an upstream C library to the
   specific version vendored inside a macOS app. Blocked the reviewer in Phase 1; resolvable in
   Phase 2 by reading `.gitmodules` + the pinned submodule SHA. Flagged for a walkthrough.
4. **Audited version is superseded.** 1.5.0 vs. current 1.5.2 — accepted deliberately (see
   "Version pinned"), but it means the review certifies an older artifact than the one a naive
   install would fetch.
5. **Network behavior to verify later (P3/P5).** README states MathJax and Mermaid JS libraries
   are **downloaded from `cdn.jsdelivr.net` and cached on first launch**, and the Emoji
   "images" mode fetches emoji images from GitHub. Both need to be confirmed as opt-in/bounded.
6. **Entitlements to verify for real (P4).** Self-disclosed: system-wide **read** access
   exception, plus `com.apple.security.temporary-exception.mach-lookup.global-name`. Disclosed
   ≠ verified — Phase 4 must confirm what the shipped binary actually requests.
7. **Untrusted-input surface (P3/P5).** Codebase is ~96% C++/C. The "Inline HTML (unsafe)"
   option renders raw HTML and `javascript:`/`data:` links; README says it is **off by
   default** — the default must be confirmed in source, not taken on trust.

## Dealbreakers encountered (if any)

- None as of end of Phase 1.

## Conditions / restrictions if installing

_(to be written by the reviewer if the decision is "Accept with restrictions")_

## Decision rationale (the "why," in a few sentences)

> ⏳ pending

## Update log (re-audits of later versions)

| Date | New version | What changed (diff summary) | Re-verdict |
|------|-------------|-----------------------------|-----------|
| | | | |
