# provenance/ — private development records

This folder preserves the **authorship evidence** behind this framework: the
working sessions in which it was conceived, designed, and stress-tested. They
show the project was **conceived and directed by its author**, with AI acting as
an assistant — the human set the intent and made every decision.

## What's here

Six private captures. Together they document two development sessions — plus a
fuller, later export of the first.

**The paired origin story — conception + independent review:**

| File | What it is |
|------|------------|
| `PRIVATE_security-audit-for-external-code_CREATION.json` | Native VS Code export of the **creation** session — complete raw record. |
| `PRIVATE_security-audit-for-external-code_CREATION.md` | Readable Markdown rendering of the creation session (internal "thinking" omitted). |
| `PRIVATE_security-audit-for-external-code_AUDIT.json` | Native VS Code export of the independent **review** session — complete raw record. |
| `PRIVATE_security-audit-for-external-code_AUDIT.md` | Readable Markdown rendering of the review session. |

These four are the **mirrored pair** that demonstrates the originating
methodology: a CREATION pass and an independent, second-opinion AUDIT on a
*different* model. They are kept together as the canonical origin story.

**Extended capture of the CREATION session:**

| File | What it is |
|------|------------|
| `PRIVATE_security-audit-for-external-code_CREATION_full-session.json` | Native export of the **same CREATION session**, captured later and in full — it also covers the migration to a public home, the scope hardening, and repository setup. |
| `PRIVATE_security-audit-for-external-code_CREATION_full-session.md` | Readable Markdown rendering of the full-session export. |

The full-session pair is the **same session** as the original CREATION capture,
exported later so it carries the whole arc through migration and hardening. It is
therefore partially duplicative of the original CREATION record and, on its own,
tells only the CREATION *half* of the origin story. The original paired
CREATION + AUDIT records are retained alongside it precisely because they show
the mirrored conception-and-review methodology that the full-session capture does
not.

The two sessions:

| Session | Model | Role | When |
|---------|-------|------|------|
| CREATION | Claude Opus 4.8 | Framework conception & authoring | July 2026 |
| AUDIT | GPT-5.6 | Independent "second opinion" review | July 2026 |

The `.json` files are the authoritative native exports; the `.md` files are
faithful readable renderings of them.

## Why these are preserved

- **Authorship evidence.** They document that a human conceived and directed the
  work, and that AI assistance was used openly — useful if authorship is ever
  questioned.
- **Development history.** They hold the reasoning behind the decisions
  summarized publicly in
  [`../docs/design-decisions.md`](../docs/design-decisions.md).

## Why they're kept private in a public repo

This repository is public, but these records are **deliberately not published**:

- The transcripts contain **working context** — organizational discussion,
  personal details, and the author's work email in commit/tool metadata — that
  was intentionally kept out of the public documentation. Publishing the raw
  sessions would re-expose exactly what was scrubbed from the public docs.
- Raw sessions include the full, unfiltered process (tool calls, file paths,
  asides) that belongs in a private record, not a public artifact.

**How the privacy is enforced:** everything in this folder **except this
README** is git-ignored (see the repository `.gitignore`), so the transcripts
can sit alongside the project for convenience while being **guaranteed never to
be committed or published**. Because git-ignored files don't travel in commits
or bundles, also back them up privately (e.g. secure personal storage).

## How they were produced

Exported natively from VS Code (Chat view → "⋯ / more actions" → Export) as
`.json`, then converted to Markdown for readability. The Markdown omits the AI's
internal "thinking"; the `.json` retains the complete data.
