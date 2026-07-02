# 01 — Threat Model & Principles

Before checking *how* to audit, get clear on *what you're defending against*. A focused audit beats a scattered one.

---

## 1. What are you actually deciding?

Every time you download and run code from GitHub, you make a **trust decision**. You are granting the code — and everyone behind it — the ability to act on your computer with your privileges.

You are not just trusting the friendly project author. You are trusting **the entire chain**:

```
   The maintainer(s)          ← could be careless, or their account could be hijacked
        │
   Their dependencies         ← dozens–hundreds of other authors' code
        │
   Their build/release system ← GitHub Actions, signing keys, release pipeline
        │
   The delivery path          ← the download link, mirrors, your network
        │
   ►  YOUR MACHINE
```

A weakness in **any** link can hurt you, even if the main author is completely honest. This is why the audit looks beyond "is the author nice?"

---

## 2. Who might attack you, and why

You don't need to be a specific target. Most attacks are opportunistic. Realistic attacker types:

| Attacker | Typical goal |
|----------|--------------|
| **Malware author** distributing trojanized tools | Steal credentials, install ransomware, mine cryptocurrency, build a botnet |
| **Supply-chain attacker** who poisons a popular dependency | Reach *everyone* who uses a widely-trusted package |
| **Account hijacker** who takes over a real maintainer's GitHub or signing key | Ship malware under a trusted name |
| **Typosquatter** publishing lookalike projects | Catch people who mistype or grab the first search result |
| **"Protestware" / sabotage** author | Deliberately break or wipe machines based on location, date, etc. |
| **Nation-state / targeted** (rare for most people) | Long-term, stealthy access to a specific person or org |

For most individuals, the first four are the realistic threats — and this framework is tuned to catch them.

---

## 3. What are you protecting? (Your assets)

Name what you'd hate to lose. This tells you how much effort an audit is worth.

- **Your files** — documents, photos, source code, anything irreplaceable.
- **Your credentials** — passwords, SSH keys (`~/.ssh`), cloud keys (`~/.aws`), API tokens, browser-saved logins, your macOS Keychain.
- **Your accounts** — email, bank, GitHub, cloud — anything reachable from your machine or its saved sessions.
- **Your computing resources** — CPU/GPU (cryptomining), network (proxying attacks), storage.
- **Your machine's trust position** — access to your employer's VPN, internal systems, or other devices on your network.
- **Your time and peace of mind** — cleanup after an incident is expensive.

> If the software will run on a machine that also holds work credentials or access to sensitive systems, raise your audit to the strictest tier — and strongly prefer testing in isolation first.

---

## 4. How malicious downloads typically hurt you

Knowing the common "payloads" tells you what to look for in the source-review and runtime phases:

- **Data theft / exfiltration** — reads your files or credentials and sends them over the network.
- **Persistence / backdoor** — installs a hidden background service so the attacker keeps access after reboot.
- **Credential harvesting** — targets `~/.ssh`, `~/.aws`, Keychain, browser profiles, environment variables.
- **Command-and-control** — "phones home" to an attacker server and runs whatever it's told.
- **Destructive payloads** — ransomware (encrypts your files) or wipers.
- **Cryptojacking** — quietly uses your CPU/GPU to mine cryptocurrency.
- **Supply-chain pivot** — uses your machine as a stepping stone into systems you can reach.
- **Malicious build steps** — the harm happens *while you build/install*, before you ever "run" the app (e.g. a poisoned `postinstall` script or Makefile).

---

## 5. The core principles, applied to downloading

These are the same secure-engineering principles used to *write* safe code, re-pointed to *consuming* code safely. They justify every check in the phases.

### Assume breach
Plan as though the thing you're about to run **could** be malicious. Structure your test so that if it *is* bad, it can't reach your real data. Concretely: prefer a throwaway account or VM for first runs; keep backups.

### Least privilege
Give code the **minimum** power it needs. A Markdown previewer never needs your SSH keys or microphone. During testing, deny by default and grant only what's clearly required.

### Defense in depth
Never trust a single signal. "It has 5,000 stars" is *not* an audit. Stack independent checks — reputation **and** source review **and** signature **and** runtime observation — so one bad signal is caught by another.

### Zero trust (verify every time)
Trust is not permanent. Re-verify on **every update**, because a safe project can be hijacked or can turn malicious later. Pin the exact version you audited so it can't change under you silently.

### Fail closed
When you can't verify something, the default answer is **no**. Missing signature, unreadable obfuscated code, a dependency you can't identify, a question you can't answer — each is a reason to stop, not to "try it and see."

### Validate at the boundary
The download is your trust boundary. Inspect it *there*, before it's on your real system — not after you've already run it.

---

## 6. Risk calibration — how much audit is enough?

You will not run all five phases for every download. Scale effort to risk. Risk rises with **power**, **obscurity**, and **inspect-ability**.

| Factor | Lower risk | Higher risk |
|--------|-----------|-------------|
| **Privilege it runs with** | Sandboxed, read-only, test project | Your full user account; admin/root; system extension |
| **Autonomy** | You launch it manually, occasionally | Runs automatically / in the background / on every file preview |
| **Inspect-ability** | Readable source you can review | Pre-built binary you can't read |
| **Popularity & track record** | Widely used for years, many maintainers | Brand-new, obscure, single author |
| **Origin** | The original, well-known project | A fork, mirror, or lookalike |
| **What it can reach** | An isolated test box | Your main machine with work/personal credentials |

**Rule of thumb:**
- **Low risk** → Quick Triage (Phase 1 highlights) may be enough.
- **Medium risk** → Quick Triage + source review (Phase 3) + supply chain (Phase 2).
- **High risk** (installers, system extensions, anything running with real privileges — **QLMarkdown lives here**) → all five phases + a written decision.

---

## 7. What a "pass" does and doesn't mean

- A clean audit means: *"I found no evidence of malice, the project shows strong trust signals, and I've limited what it can do."* That meaningfully reduces risk.
- It does **not** mean: *"This is proven safe."* Skilled attackers can hide. Treat every install as a revocable decision: keep backups, keep monitoring, and be ready to remove it.

Next: [`02-artifact-triage.md`](02-artifact-triage.md) — identify what you're downloading so you run the *right* checks.
