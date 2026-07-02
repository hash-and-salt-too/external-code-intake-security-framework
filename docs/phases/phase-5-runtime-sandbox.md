# Phase 5 — Runtime / Sandbox Testing

**Question this phase answers:** *When this actually runs, how does it behave — and can I watch it somewhere it can't hurt me?*

Static review (Phases 3–4) can miss things: obfuscation, compiled dependencies you couldn't read, behavior that only triggers at runtime. This phase is your safety net — **observe the software in isolation before trusting it on your real machine.** *Assume breach; contain the blast radius.*

---

## 5.1 Choose an isolation level (least privilege for first run)

Match isolation to the risk you assessed during triage. From strongest to lightest:

| Isolation | What it is | Best for |
|-----------|-----------|----------|
| **Separate physical machine** | A spare Mac you don't care about | Highest-risk or untrusted software |
| **Virtual machine (VM)** | A macOS/Linux guest via UTM, VMware Fusion, Parallels — a computer-inside-your-computer | Strong default when practical; snapshot before, revert after |
| **Separate macOS user account** | A fresh standard (non-admin) account with **no** access to your real files/keys | Practical for macOS-integrated things like Quick Look extensions that are awkward to test in a VM |
| **Built-in sandbox** | Running the app under its own App Sandbox (if it uses one) | A baseline layer, not a substitute for the above |

- [ ] Pick the **strongest option that's practical** for your artifact type.
- [ ] Whatever you choose, **back up your real data first** and don't have sensitive credentials present in the test environment.

> **QLMarkdown note:** Quick Look extensions integrate with Finder, so a **separate standard user account** (or a macOS VM) is the realistic way to observe one safely. Create a throwaway account with no important files, install there, and preview *test* Markdown files — including deliberately odd/malformed ones — while monitoring (below).

---

## 5.2 Set up monitoring *before* you run it

You want to *see* what it does the moment it runs. Turn on observation first.

**Network (is it phoning home / exfiltrating?)**
- [ ] Use an outbound application firewall that prompts on new connections — **Little Snitch** or the free **LuLu** — set to **deny by default**, so *you* approve each connection and see where it wants to go.
- [ ] Spot-check live connections:
  ```
  lsof -i -nP            # open network connections by process
  nettop                 # live per-process network activity
  ```
- [ ] Compare what it contacts against what Phase 3/4 led you to expect. **Unexpected destinations are a major finding.**

**Files (is it reading/writing where it shouldn't?)**
- [ ] Watch file activity while it runs (this is verbose; filter to the process):
  ```
  sudo fs_usage -w -f filesys | grep -i <process-name>
  ```
- [ ] Confirm it touches only what it should (e.g. the file you previewed and its referenced images) — **not** `~/.ssh`, Keychain, browser data, or `~/.aws`.

**Processes (does it spawn anything unexpected?)**
- [ ] Watch **Activity Monitor** and/or:
  ```
  ps -axo pid,ppid,user,command   # look for child processes it launches
  ```
- [ ] A previewer spawning a shell, an interpreter, or a network tool is a serious red flag.

---

## 5.3 Exercise it deliberately

- [ ] Use it the normal way (for QLMarkdown: preview ordinary Markdown files).
- [ ] Then feed it **hostile input** to test robustness: unusually large files, malformed/garbage content, files with embedded remote-image links or scripts. Watch for crashes (possible memory-safety bugs) and unexpected network fetches.
- [ ] Note anything that doesn't match the documented feature set.

---

## 5.4 Check for persistence after install

Malware wants to survive reboots. After installing in your isolated environment, look for footholds it may have created:

- [ ] **Launch agents/daemons:**
  ```
  ls -la ~/Library/LaunchAgents /Library/LaunchAgents /Library/LaunchDaemons
  ```
  A simple previewer should **not** install a background service.
- [ ] **Login items** — System Settings → General → Login Items, or:
  ```
  osascript -e 'tell application "System Events" to get the name of every login item'
  ```
- [ ] **Quick Look plugins present** (expected location for this artifact type):
  ```
  ls -la ~/Library/QuickLook /Library/QuickLook
  qlmanage -m plugins        # list registered Quick Look generators
  ```
  Confirm what got registered is only what you installed.
- [ ] **Shell startup edits** — check whether `~/.zshrc`, `~/.zprofile`, `~/.bash_profile` were modified.

---

## 5.5 Decide, then clean up

- [ ] Summarize runtime behavior in your report: what it contacted, what it touched, what it spawned, what persisted.
- [ ] If anything contradicts the earlier phases or your expectations, **that outranks a clean static review** — trust observed behavior.
- [ ] **Uninstall from the test environment and verify removal** (no leftover launch agents, login items, or plugins). If you used a VM snapshot, revert it.

---

## 5.6 Only then, promote to your real machine (if approved)

If — and only if — all phases support it:

- [ ] Install the **exact version you audited** (not a re-download of "latest").
- [ ] Keep **least privilege** in mind: don't grant permissions it doesn't need; keep the outbound firewall active for a while.
- [ ] **Pin the version** and plan to re-audit on updates (see the methodology's "Handling updates").

---

## Phase 5 outcomes

| Result | Meaning | Next |
|--------|---------|------|
| **Dealbreaker** | Contacts unexpected servers, reads credentials/sensitive files, spawns unexpected processes, or installs persistence | **Reject** and remove; revert the environment. |
| **Concerns** | Minor unexplained behavior, more network chatter than expected | Investigate; resolve or restrict before any real-machine use. |
| **Clean** | Behavior matches documented function; touches only what it should; no surprise persistence | Proceed to the final decision. |

Record findings, then complete the [report template](../templates/audit-report-template.md) and make your go/no-go.
