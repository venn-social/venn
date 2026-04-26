# Architectural Decision Records (ADRs)

A short, dated note about why we made a choice that's hard to reverse. Goes here, in version control, next to the code it shapes.

Most product decisions live in [Notion](https://notion.so/HQ-34ac60c854a2805fa3b9cc6da0380285). ADRs are for **engineering decisions where the rationale is going to matter to a future-you (or a future contributor) reading the code six months from now and asking "why on earth did we do it this way?"**

## When to write an ADR

Write one when:

- The decision is **load-bearing** — the codebase shape would be different if we'd chosen otherwise.
- The decision is **hard to reverse** — switching costs are nontrivial (1+ weeks of work, or a coordinated migration).
- The reasoning **isn't obvious from the code itself** — someone reading the file in six months would have to reconstruct the why.

Examples that deserve an ADR:

- Picking React Native over Swift (lock-in: 1+ weeks to reverse).
- Picking Supabase over Firebase / a custom backend (lock-in: weeks-to-months).
- Picking Zustand over Redux (lock-in: rewrite all state).
- Picking Jaccard over embedding-based similarity for Venn-overlap (lock-in: rewrite recs).

Examples that DON'T need an ADR (just put in code or commit message):

- File-naming conventions (those go in `docs/ARCHITECTURE.md`).
- Today's bugfix.
- Renaming a function.
- Picking a UI color (use a token).

## How to write one

1. Copy `0000-template.md` to `NNNN-short-title.md` where `NNNN` is the next free four-digit number. Use a kebab-case title.
2. Fill in the sections. Keep it short — this is not an essay; it's a note for future-you.
3. Status is `Proposed` until the team agrees, then `Accepted`. If we change our minds later, update to `Superseded by NNNN` and link the new one.
4. Open a PR like any other change. Reviewers check the rationale and the alternatives section.

## Format

Lightweight Nygard style. Five sections:

- **Status** — `Proposed`, `Accepted`, `Deprecated`, or `Superseded by NNNN`.
- **Date** — ISO format.
- **Context** — what's the situation, what's at stake.
- **Decision** — what we chose, in one paragraph.
- **Consequences** — what gets easier, what gets harder, what we're locked into.
- **Alternatives considered** — what else we looked at and why we passed.

## Index

| #                                         | Title                                          | Status   | Date       |
| ----------------------------------------- | ---------------------------------------------- | -------- | ---------- |
| [0001](./0001-react-native-over-swift.md) | Build on React Native + Expo, not native Swift | Accepted | 2026-04-26 |
