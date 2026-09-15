# 05 — Update Audit: A New Version of Something You Already Accepted

*Cheap re-verification against a stored baseline. Not a re-audit.*

---

## What this is for

An intake decision certifies **one exact version**. But almost every macOS app updates
itself, so the thing you approved can quietly replace itself with something you never
saw. Re-running a full audit on every point release does not scale — and a framework
that demands it will simply be ignored.

The expensive part of an audit is **establishing what "normal" looks like**. Once that
is written down, checking a new version against it is fast.

> **The one question an update audit answers:**
> **Did the trust anchor or the privilege change?**
>
> That is all. It says nothing about behaviour, and a clean result is **not permission
> to install**.

**Prerequisite:** the artifact was previously accepted **and** a `*.baseline.txt` was
recorded beside its report. No baseline → this is not an update audit; it is a fresh
intake.

---

## Cost

Measured on the framework's first real update audit (Little Snitch 6.4.1 → 6.5 — see
[`../reports/little-snitch-v6.5-update-audit.md`](../reports/little-snitch-v6.5-update-audit.md)):

| | |
|---|---|
| **First run, including learning the workflow** | **25m18s** |
| One-time instrument calibration *(excluded; never recurs)* | 6m01s |
| **The drift comparison itself** | **6 seconds** |
| Estimated clean repeat | ~10–12 min |

> **That figure is the cost of reaching a *decision*, not of shipping the update.**
> Installation, and the verification that the installed bytes match the audited ones,
> happened after the clock stopped and were not measured. Budget for them separately —
> and note that the install is where that particular run went wrong (Step 8).

**Budget 10–15 minutes for a routine update of a high-privilege artifact.** The
mechanical comparison is effectively free; nearly all the remaining time is judgment —
reading release notes, corroborating provenance, and proving your instruments are not
lying to you. *Automating harder does not help, because the fast part was already
automated.*

---

## Step 0 — Disposition first (yes, even for an update)

Run the same ladder from [`02-artifact-triage.md`](02-artifact-triage.md). For updates,
**G0 has a special answer**:

> *"Do I already have a trusted tool that does this job?"* →
> **Yes — the version you already cleared.**

So **WORK AROUND means "stay on the pinned, audited version,"** and it is a perfectly
legitimate, free outcome. Update only when there is a reason to.

Gather these before deciding:

- [ ] **Does the release claim security fixes?** No claimed fix is a strong argument to wait.
- [ ] **Is there real pressure?** OS-compatibility deadlines, a broken feature you rely on.
- [ ] **Does it add new risk?** New capabilities, new network behaviour, anything the
      vendor labels *experimental*.
- [ ] **Will the updater act on its own?** Check whether it auto-*checks* or
      auto-*installs*. Checking-and-prompting is a much weaker forcing function than
      silent replacement.

**Decision A (the artifact) and Decision B (the task) are independent.** An update can be
a perfectly good **Accept** that you still decide not to install today.

---

## Step 1 — Pre-commit the escalation triggers ⚠️ before looking at anything

Write down, **in the report, before gathering evidence**, what would force a full
re-audit. This is what stops you from rationalising a finding after you see it.

A good default set for a signed macOS app:

- Team ID changes
- Any **new entitlement** on any component
- Any high-privilege capability appearing (for a network tool: VPN/proxy providers)
- Any **new non-Apple linked library**
- Loss of hardened-runtime / library-validation flags
- Notarization or Gatekeeper regression

Also pre-commit a **time forecast**, so you can later tell whether the framework is
getting cheaper or you are just getting more tolerant.

---

## Step 2 — Calibrate the instrument ⚠️ before trusting a "no drift"

**This is the step people skip, and it is the one that makes the result mean anything.**

> **The tripwire question:** *If this check were broken, what would its output look like?*
>
> A drift checker that read nothing prints **"no drift"** — exactly what a genuinely
> clean update prints. The two are indistinguishable without calibration.

Calibrate the comparator **once per script version**, not once per audit:

