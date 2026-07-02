# Phase 2 — Supply Chain

**Question this phase answers:** *What other code does this depend on, and what runs on my machine when it's built or installed?*

When you trust one project, you inherit trust in **everything it pulls in** and **every script that runs during its build/install**. A lot of real-world compromises hide *here* — not in the app's own logic — because people review the app and forget the plumbing.

> Two harm windows live in this phase: **(a)** dependencies you'll run later, and **(b)** build/install scripts that run *right now*, before you ever "use" the software.

---

## 2.1 Find out what it depends on

Look for **manifest files** (the "ingredients list") in the repo. Which one exists tells you the ecosystem:

| File | Ecosystem | 
|------|-----------|
| `package.json` (+ `package-lock.json` / `yarn.lock`) | Node.js / npm |
| `requirements.txt`, `pyproject.toml`, `Pipfile` (+ `.lock`) | Python |
| `Gemfile` (+ `Gemfile.lock`) | Ruby |
| `Cargo.toml` (+ `Cargo.lock`) | Rust |
| `go.mod` / `go.sum` | Go |
| `Package.swift`, `Podfile` (+ `Podfile.lock`), `Cartfile` | Apple (Swift PM / CocoaPods / Carthage) |
| `.gitmodules` | Git submodules (nested repos) |
| `*.xcodeproj` / `*.xcworkspace` build settings | Xcode-linked frameworks |

Checklist:
- [ ] **List the direct dependencies.** Read the manifest. Do you recognize the major ones? Are there only a few (easier to trust) or a sprawling tree (more to trust)?
- [ ] **Look for a lockfile.** A lockfile pins exact versions so they can't silently change. Its presence is a good sign; its absence means "you might get a different (possibly newer, possibly malicious) version than what was reviewed."
- [ ] **Check version pinning.** Are dependencies pinned to specific versions/hashes, or floating (`^`, `~`, `latest`, `*`)? Floating versions are convenient but let code change under you — weaker for trust.

---

## 2.2 Scrutinize each dependency's trust

You don't need to fully audit hundreds of packages, but do triage the tree:

- [ ] **Recognize the big/critical ones.** For the handful your software leans on most, do a mini Phase-1 (are they real, maintained, reputable projects?).
- [ ] **Hunt for oddities.** A dependency pointing at a **random personal repo**, a **fork** instead of the upstream original, a package with a **near-miss name** (typosquatting), or a brand-new package with suspiciously sudden adoption — each deserves a closer look.
- [ ] **Watch the depth.** Deeply nested transitive dependencies are where poisoned packages hide, because nobody reads that far. Tools (Phase note below) can flag known-bad ones.

---

## 2.3 Check *vendored* (bundled-in) third-party code

Some projects copy dependencies **directly into the repo** instead of downloading them. QLMarkdown, for example, bundles the `cmark-gfm` C library (and syntax-highlighting code).

- [ ] **Identify bundled third-party code** (often in folders like `vendor/`, `third_party/`, `External/`, `Sources/…`, or a submodule).
- [ ] **Confirm it matches the trustworthy original.** Is it a known-good version of a well-known library, or has it been **modified**? Unexplained local modifications to a bundled library are a classic place to slip in a backdoor. If it's a submodule, check *where it points* (`.gitmodules`).
- [ ] **Note the language.** Bundled **C/C++** that parses untrusted input (like a Markdown parser) carries memory-safety risk even when it's honest — relevant to Phase 3.

---

## 2.4 Review what runs at **build/install time** (the high-value target)

This is the part people skip. These scripts execute code on *your* machine during build or install — sometimes with elevated privileges — regardless of how clean the app itself looks.

Look for and read:

- [ ] **npm lifecycle scripts** — `scripts` in `package.json`, especially `preinstall`/`postinstall`. These run automatically on `npm install`.
- [ ] **Python install code** — `setup.py` can contain arbitrary code that runs on install; check `pyproject.toml` build hooks too.
- [ ] **Rust build scripts** — `build.rs` runs during `cargo build`.
- [ ] **Makefiles / shell scripts** — `Makefile`, `configure`, `*.sh`, bootstrap/`install.sh`. Read what they actually do.
- [ ] **Xcode "Run Script" build phases** — macOS/Xcode projects can run arbitrary shell during build (visible in the project's Build Phases). Relevant to QLMarkdown.
- [ ] **CI/CD workflows** — `.github/workflows/*.yml`. What does the pipeline build, and does it **download code at build time** from somewhere other than the pinned dependencies?

Red patterns to flag in any of the above:
- Commands that **`curl`/`wget` and then execute** something from the network during build.
- **`base64`/hex blobs** that get decoded and run.
- Writing to locations **outside** the project (your home dir, `~/Library/LaunchAgents`, `/usr/local`, `/Library`).
- **`sudo`** or privilege prompts during build/install.
- Obfuscated or needlessly complex steps that hide what's happening.

---

## 2.5 Check dependencies against known-vulnerability databases

You can do this *reading-only* today; scripts can automate it later when you're ready.

- [ ] Cross-check notable dependencies against **GitHub Security Advisories**, the **OSV** database (osv.dev), and the **NVD**.
- [ ] Note the **tools** that automate this (for later): `npm audit` (Node), `pip-audit` (Python), `bundler-audit` (Ruby), `cargo audit` (Rust), `govulncheck` (Go), and the ecosystem-agnostic **OSV-Scanner**. GitHub's **Dependabot** does this continuously for projects that enable it.
- [ ] Presence of a fixed CVE isn't disqualifying; an **unpatched, known-exploited** vulnerability in a current dependency is a serious finding.

---

## 2.6 Prefer an SBOM if one exists

Some mature projects publish a **Software Bill of Materials** — a machine-readable ingredient list. If present, it makes this whole phase faster and more complete. Its absence is normal for small projects, not a red flag by itself.

---

## Phase 2 outcomes

| Result | Meaning | Next |
|--------|---------|------|
| **Dealbreaker** | Build/install script fetches-and-runs remote code, decodes hidden blobs, or grabs `sudo`; a core dependency is a known-malicious or unpatched-exploited package | **Reject.** |
| **Concerns** | Floating versions, sprawling untrusted tree, modified bundled library you can't explain, no lockfile | Proceed cautiously; pin versions yourself, prefer building from reviewed source, isolate at runtime. |
| **Clean** | Recognizable, pinned dependencies; bundled code matches trusted upstream; build scripts are readable and benign | Continue. |

Record findings, then continue to [`phase-3-source-review.md`](phase-3-source-review.md).
