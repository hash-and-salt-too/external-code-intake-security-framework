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
| **Overall risk rating** | ⏳ pending final — currently trending **High** on the untrusted-input path (finding #22) |
| **DECISION** | 🟡 **HOLD — needs a second look** (interim, recorded 2026-08-03 after Phase 3). *Not a rejection.* Use and sharing are blocked until Phase 5 resolves whether finding #22's arbitrary local-file read can be exfiltrated. If Phase 5 shows it cannot, this may loosen to **Accept with restrictions** with "Inline HTML (unsafe)" **off**. |
| **Decision made by** (a human — not the AI) | Repo maintainer (human), 2026-08-03. AI gathered and explained evidence only. |
| **One-line rationale** | A merely-previewed Markdown file can cause arbitrary user-readable files to be base64-embedded into the preview DOM (#22); impact is unresolved pending runtime observation, so *fail closed* until it is. |
| **Re-audit trigger** | ⏳ pending final |

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
- **Build preflight result / selected build file (if applicable):** Not yet run against a
  quarantined tree, but the toolchain side is already conclusive. Measured 2026-08-03 on the
  review machine: macOS **15.7.8**, **no Xcode installed** — the active developer directory is
  `/Library/Developer/CommandLineTools`, so `xcodebuild` is unavailable and `xcodebuild
  -showsdks` returns no macOS SDK. Xcode-selected Swift is **6.1.2** (CLT), target
  `x86_64-apple-macosx15.0` (Intel). `cmake`, `autoconf`, `automake`, `pkg-config` are **not
  installed**; GNU `glibtool` is present. Against an Xcode-project tree,
  [`check-build-feasibility.sh`](../scripts/check-build-feasibility.sh) would therefore return
  **exit 2 — inconclusive** (it requires detectable full-Xcode, developer-directory and SDK
  evidence). See [`../docs/design-decisions-Xcode.md`](../docs/design-decisions-Xcode.md).
  **Separate, non-toolchain blocker:** upstream PR
  [#224](https://github.com/sbarex/QLMarkdown/pull/224) states the `cmark-gfm` submodule commit
  pinned at tag `1.5.0` **cannot be fetched from `github/cmark-gfm`**, so
  `git submodule update --init` cannot reconstitute 1.5.0 as released. This is an
  **obtainability** blocker, not a declared-compatibility one — a class the preflight helper
  does not cover.
- **Source↔binary correspondence established? If not, why not:** ⏳ pending. On current
  evidence it **cannot** be established for 1.5.0: the source tree as released is not fully
  obtainable (see above), so any binary reviewed will be the maintainer's, not one built from
  reviewed source. Per the framework this is a **triage branch, not a Hold** — a bounded
  environment/upstream limitation rather than an unresolved risk in the code — but it must be
  recorded and it shifts weight onto Phase 4 and Phase 5.
- **Older release considered? Exact version and later security fixes checked:** Yes — inverted
  case. The reviewer *deliberately* pinned the older `1.5.0` rather than current `1.5.2` (see
  Phase 1, "Version pinned"). Framework rule for older releases therefore applies: the
  `1.5.1`/`1.5.2` changelogs and any advisories must be checked for security fixes made after
  `1.5.0`. ⏳ **Open task for Phase 2.**

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

## Phase 2 — Supply chain ⚠️ complete with concerns

**Reviewer verdict: proceed with concerns.** The *plumbing* is unusually clean — no CI, no
run-script build phases, no fetch-and-run, everything pinned. The concern is **verifiability**
of what's pinned, concentrated entirely on the Markdown parser.

Source staged read-only at `quarantine/qlmarkdown-1.5.0` (shallow clone of tag `1.5.0`,
submodules deliberately **not** initialized). HEAD verified `= b59df6acb713881a9a3d30352c5c6a93e6218d7f`.

| Check | Result | Evidence / note |
|-------|:------:|-----------------|
| Direct dependencies listed | ✅ | **Ten** direct third-party components in three mechanisms. *Git submodules (4):* `cmark-gfm` ← `github/cmark-gfm`; `dependencies/pcre2` ← `PhilipHazel/pcre2`; `dependencies/jpcre2` ← `jpcre2/jpcre2`; `highlight-wrapper/highlight` ← **gitlab.com**`/saalen/highlight`. *SwiftPM (4):* `Sparkle 2.9.1`, `swift-argument-parser 1.7.1`, `SwiftSoup 2.13.4`, `Yams 6.2.1`. *Vendored in-repo, non-submodule (2):* **Boost 1.87.0** (59 MB, `highlight-wrapper/boost/`) and **Lua 5.5.0** (`highlight-wrapper/lua-5.5.0/`). ⚠️ **Boost and Lua appear in neither the README's dependency list nor `.gitmodules`** — they were found only by walking the tree. Not concealment (they sit in plain view), but the project's own documentation understates what it ships. |
| Lockfile present / versions pinned | ✅ | `QLMarkdown.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` is committed, and every SwiftPM dependency is pinned to **both a semantic version and an immutable revision SHA**. All four submodules are pinned to exact commit SHAs. **No floating ranges (`^`, `~`, `latest`) anywhere.** This is materially better than typical for a hobby project. |
| Notable dependencies triaged; no typosquats/odd forks | ✅ | Every location resolves to the genuine upstream: `sparkle-project/Sparkle`, `apple/swift-argument-parser`, `scinfu/SwiftSoup`, `jpsim/Yams`, `github/cmark-gfm`, `PhilipHazel/pcre2`, `jpcre2/jpcre2`. Highlight pointing at **GitLab** is correct — `gitlab.com/saalen/highlight` is that project's real home, not a suspicious mirror. No forks-in-place-of-upstream, no near-miss names. ⚠️ **`Sparkle` is an auto-updater framework** — a legitimate, widely used one, but by design it is a channel for the app to fetch and install *new code* after this version is approved. Carried to P3/P4/P5 (appcast URL, signature verification, whether it can be disabled). |
| Vendored code & submodules match trusted upstream | ⚠️ | **Tested directly** (targeted `git fetch` of each pinned SHA into a throwaway bare repo): `jpcre2`, `pcre2` and `highlight` pins are all **fetchable** from upstream ✅. **`cmark-gfm`'s pinned commit `c168d57acfa1f688e519e4e829f9a28d559bd5fa` is NOT fetchable** — independently confirming upstream PR [#224](https://github.com/sbarex/QLMarkdown/pull/224). Two independent pointers name the intended version: `cmark-extra/Makefile` hardcodes output `libcmark-gfm.${SPECVERSION}.0.gfm.13.dylib`, and PR #224 says the fix moved to "upstream `0.29.0.gfm.13`". But upstream tag `0.29.0.gfm.13` is commit `587a12bb54d95ac37241377e6ddc93ea0e45439b` — **a different SHA**. So the bundled parser *claims* 0.29.0.gfm.13 while being pinned to a commit that cannot be retrieved, read, or diffed against upstream. Also: the `highlight` submodule **is modified at build time** — `highlight-wrapper/Makefile` copies `highlight_custom/makefile2.makefile` and `highlight_custom/src/makefile2.makefile` over the submodule's. Inspected: **build configuration only, two files, no source patches**. Vendored **Boost 1.87.0 (59 MB)** and **Lua 5.5.0** were **not** verified against upstream — honestly beyond what manual beginner-level review can cover. |
| Build/install scripts read & benign (no fetch-and-run, no `sudo`, no blobs) | ✅ | Five project build files: `cmark-extra/Makefile` (148 ln), `highlight-wrapper/Makefile` (258 ln), `dependencies/MakefilePCRE` (165 ln), `dependencies/MakefileJPCRE` (159 ln), plus Lua's own. Invoked by **11 `PBXLegacyTarget` entries** via `buildToolPath = /usr/bin/make`. **Zero `PBXShellScriptBuildPhase` / `shellScript` entries in either Xcode project** (main and `highlight-wrapper.xcodeproj`) — the framework's headline Xcode build-time attack surface is simply absent. All content is compile/link orchestration (`clang++`, `lipo`, `cp`/`ln`/`rm`) with writes confined to `BUILT_PRODUCTS_DIR` or the project dir. **Content-based sweep of the whole tree** for `curl`/`wget`/`base64`/`eval`/`sudo`: **zero hits**. Only `/etc/` references are Highlight's upstream `conf_dir` variables, unreachable because only the `lib-static` target is built. ⚠️ Method note: a *filename*-based search missed `MakefilePCRE`/`MakefileJPCRE` entirely; they were found only by reading the Xcode legacy targets. |
| Dependencies vs. advisory DBs (GH/OSV/NVD) | ⚠️ | OSV lists **30 advisories for `cmark-gfm`** (Jul 2020 – Dec 2025), **3 without a fix**. **All three checked individually and none applies to `0.29.0.gfm.13`:** `CVE-2020-5238` (table extension O(n²) DoS — fixed **`gfm.1`**, CVSS 6.5); `CVE-2022-24724` (integer overflow in `table.c:row_from_string` → heap corruption, potential RCE — fixed **`gfm.3`**, CVSS **9.8 Critical**); `CVE-2023-22485` (out-of-bounds read in `validate_protocol`, upstream calls it "harmless in practice" — fixed **`gfm.7`**, CVSS 5.3). **Why they showed as "unfixed":** all three are **`UBUNTU-CVE-…`** records — Canonical tracking *Ubuntu distribution packages* (`haskell-cmark-gfm`, `python-cmarkgfm`, `r-cran-commonmark`, `ruby-commonmarker`, `cmark-gfm 0.29.0.gfm.0-4ubuntu0.1~esm1`), not the upstream C library. "No fix" = Ubuntu shipped no patched `.deb` for those distro releases, **not** that upstream lacks a fix; each record names its upstream fix version in its own details. For a dependency **vendored as C source into a macOS app, distro-ecosystem records are the wrong ecosystem and do not apply.** **Residual exposure remains, for two reasons:** (a) `0.29.0.gfm.13` is ~3 years old and upstream has cut no release since, so anything found *after* it has no fix by definition — but see the upstream-CVE review below, which found no such advisory; (b) this entire clearance is conditional on the bundle actually **being** `gfm.13`, which finding #8 shows cannot be verified. Not checked: Boost 1.87.0, Lua 5.5.0, Highlight, PCRE2, Sparkle, SwiftSoup, Yams. |
|  ↳ *upstream `CVE-`/`GHSA-` records (correct ecosystem)* | ✅ | The two most recent **upstream-scoped** `cmark-gfm` records were checked directly. `CVE-2023-37463` — three polynomial-time-complexity bugs → unbounded resource exhaustion/DoS, **fixed `0.29.0.gfm.12`**, CVSS 6.4. `CVE-2024-22051` — CVSS **9.8 Critical**, "CommonMarker Integer Overflow", published Jan 2024; primary affected package is the **Ruby gem CommonMarker `< 0.23.4`**, and its `cmark-gfm` GIT range extracts to **fixed `0.29.0.gfm.3`**. It is listed as *Related* to `GHSA-mc3g-88wq-6f4x` — i.e. **the same underlying table `row_from_string` overflow as `CVE-2022-24724`**, re-issued in 2024 by a different CNA (VulnCheck) against a downstream re-packager. **Net: across five advisories examined, every fix lands at `gfm.1`, `.3`, `.7` or `.12`; `0.29.0.gfm.13` clears all of them, and no published advisory is known to affect it.** The earlier "December 2025" sighting was an OSV *modified* timestamp, not a new vulnerability — the newest genuine `cmark-gfm` CVE is Jan 2024 and is a duplicate. ⚠️ **"No known advisory" is not "no vulnerability":** upstream has published no release in 3 years and carries 112 open issues, so quiet may reflect reduced scrutiny rather than robustness. |
| *(additional)* Build provenance / CI | ⚠️ | `.github/` contains **only `FUNDING.yml`** — **no CI workflows at all** at tag 1.5.0. Releases are therefore built on the maintainer's own machine with no automated, reproducible, or attested pipeline. Not unusual for a hobby project, but it means the published binary's provenance rests **entirely** on the code signature verified in Phase 4. |

## Phase 3 — Source review ⚠️ complete with a significant concern

**Scope of this phase.** First-party source only: `QLExtension` (236 ln), `QLMarkdown` (4,497 ln),
`cmark-extra` (5,369 ln of first-party C/C++), `highlight-wrapper` (883 ln), `Shortcut Extension`,
`qlmarkdown_cli`, `external-launcher`. The vendored parsers (`cmark-gfm`, `pcre2`, `jpcre2`,
`highlight`) are **uninitialized submodules and were not reviewed**; `cmark-gfm` is unobtainable
(finding #8). Nothing was built or executed — reading only.

| Check | Result | Evidence / note |
|-------|:------:|-----------------|
| Network access accounted for | ✅ | Every destination in first-party code is documented and expected: `cdn.jsdelivr.net` (MathJax `Settings.swift:1069`, Mermaid `:1053`), `github.githubassets.com/images/icons/emoji/*` (emoji-as-images mode), `github.com/` (`mention.c:65`, link *targets* only), plus about-box/attribution URLs. **No unexplained domains, no hardcoded IP addresses, no beaconing.** |
| Command/process execution accounted for | ✅ | **Zero** process execution in first-party code — no `Process(`, `NSTask`, `system(`, `popen`, `posix_spawn`. ⚠️ The only `popen` in the tree is **vendored Lua 5.5.0's `liolib.c`** (`io.popen`), linked into the Highlight engine. Whether Highlight exposes the full Lua stdlib to its language-definition scripts could not be determined — the `highlight` submodule is not checked out. |
| No dynamic/remote code execution (or justified) | ✅ | No `dlopen`/`dlsym`/`NSClassFromString` in first-party code (all such hits are vendored Lua). Two `evaluateJavaScript` calls (`ViewController.swift:850`, `:1548`) interpolate a **numeric scroll position** into a JS string in the *main app's* editor pane — not the Quick Look extension, and not fed by document content. Minor style concern only. |
| No sensitive-file/credential access (or justified) | ⚠️ | No direct references to `~/.ssh`, Keychain, `SecItemCopyMatching`, `~/.aws`, cookies or shell rc files anywhere in first-party code — the apparent grep hits were false positives from Lua internals (`keyisshrstr` matching "ssh"). **However, see finding #22:** an indirect arbitrary-file-read path exists via the raw-HTML inline-image handler. |
| No unsafe deserialization | ✅ | Settings use `Codable`/JSON. `Yams` parses YAML front-matter — a Swift YAML parser without Ruby/Python-style object instantiation. No `NSKeyedUnarchiver` on untrusted input observed. |
| No unjustified persistence mechanisms | ✅ | **Zero hits** for `LaunchAgents`, `LaunchDaemons`, `launchctl`, `SMLoginItem`, `crontab`. Correct for a preview extension. |
| No unjustified privilege escalation | ✅ | **Zero hits** for `AuthorizationExecuteWithPrivileges`, `setuid`, `sudo`, "administrator privileges". |
| No obfuscation / hidden payloads | ✅ | No base64 blobs presented as code, no minified first-party sources, no encoded-then-executed content. `cmark-extra/b64.c` is a **directory** containing a small vendored base64 library (used for data-URI image embedding) — legitimate, though another undocumented third-party component. |
| Telemetry disclosed & proportionate (or none) | ✅ | `Settings.renderStats` is a **local counter only**. Incremented in `PreviewViewController.swift:147` and the CLI; used solely to inject a "buy me a coffee" block into the preview every 100 renders. **Never transmitted** — no network send anywhere in its code paths. Not telemetry. ℹ️ Minor privacy note: `os_log(… %{public}s, url.path)` records the **path of every previewed file** into the system log at public visibility. |
| Untrusted-input handling (memory safety / sanitization) | 🛑 | **See finding #22 — the significant concern of this audit.** Additional context: `unsafeHTMLOption` defaults to **`true`** and `validateUTFOption` defaults to **`false`**, so raw document HTML is rendered and UTF-8 validation is *off* before input reaches the C parser. `SwiftSoup` is used only as a **DOM parser** (`parseBodyFragment`) — **not** as a sanitizer; no `Cleaner`/`Safelist`/`Whitelist` appears anywhere. The only HTML filtering is GFM's `tagfilter`, a **9-tag blocklist** that does not stop event-handler attributes (`<img onerror=…>`, `<svg onload=…>`). |
| Fork diff reviewed (if applicable) | ➖ | Not a fork — `sbarex/QLMarkdown` is the original (Phase 1). |

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

**From Phase 2:**

8. **The parser pin is unobtainable — the central finding.** `cmark-gfm` is pinned to
   `c168d57a…`, which **cannot be fetched from upstream** (verified directly, not just taken
   from PR #224). The component that processes every previewed file therefore cannot be read,
   cannot be diffed against upstream, and cannot be conclusively version-matched. It *claims*
   `0.29.0.gfm.13`, but that tag is a **different commit** (`587a12bb…`). This is a
   **verifiability gap, not evidence of tampering** — but it is unresolvable at this level.
9. **The parser cannot be patched by upgrading.** `0.29.0.gfm.13` is upstream's newest-ever
   release and is ~3 years old; no release has been cut since. Any unfixed advisory against it
   stays unfixed. This converts "stale dependency" from a maintenance nit into a standing,
   permanent exposure on the untrusted-input path.
10. **Two vendored libraries absent from the documented dependency list — but they are
    *transitive* deps, not hidden additions.** Boost 1.87.0 (59 MB) and Lua 5.5.0 ship in-repo
    and appear in neither the README dependency list nor `.gitmodules`. **Corrected on further
    evidence:** Highlight's own makefile (`highlight_custom/src/makefile2.makefile`) contains a
    "Lua Detection" section and builds `LuaExceptions.o`, `LuaFunction.o`, `LuaState.o`,
    `LuaWrappers.o` — i.e. **Lua is Highlight's own dependency**, and Boost sits at the same
    level for the same reason. Vendoring them makes the build self-contained without Homebrew,
    which is a normal and defensible choice. This is therefore a **documentation gap, not a
    transparency failure**; an earlier, harsher "undeclared dependencies" framing was
    overstated and is withdrawn. Neither was verified against upstream — 59 MB of Boost headers
    is an explicit **ceiling of this review**, stated rather than glossed.
11. **Lua is an embedded script engine.** Highlight drives syntax highlighting via Lua language
    definitions, so previewing a fenced code block executes Lua scripts shipped with the app.
    Not attacker-controlled by default, but it is script execution inside a previewer. → P3.
12. **Sparkle auto-updater: configured, signature-verified, and not silently automatic.**
    `QLMarkdown/Info.plist` sets `SUFeedURL` = `https://sbarex.github.io/QLMarkdown/appcast.xml`
    (HTTPS, maintainer's own domain), `SUScheduledCheckInterval` = `86400` (24 h), and
    **`SUPublicEDKey` = `J+ikFQXeR6eaUV0jvyfZAJKeYh+9UKGJuD/kJSIXnZk=`** — an EdDSA public key,
    so Sparkle 2 cryptographically verifies every downloaded update; a compromised appcast alone
    cannot deliver code without the maintainer's private key. ✅ Correct design.
    **Neither `SUEnableAutomaticChecks` nor `SUAutomaticallyUpdate` is set**, so per Sparkle's
    documented defaults the app should *ask* before its first automatic check and will not
    silently self-install. Manual check exists (`checkForUpdates` in `AppDelegate.swift` /
    `ViewController.swift`). ⚠️ **This rests on Sparkle's defaults, not on anything QLMarkdown
    asserts — verify at runtime in P5** that nothing reaches `sbarex.github.io` before consent.
    **Framework point regardless:** auto-update is by design a route for the audited artifact to
    become an unaudited one. EdDSA proves *authenticity*, never *safety*. Disabling it is a
    natural restriction candidate — firewall-deny `sbarex.github.io` (strongest),
    `defaults write org.sbarex.QLMarkdown SUEnableAutomaticChecks -bool NO`, or decline the
    first-launch prompt.
13. **No CI at 1.5.0.** Only `FUNDING.yml` under `.github/`. Release binaries are built on the
    maintainer's machine with no attestation — all binary trust rests on Phase 4 signing.
14. **Positive findings worth recording.** Zero Xcode run-script build phases; zero
    fetch-and-run/`sudo`/`base64` anywhere; a committed SwiftPM lockfile with revision-level
    pinning; all upstreams genuine with no typosquats or substituted forks.
15. **1.5.1 / 1.5.2 carry no advertised security fix** (required check for pinning an older
    release). 1.5.1: "Fixed css popup menu refresh." 1.5.2: features plus **"Fixed memory leaks
    in the inline-image, mention and emoji extensions"** and Highlight updated to 4.20. Memory
    *leaks* are not memory-safety vulnerabilities, but they sit in custom C extensions on the
    untrusted-input path — security-adjacent, and a fair reason to prefer 1.5.2 for actual use.
16. **Method note for scripting.** Filename-based discovery of build files **missed two of
    them** (`MakefilePCRE`, `MakefileJPCRE`); they surfaced only by reading the Xcode legacy
    targets. Any future script must enumerate build files from the *build system*, not from
    filename patterns.
17. **Advisory-ecosystem trap (method lesson).** The three "unfixed" `cmark-gfm` advisories were
    all `UBUNTU-CVE-…` records about **Ubuntu distro packages**, not the upstream C library.
    Vendored-source dependencies must be matched against **upstream `CVE`/`GHSA`** records;
    distro records (`UBUNTU-`, `DEBIAN-`, `RHEL-`, `SUSE-`) describe a packaging ecosystem this
    artifact is not part of. Any future advisory-mapping script must filter by ecosystem, or it
    will produce false alarms.
18. **Table parsing is this parser's historical hot spot.** Two of the three advisories reviewed
    (`CVE-2020-5238`, `CVE-2022-24724` — the latter CVSS 9.8 with potential RCE) are table-
    extension bugs, and the published workaround for the critical one was literally "disable the
    table extension." QLMarkdown exposes **Tables** as a user-toggleable extension. → P3/P5, and
    a candidate lever if the decision ends at *Accept with restrictions*.
19. **Advisory picture resolved in the parser's favour — conditionally.** Five `cmark-gfm`
    advisories examined; all fixes land at `gfm.1`, `.3`, `.7` or `.12`, so **`0.29.0.gfm.13`
    clears every published advisory** and there is no known post-`gfm.13` vulnerability. This
    substantially reduces the Phase 2 concern — **but only for a bundle that genuinely is
    `gfm.13`**, which finding #8 shows cannot be established. The risk therefore shifts from
    "known-vulnerable dependency" to "unverifiable dependency identity."
20. **Duplicate-CVE trap (method lesson).** `CVE-2024-22051` (CVSS 9.8, dated 2024) is the *same
    bug* as `CVE-2022-24724` (2022), re-assigned by a different CNA against a downstream
    re-packager (Ruby CommonMarker). **A CVE's assignment date is not the bug's date.** Always
    read `Aliases`/`Related` before counting a recent ID as a new problem — otherwise one defect
    inflates the risk picture two or three times. A future advisory script must de-duplicate by
    alias group, not by CVE ID.
21. **Three of five parser advisories are table-extension bugs**, two of them critical‑severity
    integer overflows. Whatever the version question, **tables are where this parser breaks.**

**From Phase 3:**

22. 🛑 **Arbitrary local-file read reachable from a previewed document (the significant finding).**
    Established by source reading only; **not tested, not executed.** Two image paths exist with
    different protection:
    - **Path A — markdown-syntax images `![](…)`: protected.** Swift passes `nil` for the MIME
      callback (`Settings+render.swift:254`), so the C code derives the type **independently**
      via `get_mime(image_path, 2)` and then enforces `startsWith("image/", mime)`
      (`inlineimage.c:231–236`). A caller cannot influence that derivation.
    - **Path B — raw HTML `<img src="…">` while unsafe HTML is on: the check is vacuous.**
      The Swift `unsafe_html_processor_callback` (`Settings+render.swift:~289–325`) builds
      `mime = "image/\(ext)"` from the *path extension*, with a `default:` branch accepting
      **any** extension, then passes that string to `get_base64_image2`, which validates the
      **caller-supplied** value against `startsWith("image/", mime)` (`inlineimage.c:333`).
      It always passes by construction; a file with no extension yields `"image/"`, which also
      passes. There is additionally **no path-traversal check** —
      `baseDir.appendingPathComponent(src).path` is applied directly to document-controlled `src`.

    **Resulting chain:** `<img src="../../../../../../Users/<you>/.ssh/id_rsa">` in a `.md` file
    → not `http`, not `data:` → resolves outside the document folder → `fileExists` ✓ →
    `mime = "image/"` ✓ → `fopen` + full read + `b64_encode` → embedded in the preview DOM as
    `data:image/;base64,…`. **Triggered by merely selecting the file in Finder** — no click, no
    consent. Amplified by `unsafeHTMLOption` defaulting to **`true`** and the extension's
    `com.apple.security.temporary-exception.files.absolute-path.read-only = /` entitlement.

    **Explicitly NOT established:** that the data can be **exfiltrated**. That requires
    JavaScript executing in Quick Look's host *and* network egress. The extension does hold
    `com.apple.security.network.client`, and Math/Mermaid are enabled by default — but the JS
    policy on the macOS 12+ data-based path is unproven (see #24). TCC still gates
    `~/Documents`/`~/Desktop`; `~/.ssh`, `~/.aws` and shell rc files are **not** TCC-protected.
    → **Phase 5 verification item, to be tested only in an isolated environment.**
23. ⚠️ **Documented defaults do not match code defaults.** README: *"By default, HTML tags are
    stripped and unsafe links are replaced by empty strings."* Source: `unsafeHTMLOption = true`
    (`Settings.swift:475`). The README accurately describes **`cmark-gfm`'s library** default,
    but QLMarkdown ships the opposite. Also `validateUTFOption = false` (`:479`) — UTF-8
    validation is **off**, so malformed UTF-8 reaches the C parser unvalidated. Docs-vs-code
    divergence on a security-relevant default is a finding in its own right.
24. **Which render path is live matters, and it is unverified.** `QLIsDataBasedPreview` is `true`
    in `QLExtension/Info.plist`, so on macOS 12+ the live entry point is `providePreview(for:)`
    returning a `QLPreviewReply`; the `loadView()` block setting
    `configuration.preferences.javaScriptEnabled` is **dead code** on modern macOS. The extension
    therefore **does not control the JS policy** — Quick Look's host does. Note the default
    expression `(unsafeHTML && inlineImage) || !mermaid.isDisabled || !math.isDisabled` evaluates
    **true on all three clauses**, and Math/Mermaid are advertised as working in Quick Look
    previews, which strongly implies JS *does* execute there. → P5.
25. **XPC launcher performs no scheme validation.** `external-launcher` exposes
    `open(_ url: URL)` → `NSWorkspace.shared.open(url)` with **no allow-list**, and its
    `shouldAcceptNewConnection` returns `true` unconditionally without validating the peer's code
    signature. Reachable when a user **clicks** a link in a preview
    (`PreviewViewController.decidePolicyFor`, which filters only `scheme != "file"`). The real
    defense is upstream in `cmark-gfm`'s link scrubbing — which `unsafeHTMLOption = true` relaxes.
    Requires user interaction, so lower severity than #22, but it is missing defense-in-depth.
26. **Entitlements declared by the Quick Look extension** (`QLExtension.entitlements`; the shipped
    binary must still be verified in P4): `app-sandbox` ✅, app-group
    `group.org.sbarex.qlmarkdown`, `files.user-selected.read-only`, **`network.client`** ⚠️,
    **`temporary-exception.files.absolute-path.read-only = /`** ⚠️ (whole-filesystem read), and
    `temporary-exception.mach-lookup.global-name` for `com.apple.nsurlsessiond` +
    `org.sbarex.qlmarkdown-settings-changed`. The README attributes the mach-lookup exception to a
    Big Sur WebKit bug, but the actual values are the networking daemon and a settings-change
    notification — a second docs-vs-code divergence. **Whole-filesystem read + network client, in
    a component the OS invokes automatically, is what makes #22 consequential.**
27. **Stated ceiling of this phase.** `cmark-extra` contains **5,369 lines of first-party C/C++**
    parsing untrusted input; it was **spot-checked, not comprehensively reviewed**. The vendored
    parsers were not reviewed at all. Memory-safety auditing of C at this scale is beyond
    beginner-level manual review — stated rather than glossed.
28. **⏸️ Parked — upstream disclosure of finding #22.** Deliberately **not** acted on during the
    audit: reporting before the review is complete would be presumptive. To be revisited once a
    final decision is recorded. Complicating factor: the project has **no `SECURITY.md`** and no
    documented reporting channel (finding #1), so the options are GitHub private vulnerability
    reporting (if enabled on the repo) or a public issue. Distinct from the optional, purely
    cosmetic Boost/Lua documentation suggestion (finding #10).

## Dealbreakers encountered (if any)

- **None proven.** Finding #22 (arbitrary local-file read reachable from a merely-previewed
  document) is the candidate. It is established from source, but its impact hinges on an
  unverified question — whether the read data can leave the machine — which Phase 5 must
  settle in isolation. Under *fail closed*, an unresolved **high-impact** question defaults to
  blocked.

## Conditions / restrictions if installing

_(to be written by the reviewer if the decision is "Accept with restrictions" — candidates
surfaced so far, not yet chosen)_

- **Disable Sparkle auto-update and re-audit each version.** Firewall-deny
  `sbarex.github.io`, and/or `defaults write org.sbarex.QLMarkdown SUEnableAutomaticChecks
  -bool NO`. Rationale: keeps every new version inside the intake gate rather than letting an
  approved artifact silently become an unapproved one (finding #12).
- **Consider disabling the Table extension.** Three of five parser advisories are table bugs,
  two critical; upstream's own published workaround for the CVSS 9.8 issue was to disable it
  (findings #18, #21).
- **Keep remote-content features off** (emoji-as-images, web-linked MathJax/Mermaid) so that
  previewing a file generates no network traffic (finding #5).
- **Turn "Inline HTML (unsafe)" OFF.** It ships **on** (finding #23), and it is the switch that
  enables the weak Path B inline-image handler behind finding #22. Highest-value single setting
  change identified in this review.
- **Turn "Validate UTF" ON.** Ships off (finding #23) — cheap hardening in front of a C parser.

## Decision rationale (the "why," in a few sentences)

> ⏳ pending

## Update log (re-audits of later versions)

| Date | New version | What changed (diff summary) | Re-verdict |
|------|-------------|-----------------------------|-----------|
| | | | |
