# @venn/mobile

The Venn iOS + Android app, built with [Expo](https://expo.dev) and React Native.

## Quick commands

Run these from the **repo root** (one level up from here), not from this folder:

```bash
npm run mobile             # Start the dev server
npm run mobile:ios         # Start and open in iOS simulator (Mac only)
npm run mobile:android     # Start and open in Android emulator
```

Or from inside `apps/mobile`:

```bash
npm run start
npm run lint
npm run typecheck
npm run test
```

## Folder map

```
src/
├── app/              Expo Router file-based routes. One file = one screen.
│   ├── (tabs)/       Bottom-tab screens.
│   └── auth/         Login / signup (presented as modals).
├── components/
│   └── ui/           Design-system primitives: Button, Text, Screen, etc.
├── constants/        Theme tokens, routes.
├── features/         Feature modules. Each folder is self-contained.
│   └── auth/         Auth provider, hook, types.
├── hooks/            Cross-feature custom hooks.
├── lib/              Core infra — Supabase client, env validation.
├── services/         API wrappers. All Supabase calls go here.
├── stores/           Zustand stores (add as needed).
├── types/            Cross-feature TypeScript types.
└── utils/            Pure helper functions + their tests.
```

See `docs/ARCHITECTURE.md` in the repo root for _why_ it's shaped this way.