| Test | How | Must produce |
|---|---|---|
| **Known-negative** | Compare the *old* version against its own baseline | "No drift" |
| **Known-positive (gross)** | Compare a completely different app against the baseline | Loud, obvious drift |
| **Known-positive (targeted)** | Copy the baseline, delete one entitlement line, re-run | **"NEW PRIVILEGE"** naming that exact entitlement |
| **Known-positive (identity)** | Copy the baseline, alter the Team ID, re-run | Team-ID / authority drift |

> Perturbing **copies of the baseline** is the trick worth remembering: it tests exactly
> the detections your escalation triggers depend on, costs seconds, and touches no binaries.

**Watch for checks the artifact cannot exercise.** In the Little Snitch run, the
"new non-Apple library" detector could not be tested by that artifact's own baseline,
because the app links **zero** non-Apple libraries — a broken parser and a genuinely
clean app produce identical output. That path had to be validated against *different*
apps that do link such libraries before the zero could be believed.

> ⚠️ **Read the calibration output in full — do not `head` it.** In that same run, piping
> a positive-control result through `head -25` hid most of the detectors that had fired,
> and the report was written claiming a coverage gap that did not exist. Filtering output
> is not neutral; it changes what the evidence appears to say. **Count or classify the
> whole result** before summarising it:
>
> ```bash
> <check> | grep -oE '^(🛑|⚠️) [A-Z ]+' | sort | uniq -c
> ```

---

## Step 3 — Read the release notes *before* the binary

Order matters. Read the vendor's claims first, then check the artifact against them.
Reversed, you will unconsciously use the notes to explain away whatever you find.

Record: claimed security fixes (or their absence), new capabilities, anything
*experimental*, and any compatibility deadline.

---

## Step 4 — Fetch, and verify *before* mounting

- [ ] Resolve the download URL **from the vendor's own page**. Do not guess it, even if
      the pattern looks obvious. A redirect that matches the one recorded in the previous
      audit is itself a passing consistency check.
- [ ] Fetch into `quarantine/`. Record **SHA-256** and size; compare size to the
      advertised `Content-Length`.
- [ ] **Verify the signature before mounting anything.**
- [ ] Re-run the vendor's designated-requirement check using the Team ID **carried
      forward from the previous audit** — that makes it a genuine cross-version check
      rather than a circular one.
- [ ] Cross-check the signing timestamp against an independent source (HTTP
      `Last-Modified`, the published release date). Two sources agreeing is real evidence.

---

## Step 5 — Mount read-only and run the drift check

Mounting read-only does not execute anything:

```bash
hdiutil attach -readonly -nobrowse -noautoopen quarantine/<image>.dmg

scripts/verify-known-artifact.sh \
  --baseline reports/<artifact>-<oldversion>.baseline.txt \
  "/Volumes/<Volume>/<App>.app"

hdiutil detach "/Volumes/<Volume>"
```

Confirm the version *inside* the image is the one you think it is, rather than trusting
the filename.

### Then prove the instrument actually read the new version

A "no drift" result is only meaningful if the comparator saw **new bytes**. Compare a
few code hashes between old and new:

```bash
codesign -dv --verbose=4 "<old>/Contents/MacOS/<Binary>" 2>&1 | grep CDHash
codesign -dv --verbose=4 "<new>/Contents/MacOS/<Binary>" 2>&1 | grep CDHash
```

**They must differ.** Every binary changing while no invariant changes is the ideal
shape for a point release. Identical hashes mean you compared something to itself.

---

## Step 6 — Classify the result

| Result | Meaning | Action |
|---|---|---|
| **No drift** | Identity and privilege unchanged | Human decision. Still *not* automatic permission — weigh the release notes and whether you need the update at all. |
| **Composition changed** (components added/removed) | Structure moved, trust anchor intact | Confirm the release notes explain it. If they don't, that gap is a finding. |
| **Trust anchor or privilege changed** | Team ID, authority, notarization, flags, a new entitlement, or a new non-Apple library | 🛑 **Do not install. Escalate to a full re-audit.** |

