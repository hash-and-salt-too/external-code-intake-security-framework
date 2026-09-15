# Audit Reports

One report per audited item lives here — the concrete output of running the framework in [`../docs/`](../docs/).

## Convention

- **One file per audited target *and version***, e.g. `qlmarkdown-v1.4.2.md`, `sometool-v2.0.md`.
  Version matters because an audit certifies *one specific version*; a new release needs a re-check.
- **Start from the template:** copy [`../docs/templates/audit-report-template.md`](../docs/templates/audit-report-template.md) into this folder and fill it in as you work through the phases.
- **Text only.** Record findings, commands run, and decisions here.

## What does NOT belong here

- **Downloaded / suspect code under review.** Keep any code you download for inspection in your isolated Phase 5 environment (VM or throwaway account) or a separate scratch directory you never build from — never in this durable folder. See [`../docs/phases/phase-5-runtime-sandbox.md`](../docs/phases/phase-5-runtime-sandbox.md).
- **Secrets, tokens, or credentials** of any kind.

## Redaction convention (this is a public repo)

Reports describe work done on a real machine, so they will naturally pick up details
about *that machine* alongside facts about the artifact. **Facts about the artifact are
the evidence and should be published; facts about your machine are not.**

Redact before committing:

| Redact | Replace with | Why |
|---|---|---|
| Local account names | `<local-account>` | Names a real user on your machine |
| Home directory paths | `/Users/<your-username>/` | Same |
| Per-install UUIDs (e.g. staged system extensions) | `<staged-uuid-x.y>` | Machine state, and the *value* is never the evidence — only that it **changed** |
| Process IDs | omit | Ephemeral; adds nothing |
| Hostnames, serial numbers, licence keys | omit | Directly identifying |
| Raw `--system-persistence` output | summarise | Reflects your installed software, not the artifact |

**Keep** — these are artifact facts and the report is worthless without them: hashes,
CDHashes, Team IDs, entitlements, signing authorities, version and build numbers, and
vendor-side values such as a UID baked into a vendor's disk image.

> **The test:** *would this value be identical on someone else's Mac?* If yes, it
> describes the artifact — publish it. If no, it describes **your** Mac — redact it.

The account name `isolation` is an exception: the framework *instructs* readers to
create an account by that name, so it is prescriptive, not a disclosure.

## Index

| Date | Target | Version | Decision | Report |
|------|--------|---------|----------|--------|
| 2026-09-15 | Little Snitch | 6.5 *(update audit)* | 🟢 Accept · installed & verified | [little-snitch-v6.5-update-audit.md](little-snitch-v6.5-update-audit.md) |
| 2026-08-06 | Micro Snitch | 1.6.1 | 🟡 Accept with restrictions *(contingent — Phase 5 verification pending)* | [micro-snitch-v1.6.1-intake.md](micro-snitch-v1.6.1-intake.md) |
| 2026-08-05 | Little Snitch | 6.4.1 | 🟢 Accept | [little-snitch-v6.4.1-intake.md](little-snitch-v6.4.1-intake.md) |
| 2026-07-29 → 09-14 | QLMarkdown | 1.5.0 | 🔴 **Reject** | [qlmarkdown-v1.5.0-intake.md](qlmarkdown-v1.5.0-intake.md) |

Fast-lane items are one-line entries in `intake-log.local.md` rather than rows here.
*(`*.local.md` files are git-ignored — they stay on your machine.)*

## Two kinds of report

- **Intake** (`*-intake.md`) — first contact with an artifact. Establishes what
  "normal" looks like and, on Accept, records a `*.baseline.txt` beside it.
- **Update audit** (`*-update-audit.md`) — a new version of something already
  accepted. Answers only *"did the trust anchor or the privilege change?"* against the
  stored baseline. Far cheaper than an intake, and **not** a re-audit. See
  [`../docs/05-update-audit.md`](../docs/05-update-audit.md).

## Baselines

`*.baseline.txt` files record the signing and privilege invariants that were true at
audit time, for use by
[`../scripts/verify-known-artifact.sh`](../scripts/verify-known-artifact.sh). They are
**evidence, not permission** — a clean drift check never authorizes an install on its
own.

**Note on the QLMarkdown report:** it is published in **redacted** form. One finding is described
only as *what it is and what it means*, never *how to reproduce it* — the redaction notice at the
top of that report explains why. A separate, non-sensitive hardening suggestion from the same
review was raised openly upstream as
[sbarex/QLMarkdown#238](https://github.com/sbarex/QLMarkdown/issues/238).
