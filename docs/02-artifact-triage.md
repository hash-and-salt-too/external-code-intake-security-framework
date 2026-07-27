# 02 — Artifact Triage: What Am I Actually Downloading?

**Start every audit here.** The *type* of thing you download is the single biggest factor in which checks matter. This page answers your question directly: **yes, the "type of code" matters a great deal**, and here you identify your type and get routed to the right checks.

Two downloads can both come "from GitHub" and yet need completely different scrutiny. A shell script you can read in five minutes. A compiled app you *can't* read at all. An npm library drags in hundreds of other authors' code. Each has a different **attack surface**.

---

## Step A — Identify your artifact type

Find the row that best matches what you're about to bring in. If several apply (e.g. an app that also bundles scripts), use the **most powerful** one.

| # | Artifact type | Examples | Can you read what it does? | Runs with | Signature typically available? |
|---|---------------|----------|----------------------------|-----------|-------------------------------|
| 1 | **Interpreted script** | `.sh`, `.py`, `.js`, `.rb`, `.ps1`, `install.sh` | ✅ Yes — it's text | Your full user privileges, *immediately* | ❌ Rarely |
| 2 | **Source code you build yourself** | Cloning a repo and compiling | ✅ Yes — all of it | Whatever you grant when you run the result | ➖ You are the builder |
| 3 | **Pre-built native app / binary** | `.app`, `.dmg`, `.pkg`, Mach-O CLI tool | ❌ No — it's compiled | Your user account (installer often admin) | ✅ On macOS: expect signing + notarization |
| 4 | **System extension / OS add-on** | Quick Look ext (**QLMarkdown**), Spotlight importer, kernel/system extension, launch agent | ❌ Usually compiled | **Elevated / automatic** — runs when the OS decides | ✅ Expected; entitlements matter a lot |
| 5 | **Package-manager library** | npm, PyPI, RubyGems, Cargo, Go module, Swift PM, CocoaPods | ✅ Source, but often huge + many deps | Inside whatever app you add it to; may run install-time scripts | ➖ Varies; check registry + repo |
| 6 | **Browser extension** | Chrome/Firefox/Safari add-on | ⚠️ Partly (JS, often minified) | Inside your browser; can read pages/cookies per its permissions | ➖ Store review varies |
| 7 | **Editor / IDE extension** | VS Code extension (`.vsix`) | ⚠️ JS/TS, often minified | Your editor's privileges; can run on load, spawn processes | ➖ Marketplace signing varies |
| 8 | **Container image / infra code** | Dockerfile, published image, Terraform, Ansible | ⚠️ Dockerfile yes; base image no | Inside a container (some isolation) or against real infra | ➖ Registry signing varies |

> **QLMarkdown is type 4 (system extension).** It's compiled (you can't read it directly), it runs *automatically* when you preview a file, and it's distributed as a signed, notarized macOS app — so it needs the strictest treatment: provenance, source or binary review, signature/notarization/entitlement checks, and runtime observation.

---

## Step B — Understand your type's attack surface

### Type 1 — Interpreted scripts (shell, Python, JS, Ruby, PowerShell)
- **Good news:** you can *read every line*. Reviewing is possible without special tools.
- **Bad news:** scripts usually run **instantly with your full privileges**, and copy-paste install lines (`curl … | bash`) run code you *never even saw*.
- **Watch for:** `curl … | bash`/`| sh` one-liners, `eval`, `base64 -d | sh`, editing your `~/.zshrc`/`~/.bashrc`, adding launch agents, `sudo` prompts, reaching out to the network.
- **Emphasize:** Phase 3 (source review). **Never** pipe a remote script straight into your shell — download it, *read it*, then decide.

### Type 2 — Source you build yourself
- **Good news:** maximum transparency — you can inspect *everything*.
- **Bad news:** the **build process itself runs code** (Makefiles, `build.rs`, npm `postinstall`, Xcode "Run Script" phases, GitHub Actions). "The app source looks fine" is not enough if the build script is malicious.
- **Emphasize:** Phase 2 (supply chain, including build scripts) + Phase 3 (source review). Then you trust the binary *you* produced.

### Type 3 — Pre-built native app / binary
- **Bad news:** you **cannot read** a compiled binary. Your trust must come from elsewhere.
- **So you lean on:** Phase 1 (reputation), Phase 4 (**signature, notarization, entitlements, hash**), and Phase 5 (watch it run). Installers (`.pkg`) can run scripts as admin — inspect those *before* installing.
- **Emphasize:** Phase 4 heavily. If you can't establish trust in the binary, prefer building from source (type 2).

