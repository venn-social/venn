# 0008 — Frontend design goes through Figma first; no improvising

- **Status:** Proposed
- **Date:** 2026-05-08
- **Deciders:** Charles Salomon

## Context

venn's product identity is visual. The "venn-diagram-of-overlap" primitive on every profile, the Liquid Glass aesthetic from iOS 26, the editorial feel of taste cards — none of these are surface decoration. They are the product. A version of venn with the same backend, the same overlap algorithm, and bland default-iOS UI would be a different (worse) product.

Through 2026-04 → 2026-05 the team shipped 8 PRs that each introduced visible UI: theme tokens (PR #35), components (PR #36), auth screens (PR #38), tab shell + the VennOverlap component (PR #40), profile editing (PR #44). Every one was implemented straight to SwiftUI, with the tech-lead-of-the-day picking layouts, type, spacing, and copy on the fly. The result is functional, accessible, and stylistically inert — a "clean iOS app" with no brand.

This is fixable retroactively (a design pass to apply once the brand lands), but the meta-problem — improvising visuals while writing code — will keep producing the same outcome on every future feature unless we change the workflow. The fix is to put a design step before the implementation step, using a tool the founder can drive directly.

`Theme.swift` is honest about being placeholder: _"deliberately conservative placeholders — chosen so the app looks reasonable today while design is still being formalised."_ This ADR formalises how design _will_ be done from this point on.

## Decision

**Every net-new UI surface is designed in Figma before the implementation PR is opened.** The implementation PR's description references the Figma node URL.

Concretely:

- **In scope of the rule:** new screens, new components, new sheets, new empty states, new error states, meaningful re-skins of existing surfaces, new visual languages (e.g. a card style we haven't shipped before), and any change that introduces a new color / type / spacing / radius value not already in `Theme.swift`.
- **Out of scope of the rule:** tweaks within already-defined design tokens (using `Theme.Spacing.lg` where we used `.md` before, swapping `Theme.Color.textPrimary` for `.textSecondary`), pure logic refactors that don't change visuals, copy edits to existing layouts.
- **PR enforcement:** the PR description includes a Figma URL. PRs that introduce in-scope UI without a Figma reference are rejected at review.
- **If Figma doesn't exist yet:** stop. Either the founder designs it (the default), or designer + Claude co-create via the Figma MCP and the founder signs off. The Figma is the source of truth; code follows. We never "stub something reasonable" and promise to redesign later.
- **`Theme.swift` is the bridge.** Figma values land in `Theme.swift` first (as design tokens), then code reads from `Theme.swift`. New tokens require a Figma source — the rule applies.

This is also recorded as **CLAUDE.md rule 15** so any Claude session — and any future contributor reading the project brief — sees it before writing code.

## Consequences

- **Easier:** the visual direction is debated in the right tool (Figma, with the founder driving), at the right time (before code is written), with the right cost of changes (free in Figma, expensive in committed Swift). The codebase ends up with consistent components because the components were designed once, not redesigned ad hoc per feature.
- **Harder:** every feature now has a design step that must happen first. For trivial features ("add a Cancel button to this sheet") this can feel heavy — the rule's "tweaks within tokens" exemption keeps it from blocking small work. For larger features it adds calendar time, which is the right tradeoff for an app whose identity is visual.
- **Committed to:** Figma as the single source of design truth. Adopting another tool later (even a switch within Figma — board → design → Make) is a one-time migration, not a doctrinal break.
- **Required tooling:** Figma desktop or web (founder), Figma MCP (Claude). No additional licenses needed for the ADR itself.

## Alternatives considered

- **Code-first with a periodic "design pass."** What we'd been doing. Produces consistent generic-iOS aesthetics that are hard to shake later because every screen has its own decisions baked in. Rejected.
- **Designer ↔ engineer back-and-forth in PR comments using screenshots.** Treats design as feedback on code. Wrong incentive — the engineer has already invested in the layout, so changes feel expensive even when they shouldn't be. Rejected.
- **A "design sprint" once that locks the design system, then code freely.** Useful as a one-time event (it'll happen) but doesn't solve the per-feature improvising problem — every new feature still wants an out-of-system layout choice. Rejected as a substitute for this rule, but valuable in addition to it.
- **Use AI to generate UI directly from prose.** Tempting and we'll experiment. The output still needs a designer-level human eye to land _with_ the brand rather than diluting it. Generation-then-review is fine; generation-then-ship is not.
