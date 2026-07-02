# Worked Example — Auditing QLMarkdown

This applies the framework to **QLMarkdown**, a macOS Quick Look extension that renders Markdown file previews. It is written as a **ready-to-run scaffold**: the QLMarkdown-specific steps and exact commands are filled in, with **`‹fill in›` placeholders** for findings you'll record when you actually run the audit.

> **Status: not yet executed.** Nothing here asserts audit *conclusions* about QLMarkdown — it tells you *what to check and how*. Treat every "expected" note as something to **verify against the current release**, not as a finding. Record results in a copy of the [report template](templates/audit-report-template.md).

> **Anti-typosquat reminder:** the project this refers to is **`sbarex/QLMarkdown`** on GitHub. Confirm that exact owner/repo before trusting anything — do not accept a lookalike.

---

## Step 0 — Triage

| Field | Value |
|-------|-------|
| **Artifact type** | **Type 4 — system extension / OS add-on** (Quick Look extension) |
| **Why highest-tier** | It's compiled (not directly readable) **and** runs **automatically** when you preview a file in Finder **and** it **parses untrusted input** (any Markdown file you preview). |
| **Phases required** | **All five**, with special weight on entitlements (P4) and untrusted-input handling (P3/P5). |
| **Install methods available** | (a) **Pre-built** signed/notarized release on the Releases page — verify with P4; (b) **Build from source** with Xcode — review with P2/P3. Confirm both are still offered in the current repo. |
| **Version to pin** | `‹fill in the exact release tag or commit you will audit›` |

Because it runs automatically and processes files you didn't create, a **malicious or malformed Markdown file could trigger a parser bug just by being previewed** — which is why this one earns the full audit.

---

## Phase 1 — Provenance & reputation

Do these in the GitHub web UI on `github.com/sbarex/QLMarkdown`:

- [ ] Confirm owner is **`sbarex`** and there's no lookalike. → `‹fill in›`
- [ ] Commit **history** depth/spread (real, ongoing — not a single dump). → `‹fill in›`
- [ ] **Release** history & changelogs; note whether releases mention **notarization**. → `‹fill in›`
- [ ] **Contributors** / bus factor; **issues** enabled and active. → `‹fill in›`
- [ ] **Maintainer** `sbarex`: account age, other projects, consistent identity. → `‹fill in›`
- [ ] `LICENSE` and `SECURITY.md` present? Docs explain features/permissions? → `‹fill in›`
- [ ] External search: `"QLMarkdown" security/vulnerability/malware`; check **OSV/NVD/GitHub Advisories**. → `‹fill in›`
- [ ] **Pin the version** you'll audit and use everywhere below. → `‹fill in›`

---

## Phase 2 — Supply chain

QLMarkdown is known to **bundle third-party C code** (notably the **`cmark-gfm`** Markdown parser) plus syntax-highlighting support. Verify specifics in your pinned version.

- [ ] Open `.gitmodules` and any `vendor/`/`third_party/`/`Sources/` folders; **list bundled dependencies**. → `‹fill in›`
- [ ] For **`cmark-gfm`** (and any highlight library): confirm it matches a **known-good upstream** version and hasn't been **secretly modified**; note the exact version for CVE lookup. → `‹fill in›`
- [ ] Check **submodule targets** — do they point to the legitimate upstream repos, not random forks? → `‹fill in›`
- [ ] Open the Xcode project and review **Build Phases → Run Script** steps for anything that fetches/executes remote code at build time. → `‹fill in›`
- [ ] Review `.github/workflows/*` (if any) for build-time network fetches beyond pinned deps. → `‹fill in›`
- [ ] Cross-check `cmark-gfm`/highlight versions against **OSV/NVD** for known parser vulnerabilities. → `‹fill in›`

> Bundled **C** that parses untrusted Markdown is the main supply-chain concern here: memory-safety bugs in the parser are directly reachable by any file you preview. Carry this into Phase 3/5.

---

## Phase 3 — Source review *(if building from source, or reading the repo)*

Work from the pinned version locally; don't build/run yet. Run these **searches** (reading, not executing) and read each hit in context:

- [ ] **Network / remote content** — QLMarkdown has features around **images and remote content** in rendered Markdown. Find where it fetches remote resources and whether that's **opt-in/disable-able**:
  - search: `URLSession`, `http`, `dataWithContentsOf`, `loadRemote`, `allowRemote`, `image` → `‹fill in›`
- [ ] **HTML rendering / sanitization** — it converts Markdown to HTML for the preview. Check whether generated **HTML/JS is sanitized/escaped** and whether raw HTML or scripts in a Markdown file can execute in the preview:
  - search: `unsafe`, `raw`, `html`, `script`, `WKWebView`, `loadHTMLString`, `sanitize`, `escape` → `‹fill in›`
- [ ] **Command/process execution** — a previewer shouldn't spawn shells: `Process(`, `NSTask`, `system(`, `popen`, `exec` → `‹fill in›`
- [ ] **Dynamic/remote code** — `dlopen`, `NSClassFromString`, loading downloaded code → `‹fill in›`
- [ ] **Sensitive files / credentials** — `~/.ssh`, `Keychain`, `~/.aws`, browser data, broad home-dir reads → `‹fill in›`
- [ ] **Persistence** — `LaunchAgents`, `launchctl`, login items, shell-rc edits (a QL extension has no reason to do this) → `‹fill in›`
- [ ] **Untrusted-input flow** — trace how the file being previewed reaches `cmark-gfm` and the HTML renderer; note any hardening. → `‹fill in›`
- [ ] If auditing a **fork**, diff against `sbarex/QLMarkdown` and scrutinize every change. → `‹fill in›`