### Type 4 — System extension / OS add-on (includes QLMarkdown)
- **Highest routine risk** for everyday downloads: compiled, **automatically invoked** by the OS, and often granted broad access.
- Quick Look extensions in particular **process files you merely preview** — so a bug in how they parse a file can be triggered just by selecting a malicious file in Finder.
- **Emphasize:** *All five phases.* Pay special attention to **entitlements** (Phase 4) and to **what happens when it parses untrusted input** (Phase 3), and observe it at runtime (Phase 5).

### Type 5 — Package-manager library (npm/pip/gem/cargo/go/Swift PM/CocoaPods)
- **The dependency-explosion problem:** one small library can pull in **hundreds** of transitive dependencies — each is code you'll run.
- **Install-time code:** npm `postinstall`, Python `setup.py`, etc. can run commands the moment you install — before you use the library at all.
- **Watch for:** typosquatting (near-miss names), a package whose GitHub repo doesn't match its published contents, brand-new or single-maintainer packages with sudden popularity.
- **Emphasize:** Phase 2 (supply chain) heavily, plus Phase 1 on the top-level package and any suspicious dependency.

### Type 6 — Browser extension
- Runs inside your browser and, depending on permissions, can **read every page you visit, your cookies, and your logged-in sessions**.
- **Watch for:** "read and change all your data on all websites," remote code loading, minified/obfuscated content scripts, ownership changes of a once-good extension.
- **Emphasize:** Phase 1 + its **permission list** (the browser equivalent of entitlements) + Phase 3 where source is available.

### Type 7 — Editor / IDE extension (e.g. VS Code)
- Runs with **your editor's privileges**, often **automatically on startup or when you open a project**, and can spawn processes or read your whole workspace.
- **Watch for:** extensions that run code on load, download binaries at runtime, or request broad file/network access; obfuscated bundles.
- **Emphasize:** Phase 1 (publisher reputation, install counts, source availability) + Phase 3.

### Type 8 — Container image / infrastructure code
- A Dockerfile is readable, but the **base image** it builds on usually isn't — and images can carry embedded secrets or backdoors.
- Infra code (Terraform/Ansible) can change **real systems** with broad privileges.
- **Emphasize:** Phase 1 + Phase 2 (base image provenance, pinned digests) + Phase 3 (entrypoint scripts). Run in throwaway environments first.

---

## Step C — Universal minimums (every type, always)

No matter the type, always do these:

1. **Confirm you're at the real project.** Check the exact org/repo name and the URL that sent you there. Beware typosquats and lookalikes. *(Phase 1)*
2. **Pin the exact version** you'll run — a specific release tag or commit — so what you audit is what you get. *(Phase 1/2)*
3. **Check the project's pulse and people.** Real history, active maintenance, identifiable maintainers. *(Phase 1)*
4. **Read the red-flags catalog** once: [`checklists/red-flags.md`](checklists/red-flags.md).
5. **Decide the isolation level for first run** based on risk. *(Phase 5)*

---

## Step D — Which phases apply to you?

| Artifact type | P1 Provenance | P2 Supply chain | P3 Source review | P4 Binary/artifact | P5 Runtime/sandbox |
|---------------|:---:|:---:|:---:|:---:|:---:|
| 1 Interpreted script | ● | ○ | ●● | — | ● |
| 2 Build from source | ● | ●● | ●● | ○ (your output) | ● |
| 3 Pre-built binary | ●● | ○ | — | ●● | ● |
| 4 System extension (**QLMarkdown**) | ●● | ● | ● | ●● | ●● |
| 5 Package library | ● | ●● | ● | — | ○ |
| 6 Browser extension | ●● | ○ | ● | — | ● |
| 7 Editor/IDE extension | ●● | ● | ● | — | ● |
| 8 Container / infra | ● | ●● | ● | ○ | ● |

**Legend:** ●● = primary focus · ● = do it · ○ = light / situational · — = usually not applicable

---

## Next step

Once you know your type and which phases apply, read [`03-install-methods-explained.md`](03-install-methods-explained.md) to understand *how* you'll obtain it (build vs. pre-built vs. package manager), then begin at [`phases/phase-1-provenance.md`](phases/phase-1-provenance.md).
