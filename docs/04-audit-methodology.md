# 04 — Audit Methodology: How the Five Phases Fit Together

This is the map for the actual audit. Each phase answers one big question and feeds the next. You don't always run all five — [`02-artifact-triage.md`](02-artifact-triage.md) told you which apply to your artifact type.

---

## The five phases

```
 ┌───────────────────────────────────────────────────────────────────┐
 │ STEP 0 · TRIAGE — What am I downloading?  (02-artifact-triage.md)  │
 │ Identify the type → know which phases below matter most.           │
 └───────────────────────────────────────────────────────────────────┘
                                │
        ┌───────────────────────┼───────────────────────┐
        ▼                                                ▼
 ┌──────────────┐  "Should I even   ┌──────────────┐  "Is the finished
 │ PHASE 1      │   consider this?"  │ PHASE 4      │   file authentic and
 │ Provenance & │                    │ Binary /     │   properly signed?"
 │ reputation   │                    │ artifact     │
 └──────┬───────┘                    └──────┬───────┘
        │                                   │
 ┌──────▼───────┐  "What does it     ┌──────▼───────┐  "How does it behave
 │ PHASE 2      │   pull in & run    │ PHASE 5      │   when it actually
 │ Supply chain │   at build time?"  │ Runtime /    │   runs, in isolation?"
 └──────┬───────┘                    │ sandbox test │
        │                            └──────┬───────┘
 ┌──────▼───────┐  "What does the           │
 │ PHASE 3      │   code actually DO?"       │
 │ Source review│                           │
 └──────┬───────┘                           │
        └───────────────┬───────────────────┘
                        ▼
        ┌───────────────────────────────────┐
        │ DECIDE — weigh findings, go/no-go, │
        │ write it down (report template).   │
        └───────────────────────────────────┘
```

| Phase | The question it answers | Primary tools/skills |
|-------|-------------------------|----------------------|
| **1 · Provenance & reputation** | Is this project real, active, and run by trustworthy people? | GitHub web UI, reading history & issues |
| **2 · Supply chain** | What does it depend on, and what code runs when it's built/installed? | Reading manifests, lockfiles, build scripts, CI config |
| **3 · Source code review** | What does the code actually *do* — network, files, commands, obfuscation? | Reading code; targeted text searches for risky patterns |
| **4 · Binary / artifact** | If pre-built: is the file authentic, signed, notarized, untampered, and asking for sane permissions? | macOS: `codesign`, `spctl`, `stapler`, `pkgutil`, `otool`, `shasum` |
| **5 · Runtime / sandbox** | How does it behave when run, in an environment where it can't hurt you? | Isolated account/VM, network + file monitoring |

---

## How the phases reinforce each other (defense in depth)

No single phase is sufficient — that's the point. Each covers the others' blind spots:

- **Phase 1** can be *faked* (bought stars, fake activity) → **Phase 3/4** verify the actual code/binary.
- **Phase 3** can *miss* things (obfuscation, a subtle bug, a compiled dependency you can't read) → **Phase 5** catches misbehavior at runtime; **Phase 1** provides human context.
- **Phase 4** proves a binary is *authentic and un-tampered*, but **not that it's benign** → you still need reputation (1) and runtime observation (5).
- **Phase 2** catches harm that hides in *build/install scripts*, which a casual "the app looks fine" glance misses entirely.

When independent phases agree, your confidence is well-founded. When they conflict, trust the **more concrete** evidence (what the code/binary actually does) over soft signals (popularity, a nice README).

---

## The order to work in

1. **Triage first** (Step 0) — always. It's fast and prevents wasted effort.
2. **Phase 1 next** — it's cheap and rejects most bad candidates before you invest more.
3. Then run the phases your artifact type calls for. For readable code, do **2 → 3**. For a pre-built binary, do **4**. For anything that will actually run with real privileges, finish with **5**.
4. **Decide and record** using [`templates/audit-report-template.md`](templates/audit-report-template.md).

> **Stop early when warranted.** If Phase 1 turns up a dealbreaker (see [`checklists/red-flags.md`](checklists/red-flags.md)), you're done — reject it. *Fail closed.* You don't owe a suspicious project the benefit of a full audit.

---

## Recording as you go

Open the [report template](templates/audit-report-template.md) *before* you start and jot findings into it phase by phase. Two reasons:

1. **It forces honesty.** Writing "I couldn't verify the signature" makes the gap visible instead of silently skipped.
2. **It pays off on updates.** When a new version ships, you re-check against your notes and review only what changed — much faster than starting over.

---

## Handling updates (the part everyone forgets)

Your audit certifies **one specific version**. Because a trusted project can later be hijacked or turn malicious, treat updates as mini-audits:

- **Pin** the version/commit/tag you audited; don't auto-update powerful software blindly.
- On update, **re-run Phase 1 briefly** (any ownership change? maintainer change? new maintainers?) and **review the diff** — what changed between the version you trusted and the new one.
- Re-verify the **signature/notarization** of any new binary (Phase 4).
- Be extra wary of an update that suddenly **adds network access, new entitlements, or new dependencies**.

---

## Next step

Begin at [`phases/phase-1-provenance.md`](phases/phase-1-provenance.md).
