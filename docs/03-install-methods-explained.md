# 03 — Install Methods Explained (Build from Source vs. Pre-built vs. Package Manager)

You said you weren't sure of the difference between these — this page explains it in plain terms, because **how you obtain software changes which safety checks matter most.** No prior experience needed.

---

## The three common ways to get software from GitHub

Imagine you want a cake.

- **Build from source** = you get the *recipe and raw ingredients* and bake it yourself.
- **Pre-built release** = you get a *finished cake* in a box.
- **Package manager** = you tell an *automated kitchen* "get me that cake," and it fetches the finished cake *plus* every sub-ingredient it needs, automatically.

Each has different trust trade-offs.

---

### Method 1 — Build from source

**What it is:** You download the human-readable **source code** and turn it into a runnable program yourself (this is "compiling" or "building"), usually with a toolchain like Xcode on macOS.

**In plain terms:** You get the recipe and make the cake in your own kitchen.

| Pros (for safety) | Cons |
|-------------------|------|
| You can **read every line** before running it. | Requires installing developer tools (e.g. Xcode) — a hurdle if you're new. |
| No need to trust a mystery binary — *you* produce it. | The **build process itself runs code** (build scripts), which you must also review. |
| You can pin an exact, reviewed version. | Takes more time and effort. |

**Best when:** the software is powerful/risky, you couldn't verify a pre-built binary, or you want maximum transparency.
**Main checks:** Phase 2 (supply chain, incl. build scripts) + Phase 3 (source review).

---

### Method 2 — Pre-built release (a finished binary)

**What it is:** The maintainer already compiled the software and published the finished file on the repo's **Releases** page — often a `.dmg`, `.pkg`, or `.app` on macOS.

**In plain terms:** You get a sealed box with a finished cake. You can't see the individual ingredients anymore.

| Pros | Cons (for safety) |
|------|-------------------|
| Easy — download and run. | You **can't read** what's inside a compiled binary. |
| Usually signed + notarized by the maintainer (on macOS). | You must trust the maintainer, the signature, and the download path. |
| No toolchain needed. | A tampered or malicious binary is much harder to detect than bad source. |

**Best when:** the project is reputable, the binary is properly **signed and notarized**, and you've verified its **hash/signature**.
**Main checks:** Phase 1 (reputation) + Phase 4 (**signing, notarization, entitlements, hash**) + Phase 5 (watch it run). If you can't establish trust, fall back to Method 1.

> **Sealed-box safeguards on macOS:** *code signing* proves who made it, *notarization* means Apple scanned it for known malware, and a published *hash* lets you confirm your copy wasn't swapped in transit. Phase 4 shows exactly how to check each.

---

### Method 3 — Package manager (automated install)

**What it is:** A tool installs the software *and its dependencies* for you: `brew` (Homebrew) for macOS apps/tools, `npm` for Node.js, `pip` for Python, `gem` for Ruby, Swift Package Manager / CocoaPods for Apple projects, etc.

**In plain terms:** The automated kitchen fetches the finished cake **and** every sub-ingredient — often hundreds — with one command.

| Pros | Cons (for safety) |
|------|-------------------|
| Very convenient; handles updates. | Pulls in **many other authors' code** (transitive dependencies) automatically. |
| Popular packages are widely watched. | Some packages **run install-time scripts** the moment you install. |
| Consistent, repeatable installs. | Easy to install a **typosquatted** lookalike by mistake. |

**Best when:** you understand what the package pulls in and you've vetted the top-level package.
**Main checks:** Phase 2 (supply chain — the star here) + Phase 1 on the main package.

> **Homebrew note:** Homebrew "formulae" (build recipes) and "casks" (pre-built apps) are themselves defined in a public repo. `brew` can build from source *or* download a pre-built cask — so it blends Methods 1–3. You can read a formula with `brew cat <name>` and see exactly where it downloads from and what it runs.

---

## Quick decision guide

```
Is a readable, reviewable SOURCE build practical for you?
│
├─ Yes, and the software is high-risk (installer, system extension, runs as admin)
│     → Prefer BUILD FROM SOURCE (Method 1) after reviewing code + build scripts.
│
├─ A pre-built release exists and is properly SIGNED + NOTARIZED, from a reputable project
│     → PRE-BUILT (Method 2) is acceptable — verify signature, notarization, hash, entitlements.
│
└─ It's a library for your own project, or a common CLI tool
      → PACKAGE MANAGER (Method 3) — but audit dependencies and install scripts first.
```

---

## How this applies to QLMarkdown

QLMarkdown (a macOS Quick Look extension, artifact **type 4**) is typically available **both ways**:

- **Pre-built release** — a signed, notarized `.dmg`/app on the project's Releases page. Easiest path; verify with **Phase 4** (signature, notarization, entitlements, hash).
- **Build from source** — the repo can be compiled with Xcode. More effort, but you can review the code and build it yourself; use **Phase 2 + Phase 3**.

Because it's a system extension that runs automatically, either path should still be followed by **Phase 5** (runtime observation in isolation) before you trust it on your main machine. The [worked example](worked-example-qlmarkdown.md) walks through both.

---

## Next step

Read [`04-audit-methodology.md`](04-audit-methodology.md) for how the five phases fit together, then start Phase 1.
