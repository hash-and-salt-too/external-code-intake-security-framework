# Phase 5 Isolation Setup — Printable Checklist

*Preparing a safe place to run external code for the first time, on macOS.*

Use this **before** [`../phases/phase-5-runtime-sandbox.md`](../phases/phase-5-runtime-sandbox.md).
It covers the setup only — creating the isolated environment, proving it is actually isolated,
and arming your monitoring. The observations themselves belong in the phase doc and your report.

> **Why a separate user account?** Quick Look extensions, Spotlight importers and similar
> OS add-ons integrate with Finder, which makes them awkward to exercise inside a VM. Phase 5
> names a **separate standard (non-admin) account** as the realistic option for this artifact
> type. A VM is stronger — mainly because it can snapshot and revert — but costs more setup.

---

## Be honest about what this contains

**A standard test account DOES contain:**

- Reads of your main account's `~/Documents`, `~/Desktop`, `~/Downloads` (mode `700`).
- Writes to `/Applications`, `/Library`, `/Library/LaunchDaemons` — all need admin.
- System-wide persistence and login items.
- Access to your Keychain, iCloud, and work credentials.

**It does NOT contain:**

- Reads of anything world-readable — `/etc`, `/Library`, `/Applications`.
- **Network egress** — arm a firewall and a local listener (Part 3).
- Persistence in the test user's *own* `~/Library/LaunchAgents`.
- Anything exploiting a kernel or OS-level flaw.

**Do not treat this as a malware detonation chamber.** It is a blast-radius reducer for
software you have already reviewed statically and believe is *probably* fine.

---

## Part 0 — Before you start

- [ ] Confirm you actually want to run this. **Hold is a legitimate resting place** — under
      *fail closed*, an unfinished review blocks use just as effectively as a rejection. If
      setup cost outweighs your need for the software, "Reject — didn't clear intake" is a
      respectable outcome.
- [ ] Back up your real data (Time Machine or equivalent) and verify the backup completed.
- [ ] Re-read your Phase 3/4 findings so you know **what behaviour you are looking for**.
      Testing without a hypothesis wastes the setup.
- [ ] Write down, in advance, what result would make you **reject**. Deciding the threshold
      after you see the data invites rationalising.

---

## Part 1 — Create the test account

- [ ] System Settings → Users & Groups → **Add Account…**
- [ ] Account type: **Standard** — *not* Administrator. This is the whole point.
- [ ] Name it obviously, e.g. `audit-sandbox`.
- [ ] Use a password you do not use anywhere else.
- [ ] **Do not** sign in to iCloud or any Apple Account when the setup assistant offers.
- [ ] Skip Siri, Analytics sharing, and Screen Time.
- [ ] Do not add any real credentials, tokens, SSH keys, or work files.

---

## Part 2 — Prove the isolation (do not skip)

Assumptions about permissions are exactly where this goes wrong. **Verify.**

Log in to the test account and run each of these. You want *failures*:

```bash
ls /Users/<your-main-username>/Documents     # expect: Permission denied
ls /Users/<your-main-username>/Desktop       # expect: Permission denied
ls /Users/<your-main-username>/.ssh          # expect: Permission denied
sudo -n true                                 # expect: refusal — standard user
```

- [ ] All four behave as expected. If any succeeds, **stop and fix permissions** before going on.
- [ ] Note what *is* readable — `/etc`, `/Library`, `/Applications` and anything world-readable
      remain in scope. That is expected, and it is why decoys matter (Part 4).

---

## Part 3 — Arm monitoring *before* installing anything

### 3a. Local HTTP listener — the decisive test

This proves or disproves exfiltration **without letting anything leave the machine**, and it
avoids the process-attribution problem below. In the test account:

```bash
mkdir -p ~/probe && cd ~/probe
python3 -m http.server 8000
```

- [ ] Listener running; leave this window visible. Every request is logged with its full path.

> **Gotcha worth knowing:** Quick Look extensions run inside **system-provided host processes**.
> An outbound firewall may attribute the connection to `QuickLookUIService` or similar rather
> than to the app you are testing — which makes traffic attribution genuinely confusing. The
> local listener sidesteps this completely.

### 3b. Outbound firewall

- [ ] **Little Snitch** or the free **LuLu**, set to **deny by default / alert on every new
      connection**, so you approve each one and see the destination.
- [ ] Confirm it is actually running *before* you install the software under review.

### 3c. Unified log stream

Many apps log more than they realise. Filter to the vendor's subsystem:

```bash
log stream --predicate 'subsystem CONTAINS "<vendor-string>"' --info --debug
```

- [ ] Running in its own window. *(For QLMarkdown use `sbarex` — its inline-image extension logs
      an explicit `"… is not an image!"` rejection message, which is a direct oracle for whether
      a MIME guard accepted or rejected your probe file.)*

### 3d. File activity (optional — needs admin)

`fs_usage` requires `sudo`, which a standard user cannot do. Either:

- [ ] Run it from your **admin session** while fast-user-switched into the test account
      (`fs_usage` is system-wide):
      ```bash
      sudo fs_usage -w -f filesys | grep -i <process-name>
      ```
- [ ] …**or** skip it and rely on the canary + log stream. Record which you chose.

---

## Part 4 — Plant decoys, never real secrets

The point is to detect a read, not to risk one.

```bash
mkdir -p ~/.ssh ~/.aws
echo 'CANARY-AUDIT-7F3A-NOT-A-REAL-KEY' > ~/.ssh/id_rsa
echo 'CANARY-AUDIT-9B2C-NOT-REAL-CREDS' > ~/.aws/credentials
chmod 600 ~/.ssh/id_rsa ~/.aws/credentials
```