> Key QLMarkdown-specific questions to answer: **Does previewing a Markdown file cause any network request?** (e.g. remote images, tracking pixels) **Can embedded HTML/JS in a `.md` file run in the preview?** **Are the remote-content options off by default?** Record the answers — they define the real attack surface.

---

## Phase 4 — Binary / artifact *(if using the pre-built release)*

Download the notarized release from the official Releases page, then inspect **without installing**. Replace `‹app›` with the actual `.app`/`.appex`/`.dmg` path.

```bash
# Integrity — compare to the project's published SHA-256 (if provided)
shasum -a 256 ‹downloaded-file›

# Quarantine tag (expected on internet downloads)
xattr -l ‹downloaded-file›

# Code signing — validity + who signed it (Team ID)
codesign --verify --deep --strict --verbose=2 ‹app›
codesign -dv --verbose=4 ‹app›

# Notarization / Gatekeeper
spctl -a -vvv ‹app›                 # app
# spctl -a -vvv -t install ‹dmg/pkg›   # if it's an installer
stapler validate ‹app-or-dmg›

# Entitlements — what powers does it request?  (KEY for a previewer)
codesign -d --entitlements :- ‹app›

# Mach-O quick look
otool -L ‹app›/Contents/MacOS/‹binary›
strings -a ‹app›/Contents/MacOS/‹binary› | sort -u | less   # scan for URLs/commands/paths
```

Record:
- [ ] SHA-256 matches published value → `‹fill in›`
- [ ] Signature valid; **Team ID / Authority** = `‹fill in›` — does it match `sbarex`?
- [ ] Notarized & stapled → `‹fill in›`
- [ ] **Entitlements** requested → `‹fill in›`. Sanity-check: does it ask for **network**, and is that justified by the remote-image feature? Is the **App Sandbox** enabled? Anything unrelated to Markdown preview (mic, camera, contacts) = red flag.
- [ ] `strings`/`otool` surface nothing surprising (unexpected URLs, `/bin/sh`, `~/.ssh`) → `‹fill in›`

> Reminder: valid signing + notarization prove **authentic + passed Apple's malware scan**, *not* "safe." Keep going to Phase 5.

---

## Phase 5 — Runtime / sandbox

Because it integrates with Finder/Quick Look, test in a **separate throwaway macOS user account** (no important files, no credentials) or a **macOS VM** with a snapshot.

- [ ] In the isolated environment, turn on monitoring **before** installing:
  - Outbound firewall (**LuLu**/**Little Snitch**) set to **deny by default**.
  - `lsof -i -nP` / `nettop` for connections; `sudo fs_usage -w -f filesys | grep -i qlmarkdown` for file activity; Activity Monitor for spawned processes.
- [ ] Install the pinned version; then check what registered:
  ```bash
  qlmanage -m plugins | grep -i markdown
  ls -la ~/Library/QuickLook /Library/QuickLook
  ```
  → `‹fill in›`
- [ ] Preview **ordinary** Markdown files. Watch: **any outbound network connection?** From where and to where? → `‹fill in›`
- [ ] Preview **hostile/malformed** Markdown: very large files, broken syntax, files with **remote image URLs**, embedded raw HTML/`<script>`, unusual encodings. Watch for **crashes** (parser memory-safety) and **unexpected network fetches**. → `‹fill in›`
- [ ] Check **persistence**: `~/Library/LaunchAgents`, `/Library/Launch*`, login items, shell-rc edits — expect **none** from a previewer. → `‹fill in›`
- [ ] **Uninstall** and verify clean removal (`qlmanage -m plugins` no longer lists it; no leftover launch agents), or revert the VM snapshot. → `‹fill in›`

> The headline runtime questions for QLMarkdown: **Does a plain preview stay fully local (no network)?** **Does a malicious `.md` cause a crash or a network callout?** **Does anything persist?** Your answers here outrank a clean static review.

---

## Decision

Fill in the [report template](templates/audit-report-template.md) summary and decide:

- **✅ Install** — strong provenance; bundled `cmark-gfm`/highlight match trusted upstream with no known-exploited CVEs; validly signed by `sbarex`'s Team ID, notarized; entitlements minimal and explained; runtime stays local (or remote content is off by default) with no persistence.
- **⚠️ Install with restrictions** — e.g. keep a firewall rule denying its network access, disable remote-content/image options, and only run it on a machine without sensitive work credentials.
- **🛑 Reject** — any dealbreaker: modified bundled parser you can't explain, signature/notarization failure, entitlements far beyond function, or runtime exfiltration/persistence.

**Re-audit trigger:** any new QLMarkdown release — re-check `sbarex` ownership, diff the changes, re-verify notarization, and re-confirm no new network/entitlement was added.

---

## Reminders specific to this case
- QLMarkdown's real security-relevant surface is **(1)** the C Markdown parser handling untrusted files and **(2)** any **remote-content/HTML** rendering. Focus your energy there.
- Prefer keeping remote-image/remote-content features **off** unless you need them — *least privilege* for a local previewer.
- If you can't establish trust in the pre-built binary, **building from source** (after Phase 2/3) and running your own build is the safer fallback.
