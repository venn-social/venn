# venn — web

The web counterpart to the iOS app (`../ios/`), against the same Supabase backend. See
[`docs/superpowers/specs/2026-07-30-web-app-phase1-foundation-design.md`](../docs/superpowers/specs/2026-07-30-web-app-phase1-foundation-design.md)
for the phase roadmap, and `CLAUDE.md` rule 17 for the cross-platform parity rule this app
is built under.

**Phase 1 (current):** Next.js scaffold, magic-link auth, a read-only "my profile" page.

## Getting started

```bash
cp .env.local.example .env.local   # fill in the real Supabase URL + anon key
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

## Commands

```bash
npm run dev        # dev server
npm run build      # production build
npm run lint        # ESLint
npm run test        # Vitest unit tests
npm run test:e2e    # Playwright E2E (builds + starts a production server first)
```

Requires Node 24 (see `.nvmrc`) — `nvm use` picks it up automatically if you have nvm.

## Design tokens

`app/globals.css` mirrors `../ios/Venn/Components/Theme.swift`'s color tokens (the
monochrome base + the single neon-blue accent) — see the file's own comments for the
mapping and for why the spacing scale intentionally uses Tailwind's native numeric scale
instead of named tokens (a Tailwind v4 gotcha: named `--spacing-*` keys silently shadow
`max-w-*`/`h-*`/etc. of the same name — see the comment in `globals.css`).
