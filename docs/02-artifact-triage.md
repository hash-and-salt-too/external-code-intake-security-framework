# 02 — Triage: Do I Even Need This, and What Will It Cost?

**Start every intake here.** This page routes you in a few minutes. Most intakes should end *on this page*.

It answers two different questions, in this order:

1. **The task question** — *do I actually need this thing?* (usually cheap)
2. **The artifact question** — *is it safe?* (sometimes very expensive)

> ## The one idea on this page
>
> **The 15-minute budget is for the DECISION, not the ANALYSIS.**
>
> You cannot responsibly clear a high-risk artifact in 15 minutes — a measured real
> example took **4 hours 9 minutes**. So the 15 minutes buys you a *decision about what
> to do*, which is often "I don't need this at all." When a full audit genuinely is
> required, it stops being an interruption and becomes **scheduled work**.

---

## The ladder — work down it in order

```
G0  SUBSTITUTION CHECK                      ~60 s
    "Do I already have a trusted tool that does this job?"
    YES -> SUBSTITUTE. One line in the log. STOP.
           No artifact decision needed - it never comes in.

G1  CLASSIFY & FORECAST                     ~3 min
    Cheap observable facts only. NO analysis:
      artifact type (1-8) - install method - privilege at run time
      - does a baseline already exist?  - does an alternative exist?
    OUTPUT: a cost band. Not a verdict.

G2  DISPOSITION                             ~2 min
    Compare the forecast to the time you actually have.
    -> SUBSTITUTE / WORK AROUND / STOP+CLEAR

G3  AUDIT       (only if STOP+CLEAR)        band-dependent
    -> human records Accept / Accept-with-restrictions / Reject / Hold
```

### G0 — Do I already have a trusted tool that does this job?

**Ask this first. Always. Before anything else.**

It is the cheapest question in the framework and it eliminates more work than every
other check combined. Keep a [capability register](../reports/capability-register.md)
so this is a lookup rather than a memory test.

> **The cautionary example.** A Quick Look Markdown previewer was audited over five
> phases and 4h09m, ending in **Reject**. VS Code was already installed and already
> renders Markdown. That answer was available in **30 seconds**. The framework was
> right about the artifact and had nothing to say about the task — which is the gap
> this page now closes.

**For an update to something you already accepted, G0 has a special answer:** *yes — the
version you already cleared.* Staying on a pinned, audited version is a legitimate and
free disposition.

### G1 — Classify and forecast (not "assess risk")

G1 does **not** judge safety. It gathers cheap, observable facts and turns them into a
**cost forecast**, so an expensive audit is visible *before* you start it rather than
three hours in.

Work out four things: the **artifact type** (Step A below), the **install method**, the
**privilege it runs with**, and whether a **baseline** or an **alternative** already
exists. Then read off the band:

| Band | What lands here | Expected cost | Fits the budget? |
|:--:|---|---|:--:|
| **A — Re-verify** | A new version of something already accepted, with a stored baseline | ~10–15 min *(measured: 25 min first time, ~10–12 on a clean repeat)* | ✅ Yes |
| **B — Fast lane** | Type 1 or 5, low privilege, readable, reputable, **no install-time scripts** | ~10 min | ✅ Yes |
| **C — Scheduled audit** | Types 3, 6, 7; or types 2/5 with native code or install scripts | 1–2 h | ❌ Schedule it |
| **D — Expensive** | Type 4; anything the OS invokes automatically on untrusted input; closed-source privileged code | **4 h+** *(measured: 4:09:10)* | ❌ Schedule it — and see below |

> **Band D standing note.** An artifact in this band costs more than a whole day's
> interruption budget. **If any substitute exists, take it.** Rejecting costs you almost
> nothing; auditing costs you hours; a wrong accept costs you unboundedly.

### G2 — Choose the disposition (the task decision)

| Disposition | Meaning | Artifact verdict needed? |
|---|---|:--:|
| **SUBSTITUTE** | Use a tool you already trust that does the same job | **No** |
| **WORK AROUND** | Finish the task without it | **No** |
| **STOP+CLEAR** | Park the task; run the intake as **scheduled work**, at the depth the band demands | **Yes** |

**STOP+CLEAR does not mean "audit it in 15 minutes."** It means the audit stops being an
interruption and becomes its own scheduled task. The 15 minutes was spent *deciding that*.

### 🛑 The fourth path — name it, and rule it out

There is a path people actually take that is **not** on the list above:

> *"I'll install it now and audit it later."*

**That is not a deferral. It is an Accept with no evidence**, taken at the moment of
maximum time pressure and minimum information, and it inverts this framework's core
rule that **the gate is on execution**. Calling it a deferral is the thing that makes it
feel survivable: a deferral leaves the code *outside*; this puts it *inside*.

It is not forbidden — prohibitions get ignored under pressure. It is made **expensive to
record**:

- It is logged as **`Accepted WITHOUT review`**. Never "deferred," "provisional," or "pending."
- It goes in a **standing register at the top of your intake log**, not a buried dated line.
- Each entry records the artifact + version, the date, **the task that forced it**, and a review-by date.
- Entries leave the register only by being audited, uninstalled, or explicitly re-affirmed.
- While that register is non-empty, *"everything I run has been reviewed"* is false — and every entry is a standing lead for any future incident.

The honest reason people take this path is that STOP+CLEAR looks like the only
alternative and it is expensive. That is why **Substitute** and **Work around** are
asked first, and why the forecast comes before the analysis.

---

## Step A — Identify your artifact type *(part of G1)*

The *type* of thing you are bringing in is the single biggest factor in what an audit will cost and which checks matter. Two downloads can both come "from GitHub" and yet need completely different scrutiny. A shell script you can read in five minutes. A compiled app you *can't* read at all. An npm library drags in hundreds of other authors' code. Each has a different **attack surface** — and a very different price tag.

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

**Only if your disposition was STOP+CLEAR.** If you chose Substitute or Work around, you are done — record the one-line result and go back to what you were doing.

- **Band A (a new version of something already accepted)** → go straight to [`05-update-audit.md`](05-update-audit.md). Do **not** run a fresh intake.
- **Band B/C/D** → read [`03-install-methods-explained.md`](03-install-methods-explained.md) to understand *how* you'll obtain it, then begin at [`phases/phase-1-provenance.md`](phases/phase-1-provenance.md).

Record the outcome in [`templates/audit-report-template.md`](templates/audit-report-template.md) — including the **cost of rejecting**, which is an input to the decision, not an afterthought. When a cheap substitute exists, the bar for Accept goes **up**, not down: rejecting costs you almost nothing, while a wrong accept costs you unboundedly.