- [ ] Decoys created, each containing a **unique, greppable** canary string.
- [ ] Canary strings written down — you will search rendered output and captured requests for them.
- [ ] Confirmed: **no real key, token, or credential exists anywhere in this account.**

---

## Part 5 — Baseline the environment

Capture the "before" so you can diff the "after". In the test account:

```bash
mkdir -p ~/baseline && cd ~/baseline
ls -la ~/Library/LaunchAgents /Library/LaunchAgents /Library/LaunchDaemons > launchagents.txt 2>&1
osascript -e 'tell application "System Events" to get the name of every login item' > loginitems.txt 2>&1
qlmanage -m plugins > qlplugins.txt 2>&1
ls -la ~/Library/QuickLook /Library/QuickLook > qldirs.txt 2>&1
shasum ~/.zshrc ~/.zprofile ~/.bash_profile > shellrc.txt 2>&1
launchctl list > launchctl.txt 2>&1
```

- [ ] Baseline captured. You will re-run these after install and **diff** them.

---

## Part 6 — Install, confined

- [ ] Copy the **exact audited artifact** into the test account — the version you reviewed, not
      a fresh download of "latest".
- [ ] Install to **`~/Applications`**, *not* `/Applications`.
      `/Applications` needs admin and is **shared with your main account** — installing there
      defeats the isolation and complicates cleanup.

```bash
mkdir -p ~/Applications
# then drag the .app there, or:  cp -R /path/to/App.app ~/Applications/
```

- [ ] Note anything the installer asks for. **Any admin prompt is a finding** — write down
      exactly what asked and why.

---

## Part 7 — Exercise it

Work through these in order, watching the listener, firewall and log stream throughout.

- [ ] **Control first.** A completely ordinary, benign file. Establishes what "normal" looks like.
- [ ] **Does idle use generate traffic?** Watch for update checks or CDN fetches before you have
      consented to anything.
- [ ] **Remote-resource probe.** A file referencing `http://127.0.0.1:8000/pixel.png`. Does
      merely previewing it cause a request? Check the listener log.
- [ ] **Path-traversal probe, harmless target.** Reference something world-readable such as
      `/etc/hosts` via a relative path. Did it get embedded or rejected? Check `log stream`.
- [ ] **Path-traversal probe, canary target.** Reference your decoy. Then search the rendered
      output for the canary string.
- [ ] **Script/exfiltration probe.** Content that attempts to POST or GET page contents to
      `http://127.0.0.1:8000/`. **If a canary string appears in a listener request, exfiltration
      is confirmed — stop and reject.**
- [ ] **Malformed input.** Broken UTF-8, truncated structures, deeply nested elements. Watch for
      crashes — a crash in a C/C++ parser is a possible memory-safety bug.
- [ ] **Large input.** An unreasonably large file. Watch for runaway CPU or memory.

> **Do not write proof-of-concept exploits for known CVEs.** You are doing intake review, not
> exploit development. Probing your *own* documented concerns is in scope; weaponising a
> published vulnerability is not.

---

## Part 8 — Check for persistence

Re-run every command from Part 5 into a second folder and diff:

```bash
mkdir -p ~/after && cd ~/after
# …re-run the Part 5 commands here…
diff -r ~/baseline ~/after
```

- [ ] **Launch agents / daemons** — a previewer or simple utility should install none.
- [ ] **Login items** — anything new is a finding.
- [ ] **Registered plugins** (`qlmanage -m plugins`) — only what you installed, nothing more.
- [ ] **Shell startup files** — checksums unchanged.
- [ ] Anything unexpected here **outranks a clean static review.** Trust observed behaviour.

---

## Part 9 — Record, then clean up

- [ ] Write the runtime findings into your report **before** tearing anything down: what it
      contacted, what it read, what it spawned, what persisted.
- [ ] Save the listener log and any canary hits as evidence.
- [ ] Make the decision: **Accept · Accept with restrictions · Reject · Hold.**
- [ ] Delete the test account **and its home folder** (System Settings → Users & Groups →
      remove account → *Delete the home folder*). This is a cleaner reset than uninstalling.
- [ ] Delete the reviewed source from [`../../quarantine/`](../../quarantine/).
- [ ] If the decision was Accept or Accept-with-restrictions, install the **exact audited
      version** on your real machine, keep the outbound firewall on for a while, and record the
      re-audit trigger.

---

## Stop immediately if…

- A canary string appears in **any** network request → exfiltration confirmed.
- It contacts a destination that no phase predicted.
- It asks for **administrator privileges** without a reason you can explain.
- It installs a launch agent, launch daemon, or login item.
- It spawns a shell, an interpreter, or a network utility.
- It reads paths unrelated to its documented function.

Each of these is a **Reject** under the framework's decision model. Record it, remove the
software, and delete the account.

---

## Is there a cleaner way than printing this?

Printing works and has one real advantage: it stays readable when you are deliberately keeping
the test account offline and unlinked. But two lighter options:

- **Put the PDF in `/Users/Shared/`.** It is readable from both accounts, opens in Preview, and
  needs no printer. *(Do not rely on the software under review to display it.)*
- **Keep your admin session logged in** and use fast user switching to read it, switching back
  to the test account to work.

---

*Part of the [External Code Intake Security Framework](../README.md). Setup only — the
observations and decision belong in [`../phases/phase-5-runtime-sandbox.md`](../phases/phase-5-runtime-sandbox.md)
and your [audit report](../templates/audit-report-template.md).*