---

## Step 7 — Record, and re-baseline

- [ ] Write the decision record: **Decision A** (artifact) and **Decision B** (task),
      both human-attributed.
- [ ] Fill in the mandatory **"What this audit did NOT check"** section. A drift check is
      structurally blind to behaviour; say so.
- [ ] **On Accept, record a new baseline for the new version** and keep it beside the
      report. Skipping this means the *next* update has nothing to compare against and
      silently becomes a full intake again.
- [ ] Update the index in [`../reports/README.md`](../reports/README.md).

---

## Step 8 — Install the **audited bytes**, not a fresh download

> 🛑 **Do not use the app's built-in "Check for Updates" to perform the install.**
>
> It will **re-download** the update. Whatever it fetches is a *different act of
> acquisition* from the one you audited: a different TCP connection, possibly a
> different mirror, certainly a file you never hashed. You would be installing an
> artifact whose identity you have not established, on the strength of a report about
> a file you are no longer using. That is an **Accept with no evidence** wearing the
> costume of a completed audit.
>
> The whole value of the audit is the chain **audited bytes → installed bytes**. Install
> from the file you verified.

### The quarantine → approved-staging transition

`quarantine/` is a **read-only review area**, and the standing rule is *never build or
run anything from it*. That rule exists because quarantine holds code whose status is
undecided. Once a human has recorded an **Accept**, the artifact's status has changed —
so move it deliberately rather than quietly relaxing the rule:

1. **Re-verify the hash in quarantine** against the value recorded in the report. This
   is the check that proves nothing altered the file between analysis and install.
