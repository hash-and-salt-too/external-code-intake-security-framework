# Phase 3 — Source Code Review

**Question this phase answers:** *What does this code actually DO?* Specifically: does it talk to the network, run shell commands, touch sensitive files, hide behavior, or handle untrusted input dangerously?

You don't have to understand every line. You are **hunting for a small set of high-risk behaviors** and checking that each one you find has a legitimate reason to be there.

> **Applies to:** readable source, whether or not your local toolchain can build
> it. A pre-built binary itself needs Phase 4 + Phase 5, but using that artifact
> does not erase useful Phase 3 evidence from the corresponding pinned source.
> If you cannot establish that the binary matches the reviewed source, record
> that gap explicitly and do not treat source findings as proof about the binary.

---

## 3.1 Get the exact code locally

Work from the **pinned version** you chose in Phase 1 — not "latest."

- [ ] Download the specific release/tag/commit (GitHub's "Download ZIP" for a tag, or clone and check out the exact commit).
- [ ] If it's a **fork** or a modified copy, get the **original** too so you can compare (see 3.6).
- [ ] Keep it in a plain folder. **Don't build or run anything yet** — you're only reading.

---

## 3.2 Orient yourself before diving in

Skim to build a mental map — 10 minutes well spent:

- [ ] **Read the README and docs** for what the software *claims* to do. You'll compare claims against what the code actually does.
- [ ] **Find the entry points** — the "front doors" where execution starts (e.g. `main`, an app delegate, a CLI command handler, a Quick Look preview provider). Bad behavior usually branches off from here or from wherever input arrives.
- [ ] **Map the risky surface** — note where the code handles **input from outside** (files it parses, network responses, command-line args). Untrusted input flowing into risky operations is where vulnerabilities live.
- [ ] **Gauge size.** A tiny utility can be read almost in full. A large project can't — so prioritize the risky surfaces above.

---

## 3.3 Hunt for high-risk behaviors (the core of this phase)

For each category below: **search** for the patterns, then **read each hit in context** and ask *"does this feature have a legitimate reason to do this?"* A Markdown previewer opening network sockets deserves an explanation; a network client doing so is expected.

> The searches below are ordinary text/`grep` searches you run on the downloaded folder — reading, not running the code. They make the review *visible*: you see exactly what triggered a hit. (Automating these into a script is easy later, when you want it.)

### A. Network access (exfiltration / phone-home)
Why: this is how stolen data leaves, and how remote commands arrive.
Search for: `http://`, `https://`, `socket`, `URLSession`, `NSURLConnection`, `fetch(`, `XMLHttpRequest`, `requests.`, `urllib`, `curl`, `wget`, `Net::HTTP`, raw IP addresses.
- [ ] List every destination the code contacts. Is each one expected and documented (e.g. a syntax-highlight CDN) — or an unexplained server?
- [ ] Flag any **hardcoded IP addresses** or odd domains, and anything contacting the network in code paths that shouldn't need it.

### B. Running commands / spawning processes
Why: executing shell commands is a direct path to full control.
Search for: `system(`, `exec`, `popen`, `fork`, `subprocess`, `os.system`, `child_process`, `spawn`, `Runtime.exec`, `NSTask`, `Process(` (Swift), backticks in shell/Ruby, `sh -c`.
- [ ] For each hit, check **what** is run and **whether user/file input can influence the command** (command injection). Building a shell string out of untrusted input is a serious finding.

### C. Dynamic / remote code execution
Why: code that builds and runs *new* code at runtime can hide anything and defeat static review.
Search for: `eval(`, `exec(`, `Function(`, `vm.runIn…`, `dlopen`, `dlsym`, `NSClassFromString`, `objc_msgSend` used dynamically, `require(`/`import` of a **remote/computed** path, `pickle.loads`, reflective loading.
- [ ] Treat **any** execution of downloaded or decoded content as a major red flag unless there's a clear, benign reason.

### D. File-system access to sensitive locations
Why: this is how credentials and personal data get stolen.
Search for references to: `~/.ssh`, `id_rsa`, `~/.aws`, `.env`, `Keychain`, `login.keychain`, `~/Library/Cookies`, browser profile paths, `/etc/passwd`, `~/.zshrc`/`~/.bash_profile`, `NSHomeDirectory`, broad `FileManager`/`fopen` walks of your home folder.
- [ ] Does it read or write **outside** the files it legitimately needs? A Markdown previewer should read the Markdown file (and maybe images it references) — not your SSH keys.

### E. Credential & secret access
Why: direct theft target.
Search for: `Keychain`, `SecItemCopyMatching`, `password`, `token`, `api_key`, `secret`, `getenv`/`process.env` reads of sensitive vars.
- [ ] Any access to your Keychain, saved passwords, or secret environment variables needs a compelling, documented reason.

### F. Deserialization of untrusted data
Why: unsafe deserialization can turn data into code execution.
Search for: `pickle`, `yaml.load` (unsafe), `Marshal.load`, `NSKeyedUnarchiver` (non-secure), `ObjectInputStream`, `unserialize`.
- [ ] Flag any deserialization of data that comes from a file or the network.

### G. Persistence mechanisms
Why: how malware survives reboot.
Search for: `LaunchAgents`, `LaunchDaemons`, `launchctl`, `.plist` writes to `~/Library/…`, `crontab`, login items, edits to shell startup files, `SMLoginItem`.
- [ ] A preview extension has **no reason** to install a background service or a login item. Any such code is a strong red flag.

### H. Privilege escalation
Why: bad code wants more power.
Search for: `sudo`, `setuid`, `AuthorizationExecuteWithPrivileges`, `osascript … with administrator privileges`, prompts for admin rights.
- [ ] Does it ask for admin/root? Is that justified by what it does?

### I. Obfuscation & hidden payloads
Why: legitimate open-source code has no reason to hide.
Search for: long `base64`/hex string literals, `base64 -d | sh`, `atob(`, `String.fromCharCode` chains, unexpectedly **minified** code in a project that isn't a web bundle, packed/encoded blobs, gzip'd data decoded then executed.
- [ ] **Obfuscation in code you're auditing is itself a finding.** If you can't tell what a chunk does *because it's deliberately unreadable*, that's a reason to reject — *fail closed.*

### J. Telemetry / analytics
Why: even non-malicious data collection is a privacy consideration.
Search for: analytics SDK names, `track(`, `telemetry`, `analytics`, event-reporting endpoints.
- [ ] Is any data collection **disclosed** and **proportionate**? Undisclosed telemetry is a trust problem even if not "malware."

---

## 3.4 Trace how untrusted input flows (especially for parsers)

For anything that **processes files or data you didn't create** — a Markdown renderer like QLMarkdown is exactly this — the key risk is *malformed input triggering a bug.*

- [ ] Identify where external input enters (the file being previewed, remote content it fetches).
- [ ] Follow it to where it's parsed/processed. In **C/C++** parsers, watch for classic memory-safety bugs (buffer overflows, use-after-free) — these can let a *malicious file* run code just by being previewed.
- [ ] Check whether remote content is fetched while rendering (e.g. images/`<script>`-like features). Rendering untrusted HTML/JS or auto-loading remote resources expands the attack surface — see whether the project sanitizes/escapes output and whether such features can be disabled.

> This is the framework's secure-coding principle **"validate all external input"** applied from the outside: you're checking whether *they* validate the input *you'll* feed them.

---

## 3.5 Read the actual risky code (not just the search hits)

Searches point you to lines; now **read around them**. For the handful of genuinely risky spots:

- [ ] Understand the surrounding function well enough to judge intent.
- [ ] Confirm the behavior matches what the README claims.
- [ ] Note anything you *can't* explain as a finding to resolve (ask the maintainer, search issues) — don't wave it away.

---

## 3.6 If it's a fork or modified copy: diff against the original

The highest-value review for a fork is **what changed** versus the trusted upstream.

- [ ] Compare the fork against the original project (GitHub's compare view, or a local diff of the two folders).
- [ ] Scrutinize **every** difference — especially additions touching network, exec, files, or build scripts. Malicious forks are often 99% legitimate code plus a few poisoned lines.

---

## Phase 3 outcomes

| Result | Meaning | Next |
|--------|---------|------|
| **Dealbreaker** | Executes downloaded/obfuscated code, exfiltrates data, steals credentials, installs persistence, or hides behavior you can't explain | **Reject.** |
| **Concerns** | Broad file/network access without clear need, undisclosed telemetry, risky input handling in a parser, unexplained code | Seek explanations (issues/maintainer); if unresolved, prefer not to install, or restrict heavily and observe in Phase 5. |
| **Clean** | Behaviors all map to documented features; input handling looks careful; no hidden payloads | Continue. |

Record findings, then continue to [`phase-4-binary-artifact.md`](phase-4-binary-artifact.md) (for pre-built files) or [`phase-5-runtime-sandbox.md`](phase-5-runtime-sandbox.md).
