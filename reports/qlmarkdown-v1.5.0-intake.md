# Intake Review — QLMarkdown v1.5.0

> **Status: complete. Decision: REJECT** (2026-09-14).
>
> **Result key:** ✅ pass · ⚠️ concern · 🛑 dealbreaker · ➖ N/A.
> An unknown that can't be resolved is a ⚠️ or 🛑 — never a ✅.

> ### 🔒 Redaction notice
>
> **This is a redacted public version.** One finding — a weakness allowing a previewed
> document to cause unrelated local files to be read and embedded into the preview — is
> described here only at the level of *what it is and what it means*, never *how to do it*.
> The mechanism, the affected code paths, and the reproduction steps are **deliberately
> withheld**.
>
> **This redaction is permanent, not temporary.** This reviewer's personal intake framework is a
> learning project; pursuing vulnerability reports is outside its scope. The weakness therefore
> appears to remain unreported and unfixed, and publishing a working technique against a widely
> used application would be irresponsible — particularly from a repository about careful
> security practice.
>
> Everything that makes this useful as a *worked example* is intact: the method, the phase
> structure, the evidence trail, the decision and its reasoning, and the effort measurements.
> Full unredacted detail is retained privately, outside version control.
>
> **Nothing here should be read as an accusation against QLMarkdown or its maintainer.** See
> the decision rationale — provenance, supply chain, signing and most runtime behaviour were
> all *good*. A separate, non-sensitive hardening suggestion was raised openly upstream as
> [sbarex/QLMarkdown#238](https://github.com/sbarex/QLMarkdown/issues/238).

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
| **Overall risk rating** | **High** — on the untrusted-input path. Two necessary conditions for local-file disclosure were both demonstrated at runtime (#35, #36) in a component the OS invokes automatically. |
| **DECISION** | 🔴 **REJECT** — recorded 2026-09-14, on the criteria pre-committed 2026-09-11 *before* any runtime observation. |
| **Decision made by** (a human — not the AI) | **Repo maintainer (human), 2026-09-14.** The AI gathered, explained and recorded evidence; it made no accept/reject determination. |
| **One-line rationale** | Merely previewing a Markdown file embeds arbitrary user-readable file contents into the preview DOM (#35) **and** JavaScript executes in that same DOM (#36) — the two pre-committed reject conditions — and a safe, zero-cost alternative exists (open Markdown in VS Code), so there is no reason to carry the risk. |
| **Re-audit trigger** | Only if upstream substantively reworks the inline-image handling behind finding #22. **A new version alone is not sufficient** to reopen this. |

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
| Untrusted-input handling (memory safety / sanitization) | 🛑 | **See finding #22 — details redacted.** Contributing context, stated without a recipe: a security-relevant rendering option ships **enabled**, and a hardening option ships **disabled**, so raw document HTML is rendered and input validation is off before content reaches the bundled C parser. `SwiftSoup` is used only as a **DOM parser**, **not** as a sanitizer — no `Cleaner`/`Safelist`/`Whitelist` appears anywhere. The only HTML filtering is GFM's `tagfilter`, a fixed **9-tag blocklist** which by design does not constrain event-handler attributes. |
| Fork diff reviewed (if applicable) | ➖ | Not a fork — `sbarex/QLMarkdown` is the original (Phase 1). |

## Phase 4 — Binary / artifact ⚠️ complete with concerns

**Artifact:** `QLMarkdown.zip` (20.6 MB, published 2026-04-08T16:39:00Z), downloaded over HTTPS
from the official Releases page to `quarantine/`, expanded with `ditto -x -k` (preserves signing
metadata; plain `unzip` can corrupt it). **Never installed, launched, or moved to `/Applications`.**
Bundle contains `QLMarkdown.app` with `Markdown QL Extension.appex` (which embeds
`external-launcher.xpc`), `QLMarkdown Shortcut Extension.appex`, and `Sparkle.framework`
(with `Downloader.xpc` / `Installer.xpc`).

| Check | Result | Evidence / note |
|-------|:------:|-----------------|
| Official HTTPS source | ✅ | `https://github.com/sbarex/QLMarkdown/releases/download/1.5.0/QLMarkdown.zip` — the project's own Releases page, no mirror or re-upload. |
| SHA-256 hash matches published | ✅ | Published `8052e2b389644b5820e964974d87d1a3ae28992d103daedd9a522bedab6b4751`; computed **identical**. Digest is **GitHub-computed server-side** (stronger than a maintainer-pasted string), but still same-origin — it proves *un-tampered in transit*, **not** *benign release*. ℹ️ `xattr` shows `com.apple.provenance` but **no `com.apple.quarantine`**, because the fetch used `curl` rather than a browser — Gatekeeper's first-launch prompt would not fire on this copy. Irrelevant here (nothing launched), but a real-world gotcha. |
| Signature valid & trusted key (if provided) | ➖ | No detached GPG/PGP signature is offered for releases. macOS code signing (below) is the trust mechanism. |
| Code signing valid; Team ID matches maintainer | ⚠️ | `codesign --verify --deep --strict` → **"valid on disk"**, **"satisfies its Designated Requirement"**; nested `.appex` and `external-launcher.xpc` validated. Authority chain: **Developer ID Application: Simone Baldissini (D5VMCLD3ZK)** → Developer ID CA → Apple Root CA. `TeamIdentifier=D5VMCLD3ZK`. **Hardened Runtime enabled** (`flags=0x10000(runtime)`) on the app, the QL extension, and the XPC service. Universal binary (x86_64 + arm64). Signing timestamp **Apr 8, 2026**, consistent with the release date. Built with Xcode 26.4 / macOS 26.4 SDK. ⚠️ **Open:** the certificate identifies **"Simone Baldissini"**, while Phase 1 vetted the GitHub account **`sbarex`**. The CLI banner ("Developed by SBAREX") is suggestive but not proof. **The Team-ID-to-maintainer link is not independently confirmed** — reviewer to check the GitHub profile / sponsors / buymeacoffee page. |
| Notarized / Gatekeeper accepted / stapled | ✅ | `spctl -a -vvv` → **accepted**, `source=Notarized Developer ID`, `origin=Developer ID Application: Simone Baldissini (D5VMCLD3ZK)`. `stapler validate` → ticket **stapled** (validates offline). Consistent with the 1.5.0 release note "Application is now codesigned and notarized!". |
| Entitlements minimal & sensible; sandbox status | ⚠️ | **Shipped entitlements match the source declarations exactly** — only Apple's signing-time `application-identifier` / `team-identifier` are added. **No hidden entitlements.** This establishes source↔binary correspondence *on the entitlement dimension*, and confirms finding #26 against the real artifact rather than only in source. Details: **QL extension** — `app-sandbox` ✅, app-group, `files.user-selected.read-only`, **`network.client`** ⚠️, **`temporary-exception.files.absolute-path.read-only = /`** ⚠️ (whole-filesystem read), mach-lookup for `com.apple.nsurlsessiond` + settings notification. **Main app** — sandboxed, `network.client`, whole-filesystem **read** `/`, plus **`temporary-exception.files.absolute-path.read-write` = `/usr/local/bin`, `/usr/local/bin/qlmarkdown_cli`** ⚠️ (explained by the documented "create CLI symlink" menu action, but that is a `PATH` directory), and mach-lookup for `org.sbarex.QLMarkdown-spki`/`-spks` (Sparkle's installer/status services). **Shortcut extension** — notably looser: **`com.apple.security.cs.allow-jit`** ⚠️ and **`com.apple.security.cs.allow-dyld-environment-variables`** ⚠️ (both Hardened Runtime *relaxations*), plus `assets.movies/music/pictures.read-only` — Movies and Music are hard to justify for a Markdown→HTML converter. **`external-launcher.xpc` — empty entitlements dict, i.e. NOT sandboxed** ⚠️; see finding #30. Nothing requests microphone, camera, contacts, or `get-task-allow`. |
| Mach-O quick look (`otool`/`strings`/`nm`) clean | ✅ | `otool -L` on the QL extension: system frameworks only (Quartz, WebKit, AppKit, Foundation, Swift runtime) plus `/usr/lib/libcurl.4.dylib` (used for `curl_easy_unescape` URL parsing in `inlineimage.c`) and their own `@rpath/libwrapper_highlight.dylib`. No unexpected third-party dylibs. `strings` surfaced **only** the documented endpoints (`cdn.jsdelivr.net` MathJax/Mermaid, `github.githubassets.com` emoji images) — **no `/bin/sh`, no `.ssh`, no keychain, no `osascript`, no `/etc/passwd`**. Directly corroborates Phase 3. |
| `.pkg`/`.dmg` inspected w/o installing; scripts read | ➖ | **Not applicable — and this is a positive.** The release ships as a plain `.zip` containing `QLMarkdown.app`, with **no `.pkg`/`.dmg` installer**, therefore **no pre/postinstall scripts running with elevated rights** — the single most common macOS installer attack vector is absent by construction. |
| *(additional)* Completeness of the audited artifact | 🛑 | **The signed, hashed artifact does not contain all the code it will run.** `find` across the whole bundle returns **zero `.js` files**; neither MathJax nor Mermaid ships inside it. Per the README they are **downloaded at first launch from `cdn.jsdelivr.net`** and cached in `~/Library/Group Containers/group.org.sbarex.qlmarkdown/js`. See finding #29. |

## Phase 5 — Pre-commitment (recorded *before* any runtime observation)

> Recorded **2026-09-11**, before the isolated environment was exercised. Per
> [`../docs/checklists/phase-5-isolation-setup.md`](../docs/checklists/phase-5-isolation-setup.md)
> Part 0: *"Write down, in advance, what result would make you reject. Deciding the threshold
> after you see the data invites rationalising."*

**Environment.** Standard (non-admin) macOS account named **`isolation`** on macOS 15.7.8
(Intel). Monitoring: **Little Snitch 6.4.1** — itself intake-reviewed and accepted
([`little-snitch-v6.4.1-intake.md`](little-snitch-v6.4.1-intake.md)); the installed version
matches the audited version, no self-update drift. A **local HTTP listener on
`127.0.0.1:8000`** is the *primary* exfiltration oracle, because Quick Look extensions execute
inside Apple host processes and outbound-firewall attribution is therefore unreliable.
**Backups verified:** Time Machine and Carbon Copy Cloner both running continuously.

ℹ️ *Noted for completeness:* Little Snitch was installed **from** the `isolation` account, which
required entering administrator credentials inside that session — momentarily bridging the
isolation boundary. No untrusted code was running at the time, so the practical risk is
negligible. Subsequent Little Snitch configuration is to be performed **from the admin account**,
with testing done after fast-user-switching into `isolation`.

**Hypotheses under test** (from Phases 3–4):

1. **#22** — a crafted Markdown file, merely previewed, causes the contents of an unrelated
   user-readable file to be embedded into the preview DOM. *(Mechanism redacted.)*
2. **#24** — unknown whether JavaScript executes in Quick Look's *data-based* preview host;
   Math/Mermaid rendering correctly would imply that it does.
3. **#29 / #33** — MathJax and Mermaid are fetched **unpinned** from `cdn.jsdelivr.net`; unclear
   whether once-and-cached or per-render, and whether the fetch precedes any consent.
4. **#12** — Sparkle should not contact the appcast before the user consents.

**Pre-committed decision thresholds:**

| Observed outcome | Verdict |
|---|---|
| A canary string appears in **any** network request | **REJECT** — exfiltration confirmed |
| Contacts a destination that no phase predicted | **REJECT** |
| Installs a launch agent / daemon / login item, spawns a shell or interpreter, or demands administrator rights | **REJECT** |
| **#22 reproduces AND JavaScript executes in the preview host** | **REJECT** — the full chain is live |
| #22 reproduces, but **no** script execution and **no** egress | **ACCEPT WITH RESTRICTIONS** — "Inline HTML (unsafe)" off, Mermaid off, "Validate UTF" on, auto-update disabled |
| Cannot determine whether JavaScript executes; results ambiguous | **REMAINS HOLD** |
| #22 does not reproduce, no unexpected traffic, no persistence | **ACCEPT** (restrictions still advisable) |

> The load-bearing row is the fourth. It is the pre-commitment that prevents rationalising
> *"it's only a local file read"* after the setup cost has already been paid.

---

## Phase 5 — Runtime / sandbox 🛑 complete — finding #22 CONFIRMED

**Environment.** Standard non-admin account `isolation`, macOS 15.7.8. App installed to
`~/Applications` (never `/Applications`). Local HTTP listener on `127.0.0.1:8000` as the primary
oracle. Little Snitch 6.4.1 in a deny-by-default `Audit` profile. Evidence captured in
`/Users/Shared/phase5-kit/out/`. **Executed 2026-09-12 → 2026-09-14.**

| Check | Result | Evidence / note |
|-------|:------:|-----------------|
| Isolation level used | ✅ | Separate standard (non-admin) macOS account, verified unable to read the main account's home, unable to `sudo`. Canary decoys only — **no real credentials anywhere**. Installed to `~/Applications`. Extension confirmed active: `pluginkit` shows `+ org.sbarex.QLMarkdown.QLExtension(1.5.0)`, and `00-control.md` rendered **formatted**, proving the probes exercised the real code path rather than macOS's fallback text preview. |
| Network behavior (destinations contacted) | ⚠️ | **At first launch:** one Little Snitch alert — *"QLMarkdown wants to connect to **picsum.photos**"*. **Unpredicted by any earlier phase**, but explained on investigation: `examples/test1.md` (bundled) contains `https://picsum.photos/300/200`, loaded into the editor pane on launch. Benign, but see finding #37. **On preview:** `01-remote-image.md` caused **both** a Markdown-syntax image *and* a raw-HTML image to fetch from the listener (`/remote-image-probe.png`, `/remote-html-img.png`) — **merely previewing a file reaches the network with no interaction**. |
| File access (only expected paths) | 🛑 | **See finding #35 — details redacted.** Decoy files containing unique fake "canary" strings, placed where real credentials would live, had their contents embedded into the rendered preview after a single preview action. Three hits across two decoy files; zero plaintext hits, confirming encoded embedding. No real credential existed anywhere in the test account. |
| Process spawning (nothing unexpected) | ✅ | No shells, interpreters or network utilities spawned. `launchctl` diff shows only PID churn in unrelated Apple agents. |
| Behavior with hostile/malformed input | ✅ | `07-malformed.md` (invalid UTF-8, truncated tables, 500-deep nesting, 300-deep blockquotes): **no crash, no hang** — rendered an empty window with a box. `08-large.md` (~2.4 MB): rendered in **under 1 second**, scrollable to the last line, no CPU spin. **No memory-safety symptom observed** — though absence of a crash in one session is weak evidence about a C parser, not proof of safety. |
| Persistence check (launch agents, login items, QL plugins, rc) | ✅ | **Clean.** The only meaningful diff is the creation of `~/Library/Group Containers/group.org.sbarex.qlmarkdown` — expected. **No new launch agents, no launch daemons, no login items, no shell-rc changes.** Remaining diff lines are PID churn and unrelated background activity (Notes, Zoom, Tips). |
| Clean uninstall / snapshot reverted | ⏳ | Deferred until the decision is recorded — the `isolation` account and `quarantine/` are intentionally retained as evidence. |
| *(additional)* **JavaScript execution in the preview host** | 🛑 | **See finding #36.** Probe content previewed by pressing space in Finder demonstrated that **JavaScript executes inside the Quick Look preview**. A `<script>` tag was correctly stripped by the tag filter; other standard HTML constructs that the 9-tag blocklist does not cover were **not** stripped and did execute. This resolves the open question in finding #24. Probe payloads withheld. |
| *(additional)* **CDN-delivered JavaScript** | 🛑 | **See finding #38.** `~/Library/Group Containers/group.org.sbarex.qlmarkdown/js/` **never existed** — before first launch, after first launch, or after previewing Math and Mermaid. Yet the **Mermaid diagram drew** and the **Math rendered as typeset output**, both of which require their JavaScript libraries. Settings confirm `.link` mode (*"Math extension (linked)"*, *"Mermaid diagram (linked)"*). The libraries are therefore fetched **live from `cdn.jsdelivr.net` at render time** — not cached locally at all. |
| *(additional)* **Sparkle auto-update consent** | ✅ | **Finding #12 resolved favourably.** On first launch Sparkle presented *"Check for updates automatically?"* with *"Automatically download and install updates"* **unchecked by default**, and buttons `[Don't Check]` / `[Check Automatically]`. The reviewer chose **Don't Check**. **It asked before checking** — matching the source-level prediction that an absent `SUEnableAutomaticChecks` key produces a consent prompt. No pre-consent contact with the appcast was observed. |

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

22. 🛑 **[REDACTED — see the redaction notice at the top of this report] Local-file disclosure
    reachable from a previewed document.** Source review identified a weakness by which a
    crafted Markdown file, **merely selected in Finder**, can cause the contents of an
    unrelated user-readable file to be read and embedded into the rendered preview. No click
    and no consent are required.

    Two design properties combine to make it reachable, and a feature that ships **enabled by
    default** is what exposes it. The relevant validation exists in the code but does not
    constrain what an attacker controls. **The specific mechanism, affected files, and
    reproduction steps are withheld.**

    Established by reading only at this stage — nothing was executed. Confirmed later at
    runtime; see finding #35.

    **Not established at this stage:** whether the embedded data could be **exfiltrated**.
    That requires JavaScript execution in the preview host plus network egress. The extension
    does hold `com.apple.security.network.client`. → resolved in Phase 5 (#36).
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

**From Phase 4:**

29. 🛑 **The audited artifact is incomplete — executable code arrives after intake.** A `find`
    across the entire signed bundle returns **zero `.js` files**: neither MathJax nor Mermaid
    ships inside it. Both are **fetched from `cdn.jsdelivr.net` at first launch** and cached to
    `~/Library/Group Containers/group.org.sbarex.qlmarkdown/js`, then injected into rendered
    previews. Consequences: (a) the verified hash `8052e2b3…` and the notarization ticket cover
    **only what shipped**, not the JavaScript that will later arrive and execute; (b) no
    integrity pinning (no Subresource Integrity, no bundled reference copy) was observed, so the
    fetched code's trustworthiness rests on jsDelivr and the network path; (c) this happens on a
    **default** install, because `mathExtension` and `mermaidExtension` both default to
    `.link(url: nil)` (finding #23). **This is a direct bypass of the intake gate** — the
    framework's central principle is that a human approves code *before* it executes, and this
    design fetches new code afterwards. Directly compounds finding #24 (JS very likely executes
    in the preview host) and #22 (data present in the preview DOM).
30. ⚠️ **`external-launcher.xpc` runs unsandboxed** — empty entitlements dict, confirmed against
    the shipped binary. This is *by design*: the sandboxed Quick Look extension cannot call
    LaunchServices (the `lsopen` restriction documented in the source), so it delegates to a
    helper that can. Hardened Runtime **is** enabled on it. **Partial retraction of finding
    #25:** its `Info.plist` declares `XPCService.ServiceType = Application`, meaning each host
    gets a private on-demand instance rather than a globally reachable service — so
    `shouldAcceptNewConnection` returning `true` unconditionally is **materially less serious**
    than source review suggested. The remaining concern stands: an **unsandboxed** component
    calls `NSWorkspace.open()` with **no scheme allow-list**, on a URL originating from an
    untrusted document, after a user click.
31. **Positive findings worth recording.** Hash matches exactly; signature valid and strict-deep
    verified; **Hardened Runtime on all components**; notarized *and* stapled; universal binary;
    **shipped entitlements match source declarations with nothing hidden**; `otool`/`strings`
    clean and corroborating Phase 3; and **no `.pkg`/`.dmg` installer at all**, so there are no
    pre/postinstall scripts running with elevated rights — the most common macOS installer
    attack vector is absent by construction.
32. ⚠️ **Team ID ↔ maintainer identity not independently confirmed.** The certificate says
    **Simone Baldissini (D5VMCLD3ZK)**; Phase 1 vetted the GitHub account **`sbarex`**.
    Checked directly: `NSHumanReadableCopyright` in the signed bundle reads only *"Developed by
    SBAREX 2020 - 2026."*; `LICENSE.txt` is the stock GPL-3.0 text with **no copyright-holder
    line**; and `grep -i baldissini` across the whole source tree returns **zero hits**. The
    personal name therefore appears **only on the certificate**. A third-party blog showing both
    names is *not* independent corroboration if its screenshots derive from the same Gatekeeper
    /certificate dialog — that reasoning is circular. What *is* established: Apple verifies legal
    identity before issuing a Developer ID, so `D5VMCLD3ZK` is a real, Apple-verified identity,
    and it signed a bundle whose `org.sbarex.*` namespace matches the GitHub account. Limitation:
    signing only began at 1.5.0, so there is minimal signing history to correlate.
    **➡️ Practical control: anchor on the Team ID, not the name. Record `D5VMCLD3ZK`; treat any
    future change of Team ID as a takeover signal and re-audit.**
33. **Security posture of the CDN-fetched libraries (research supporting finding #29).** The two
    fetched libraries are **not** equivalent risks.
    - **Mermaid — active and recurring, in exactly this use case.** Direct npm advisories:
      `CVE-2026-41159` (config sanitization → CSS injection), `CVE-2026-41150` (Gantt
      infinite-loop DoS), `CVE-2026-41149` (`classDef` → HTML injection), `CVE-2026-41148`
      (`classDefs` → CSS injection) — **all four in May 2026** — plus `CVE-2025-54881`
      (sequence-diagram labels → XSS). More telling is the **downstream pattern**: *SiYuan* —
      **zero-click NTLM hash theft + blind SSRF via Mermaid diagram rendering** (High,
      `CVE-2026-40107`); *Open WebUI* — stored XSS in Mermaid **Markdown preview** (High);
      *Gogs*, *JetBrains YouTrack*, *OneUptime* (High, `securityLevel:"loose"`), *Excalidraw*,
      *GitLab*, *LobeChat*. "Render a Mermaid diagram from untrusted Markdown" is a
      **demonstrated, repeatedly exploited attack surface** — precisely what QLMarkdown does
      automatically on preview. Mitigation credit: QLMarkdown initialises Mermaid with
      `securityLevel: 'strict'` (the setting OneUptime got wrong) — but the 2026 CVEs are bugs
      in Mermaid's **own sanitization**, which strict mode does not reliably prevent.
    - **MathJax — materially lower risk.** Only two direct advisories exist: `CVE-2023-39663`
      (ReDoS, High) and `CVE-2018-1999024` (macro running untrusted JS, Moderate). All others
      are downstream consumers (Jupyter, Typora, GROWI, Wikidata).
    - **Malicious-hijack risk: LOW.** Both projects are reputable and responsive (publishing and
      fixing CVEs promptly is a positive signal); jsDelivr is a major CDN with no known
      compromise. But the risk class is not theoretical — **polyfill.io (2024)**, a widely used
      CDN-hosted JS endpoint, changed ownership and served malware to 100k+ sites.
    - **The unpinned URL cuts both ways.** `cdn.jsdelivr.net/npm/mathjax/…` and
      `…/npm/mermaid/…` carry **no `@version`**, so they resolve to *latest at fetch time*.
      **For:** fixes arrive automatically, which matters because QLMarkdown ships ~2 releases a
      year and pinning to April 2026 would freeze a Mermaid carrying four known May-2026 CVEs.
      **Against:** what will run cannot be audited in advance, and a hijack propagates
      automatically. **Complication:** the README says the library is fetched **once and cached**
      (manually refreshed from a menu), which would deliver *neither* benefit — frozen at
      whatever was latest on first launch, with no automatic fixes. ⏳ **P5 must determine which
      behaviour is real.**
    - 🔗 **Synthesis — this is the missing link in finding #22.** #22 places unrelated local file
      content into the preview DOM; exfiltrating it would additionally require script execution,
      and a Mermaid injection bug is a documented, recurring route to exactly that, in a renderer
      enabled **by default**. Every link in that chain is a separately documented weakness.
      **The chain was NOT demonstrated and is not claimed to work** — composing it would be
      exploit development, not intake review. It is, however, coherent, and it was the strongest
      single argument for the Hold that preceded the final decision. *(Payload redacted.)*
34. **⏸️ Parked — second disclosure candidate: unpinned CDN JavaScript with no Subresource
    Integrity.** Distinct from #22. A constructive upstream issue would ask for (a) a pinned
    `@version` in the jsDelivr URLs, and/or (b) an SRI hash, and/or (c) shipping the libraries
    in the bundle. To be considered alongside #28 once the audit concludes.

**From Phase 5:**

35. 🛑 **[REDACTED] Finding #22 CONFIRMED at runtime.** Predicted from source in Phase 3,
    demonstrated in Phase 5 inside the isolated account. Decoy files containing unique,
    deliberately fake "canary" strings were placed where a real credential would live. After a
    single preview action, the rendered output contained those decoy contents in encoded form —
    **three separate hits across two different decoy files**, with zero plaintext hits,
    confirming the data was embedded rather than merely referenced.

    **Broader than predicted.** Source review expected one of two code paths to be protected.
    **Neither was, in practice** — both variants embedded the decoy. The protection that exists
    at one layer is bypassed by processing that happens at a later layer.

    **Extension behaviour.** A `log show` query across the probe window found **zero** rejection
    messages, while subsystem activity confirmed the extension was running and logging. The
    extension did **not** refuse the files.

    *Precision note: the decoy hits were captured via a bundled command-line tool that shares the
    rendering engine; the absence of rejection logging and the rendering behaviour are the
    extension-side evidence. The two are consistent but were not demonstrated in a single
    process.*

    **Mechanism, payload and file references withheld** — see the redaction notice.
36. 🛑 **[REDACTED] JavaScript DOES execute in the Quick Look preview — finding #24 resolved.**
    Probe content previewed by pressing space in Finder caused outbound requests to a local
    listener, proving script execution inside the preview. A `<script>` tag **was** correctly
    stripped by the tag filter; other standard HTML constructs outside its fixed 9-tag blocklist
    were not, and executed. **Conclusion: the tag filter blocks `<script>` and is not a general
    defence.** This was the open question that gated the whole review. Probe payloads withheld.
37. ⚠️ **An unpredicted network destination appeared — and it exposes a method gap.** First launch
    contacted **`picsum.photos`**, which no earlier phase predicted. It is explicable and benign:
    the bundled `examples/test1.md` contains `https://picsum.photos/300/200`, loaded into the
    editor pane on launch. **But the Phase 3 network sweep should have caught it and didn't** —
    that sweep covered `.swift`/`.c`/`.cpp` source only, never **bundled content assets**. A real
    endpoint was missed by a method that looked thorough. Any future script must sweep shipped
    resources (`.md`, `.html`, `.css`, `.json`) as well as code.
38. 🛑 **CDN JavaScript is fetched live at render time — finding #29 confirmed and escalated.**
    The cache directory `Group Containers/group.org.sbarex.qlmarkdown/js/` **never existed** at
    any point: not before launch, not after launch, not after previewing Math and Mermaid files.
    Yet the Mermaid diagram **drew** and the Math **rendered as typeset output** — both impossible
    without their libraries. Settings confirm `.link` mode. Therefore the libraries are pulled
    **from `cdn.jsdelivr.net` on demand, every time**, rather than downloaded once and cached as
    the README describes. Combined with #36, this means: **previewing a Markdown file fetches
    unpinned third-party JavaScript over the network and executes it inside the preview.** No
    Subresource Integrity, no version pin, no local copy to audit.
39. ✅ **Genuinely reassuring Phase 5 results, recorded for balance.** **Persistence is clean** —
    no launch agents, no daemons, no login items, no shell-rc modification; the only durable
    change is the expected group container. **No process spawning.** **Malformed input** (invalid
    UTF-8, truncated tables, 500-deep nesting) caused **no crash or hang**. **A 2.4 MB file**
    rendered in under a second. **Sparkle asked for consent** before checking for updates, with
    auto-install unchecked by default (#12 resolved favourably). The software is not badly built;
    it has a specific, serious design flaw.
40. **The chain was deliberately NOT composed.** Both halves are now proven independently —
    arbitrary file content reaches the preview DOM (#35), and JavaScript executes in that DOM
    (#36). **No probe attempted to combine them**, and **no canary string ever appeared in a
    listener request**, so actual exfiltration was *not* observed. That was a deliberate choice:
    [`../docs/checklists/phase-5-isolation-setup.md`](../docs/checklists/phase-5-isolation-setup.md)
    Part 7 states *"Do not write proof-of-concept exploits… you are doing intake review, not
    exploit development."* Composing the two would be writing a working exploit. **The reviewer
    should weigh proven-necessary-conditions against unproven-composition when deciding.**

## Dealbreakers encountered (if any)

- 🛑 **Local-file disclosure into the preview DOM, triggered by selecting a file in Finder**
  (#22 → confirmed as #35), **combined with JavaScript execution in that same DOM** (#24 →
  confirmed as #36). Both were pre-committed as reject conditions on 2026-09-11, before any
  runtime observation, and both were demonstrated on 2026-09-14. *Mechanism redacted.*
- 🛑 **Unpinned third-party JavaScript fetched from a CDN at render time and executed in the
  preview** (#29 → confirmed as #38), with no Subresource Integrity and no local copy to audit.
  Independently sufficient to fail the "the artifact contains the code it runs" expectation.
  *Not redacted — raised openly upstream as
  [sbarex/QLMarkdown#238](https://github.com/sbarex/QLMarkdown/issues/238).*

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
- **Disable the Mermaid extension.** Highest-risk renderer by evidence (finding #33): five direct
  CVEs, four of them in a single month, plus a documented zero-click exploit pattern in products
  doing the same job. Disabling it removes both that renderer **and** one unpinned CDN fetch, at
  modest functional cost. Consider disabling **Math** too if MathJax rendering isn't needed —
  that would eliminate CDN-delivered JavaScript entirely (finding #29).
- **Record `D5VMCLD3ZK` as the identity anchor** and treat any Team ID change as a takeover
  signal requiring re-audit (finding #32).

## Decision rationale (the "why," in a few sentences)

> **REJECT.** Two conditions were written down on 2026-09-11 as automatic reject criteria,
> deliberately *before* the software was ever run, so the outcome could not be rationalised after
> the setup cost had been paid. Both were then met: arbitrary user-readable files are embedded
> into the preview DOM by merely selecting a file in Finder (#35), and JavaScript executes in
> that DOM (#36). A third, independently serious issue was also confirmed — unpinned third-party
> JavaScript pulled from a CDN at render time and executed in the preview (#38).
>
> **The reviewer explicitly acknowledged less than 100% certainty.** The two halves of the chain
> were proven separately and never composed into a working exploit, because composing them would
> be exploit development rather than intake review (#40). Under *fail closed*, proven necessary
> conditions plus an undemonstrated final step still fails — the framework does not require a
> working exploit before declining to run something.
>
> **The decisive practical factor: the alternative is free.** Markdown files open perfectly well
> in VS Code. When a safe substitute costs nothing, there is no reason to carry a High-rated risk
> on the untrusted-input path of an OS component that runs automatically. Rejection here is
> cheap; that asymmetry should be weighed explicitly in every intake decision.
>
> **This is not a judgement that QLMarkdown is malicious, or poorly made.** Provenance is strong
> (Phase 1), the supply chain is well pinned (Phase 2), the binary is properly signed, notarized
> and stapled with entitlements matching its source (Phase 4), and runtime behaviour showed no
> persistence, no process spawning, no crash on hostile input, and correct consent-seeking before
> update checks (Phase 5). It has one specific, serious design flaw in how it handles images
> referenced by untrusted documents.

## Update log (re-audits of later versions)

| Date | New version | What changed (diff summary) | Re-verdict |
|------|-------------|-----------------------------|-----------|
| | | | |
