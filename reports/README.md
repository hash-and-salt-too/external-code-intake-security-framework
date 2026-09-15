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

## Index

| Date | Target | Version | Decision | Report |
|------|--------|---------|----------|--------|
| 2026-08-06 | Micro Snitch | 1.6.1 | 🟡 Accept with restrictions *(contingent — Phase 5 verification pending)* | [micro-snitch-v1.6.1-intake.md](micro-snitch-v1.6.1-intake.md) |
| 2026-08-05 | Little Snitch | 6.4.1 | 🟢 Accept | [little-snitch-v6.4.1-intake.md](little-snitch-v6.4.1-intake.md) |
| 2026-07-29 → 09-14 | QLMarkdown | 1.5.0 | 🔴 **Reject** | [qlmarkdown-v1.5.0-intake.md](qlmarkdown-v1.5.0-intake.md) |

Fast-lane items are one-line entries in `intake-log.local.md` rather than rows here.
*(`*.local.md` files are git-ignored — they stay on your machine.)*

**Note on the QLMarkdown report:** it is published in **redacted** form. One finding is described
only as *what it is and what it means*, never *how to reproduce it* — the redaction notice at the
top of that report explains why. A separate, non-sensitive hardening suggestion from the same
review was raised openly upstream as
[sbarex/QLMarkdown#238](https://github.com/sbarex/QLMarkdown/issues/238).
