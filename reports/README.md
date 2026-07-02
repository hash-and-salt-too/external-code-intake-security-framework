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
| _(add rows as you complete audits)_ | | | | |