2. **Copy** (don't move) it to an approved-staging directory outside the repo.
3. **Re-verify the hash again at the staging location**, to catch a bad copy.
4. Install from staging. Delete staging afterwards.

Keeping the quarantine copy until the post-install checks pass means you can always
re-compare against the exact bytes you reviewed.

### Ordering notes for a system extension

- **Quit the running app first.** Replacing a bundle underneath a running process is
  how you get integrity warnings — and some products now actively monitor their own
  bundle while running and will alert on exactly that.
- **macOS re-stages the extension under a new UUID.** Record the old UUID before you
  start so you can prove the staged copy actually changed.

### 🛑 Do not drag-install a system-extension app in Finder

It can fail **destructively**. Observed on a real update: Finder authenticated far
enough to **delete the existing bundle**, then could not write the replacement from the
read-only image, and reported only *"some items had to be skipped"* — naming no files.
The result was a one-file husk that no longer verified as a bundle at all.

Use `ditto`, which the framework already mandates over `unzip` in Phase 4 because it
preserves signing metadata:

```bash
# 0. Sanity-check the path before any rm -rf.
ls -ld "/Applications/<App>.app"

sudo rm -rf "/Applications/<App>.app"
sudo ditto "/Volumes/<Volume>/<App>.app" "/Applications/<App>.app"

# 3. REQUIRED — see the warning below. Do not omit this.
sudo chown -R root:wheel "/Applications/<App>.app"
```

> ⚠️ **`sudo ditto` preserves the *source* UID numerically — this is a real trap.**
> A vendor's disk image carries whatever UID existed on their build machine. If that
> number happens to match a real account on *your* Mac, the installed app becomes owned
> by that account. Observed on a real update: a vendor DMG carried **uid 504**, which on
> the target machine resolved to a **login-capable account in the `admin` group** — so a
> security tool that had been `root:wheel` became modifiable by an unrelated local user
> without `sudo`.
>
> **Nothing else catches this.** The signature stays valid, notarization stays intact,
> Gatekeeper still accepts, the drift check still reports "no drift," and the binaries
> are byte-identical. Ownership is not part of a code signature and is not in the
> baseline schema. `chown` is not tidying — it is the remediation.

### Expect the extension swap to be silent

macOS prompts for approval only on a system extension's **first** activation or when its
**Team ID changes**. A same-team version update is replaced **without any prompt**.

**Do not read that silence as either success or failure — verify it.** Confirm the
version actually changed:

```bash
systemextensionsctl list | grep -i <vendor>
```

You should see the new version `[activated enabled]` and the old one
`[terminated waiting to uninstall on reboot]`. A silent no-op looks exactly like a
silent success until you check.

---

## Step 9 — Post-install verification

**Do not skip this. The baseline probably does not cover the code that actually runs.**

macOS stages privileged components elsewhere: system extensions execute from
`/Library/SystemExtensions/<UUID>/`, and helpers often from
`/Library/Application Support/<Vendor>/`. Your baseline almost certainly describes the
`.app` bundle in `/Applications`, which is effectively the *installer*.

In the Little Snitch run the staged binary was confirmed byte-identical to the one inside
the app — but that was **verified, not assumed**, and macOS re-stages under a *new* UUID
on update.

```bash
# 1. The installed app should match the image you audited.
scripts/verify-known-artifact.sh \
  --baseline reports/<artifact>-<newversion>.baseline.txt \
  "/Applications/<App>.app"

# 2. Ownership - NOT covered by the baseline schema. Check it by hand.
#    Expect 0. Anything else means the install changed who can modify the app.
find "/Applications/<App>.app" ! -user root | wc -l

# 3. The staged copy should match the audited one.
#    Compare EVERY staged copy - there will be more than one after an update.
for d in /Library/SystemExtensions/*/<ext>; do
  echo "$d"
  shasum -a 256 "$d/Contents/MacOS/<bin>"
done
shasum -a 256 "/Applications/<App>.app/Contents/Library/SystemExtensions/<ext>/Contents/MacOS/<bin>"

# 4. Which staged copy is the RUNNING process actually using?
ps -p "$(pgrep -f <ext-bundle-id> | head -1)" -o comm=

# 5. Enumerate what the app actually registered for persistence.
#    Never recall these paths from memory or from the vendor's CVE history.
scripts/verify-known-artifact.sh --system-persistence "/Applications/<App>.app"
```

> ⚠️ **Do not shortcut step 3 with a glob and `head -1`.** After an update there are
> **two** staged copies — the new one and the superseded one awaiting removal on reboot.
> Taking the first match compares the audited binary against the *old* extension and
> reports a mismatch on a perfectly correct install. Enumerate them all, then confirm
> which one the running process uses. The tooling is not broken in that case; it is
> answering a subtly different question than the one you meant to ask.

All of these must agree before the update is considered closed. The chain you are
proving is **audited bytes → installed bytes → staged bytes → running bytes**.

> ⚠️ **Enumerate persistence — never recall it.** Launchd job names change between
> major versions, and vendor CVE write-ups cite *historical* paths. This framework's
> own 6.4.1 report recorded three plists that do not exist on the machine, because a
> vendor-history detail was written into a current-state inventory and marked ✅.
> Step 5 exists so that cannot recur. Pay particular attention to any job whose
> program lives **outside** the bundle: that is real, privileged, boot-time
> persistence which your baseline does not cover.

**If you had no choice but to use the vendor's own updater** — some products cannot be
updated any other way — then the post-install drift check stops being a confirmation and
becomes the *only* evidence you have about what got installed. Run it, and say plainly
in the report that the installed bytes were never independently verified before
execution.

---

## What an update audit can never tell you

Be honest about the ceiling every time:

- **Behaviour.** Nothing is run. A malicious change that keeps the same Team ID,
  entitlements and component list — which is exactly what a compromise of the vendor's
  own build pipeline would look like — passes a drift check cleanly.
- **New code.** Closed-source additions are invisible. If the vendor calls a feature
  *experimental*, record that as a finding; no drift check will surface it.
- **The updater itself.** For a self-updating app, the update component remains a
  standing trust dependency: it can replace the artifact with one that was never
  reviewed.

A drift check is a **change detector**, not a safety proof. It is valuable precisely
because it is narrow — and it is only trustworthy because it was calibrated.
