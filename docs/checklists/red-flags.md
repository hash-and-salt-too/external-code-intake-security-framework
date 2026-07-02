# Red Flags Catalog — Dealbreakers & Warning Signs

A quick-reference watch-list. Read it once so you *recognize* trouble during the audit.

Two tiers:
- 🛑 **Dealbreaker** — on its own, a reason to **reject** (*fail closed*). Don't rationalize it away.
- ⚠️ **Caution** — not fatal alone, but each one lowers trust. Several together, or one plus a dealbreaker-adjacent issue, means **stop**.

> Guiding rule: **anything you can't explain or verify is a finding, not a pass.** Unknown = risk.

---

## 🛑 Dealbreakers

### Installation & delivery
- 🛑 Instructions tell you to pipe a remote script straight into a shell — `curl … | bash`, `curl … | sudo bash`, `wget -O- … | sh` — without reading it first.
- 🛑 You're asked to **disable security** to install: turn off Gatekeeper, disable SIP, "right-click → Open to bypass," approve unsigned kernel/system extensions, or lower security in Recovery.
- 🛑 You're asked to **paste secrets** (passwords, tokens, seed phrases, API keys) or grant admin/root for no clearly justified reason.

### Code & artifact
- 🛑 **Obfuscated code presented as the product** — `base64`/hex blobs that get decoded and executed, packed payloads, or "minified" code where a library wouldn't be. Legitimate open source has no reason to hide.
- 🛑 Code that **downloads and executes** further code at runtime or during build (remote `eval`, fetch-then-run, `dlopen` of downloaded files).
- 🛑 Code that reads **credentials/sensitive files** (`~/.ssh`, Keychain, `~/.aws`, browser logins) without a legitimate, documented reason.
- 🛑 **Hash or signature mismatch** on a downloaded file, or a binary that is **unsigned *and* un-notarized** yet wants to run automatically or with elevated privileges.
- 🛑 Installer **pre/postinstall scripts** that fetch remote code, decode blobs, or silently install background services.
- 🛑 A **backdoor pattern**: hidden hardcoded credentials, a secret command/URL trigger, or logic that behaves differently for a specific hidden input.

### Behavior at runtime
- 🛑 Contacts **unexpected servers** / exfiltrates data, or **spawns unexpected processes** (a previewer launching a shell, interpreter, or network tool).
- 🛑 Installs **persistence** with no functional reason (launch agent/daemon, login item, cron, shell-rc edit) — especially for something that shouldn't run in the background.

### Project & people
- 🛑 **Typosquat / impersonation** — a lookalike name/owner pretending to be the real project.
- 🛑 A **brand-new throwaway account** whose only purpose is to host this binary, with no history and no verifiable identity.
- 🛑 Clear signs of **account/repo compromise**: sudden maintainer swap, out-of-character commits after long silence, rewritten/force-pushed history around a release.

---

## ⚠️ Cautions (weigh together)

### Project health
- ⚠️ Single maintainer / low **bus factor** (one point of failure or compromise).
- ⚠️ **Abandoned** or long-stale — no security fixes coming.
- ⚠️ **Issues disabled**, removing public scrutiny.
- ⚠️ Thin or dishonest **documentation**; claims that don't match the code.
- ⚠️ Popularity that feels **manufactured** (many stars, little real activity or third-party mention).
- ⚠️ You're installing a **fork** and can't articulate why over the original.

### Supply chain
- ⚠️ **Floating** (unpinned) dependency versions; **no lockfile**.
- ⚠️ A **sprawling** dependency tree of unfamiliar packages.
- ⚠️ **Vendored** third-party code that's been **modified** from upstream without explanation.
- ⚠️ Submodules/dependencies pointing at **random personal repos**.
- ⚠️ Build pipeline that pulls in code from outside the pinned dependencies.

### Code & permissions
- ⚠️ **Broad file or network access** beyond what the feature set needs.
- ⚠️ **Undisclosed telemetry**/analytics (privacy issue even if not malware).
- ⚠️ **Entitlements** wider than the function warrants; **sandbox disabled** without explanation; network entitlement on a purely local tool.
- ⚠️ **C/C++ parser handling untrusted input** with no sign of fuzzing/hardening (memory-safety risk) — relevant to Markdown/preview tools.
- ⚠️ Code you simply **can't understand** in a risky area (resolve it or treat as a reason not to install).

### Trust signals
- ⚠️ Signed by a **valid Team ID you can't tie** to the vetted maintainer.
- ⚠️ **No published checksum/signature** to compare against.
- ⚠️ Recent **ownership transfer** of the repo (not necessarily bad — verify).

---

## How to use this list
1. During each phase, note any items that match.
2. **Any 🛑 → reject**, or fully resolve it with solid evidence before continuing.
3. Tally the ⚠️ items. A cluster of cautions is itself a "no," or a "only in strict isolation, built from source."
4. Record what you found in the [report template](../templates/audit-report-template.md) — including the ones that were *clear*, so the decision is defensible later.
