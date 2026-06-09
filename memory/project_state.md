---
name: project-state
description: Current build state of the venn iOS app — what's wired, what's in-flight, what's missing
metadata:
  type: project
---

As of 2026-06-07, the venn iOS app (Swift 6 + SwiftUI, iOS 26+, Supabase backend) has the following state:

**Fully built and wired to real Supabase data:**

- Auth — magic-link email flow, AuthService, AuthViewModel, AuthView, deep-link callback in VennApp.onOpenURL
- Feed — FeedService reads real posts (joins media + author), FeedView renders ActivityCard per post
- Explorer — ExplorerService reads real media catalog by kind, ExplorerView renders recommendations
- Profile — ProfileService reads/updates profiles + metrics, ProfileView + edit sheet
- App shell — splash video, RootView auth routing, 3-tab MainView, GlassSkyBackground, theme system
- Components — VennMark, VennOverlap (visual only, no real data), ActivityCard, AvatarBadge, MetricTile, Glass, Controls, Interaction primitives
- DB schema — 2 migrations: profiles/follows/auth (init) + polymorphic media catalog + posts

**Untracked / in-flight (not committed):**

- `ios/Venn/Features/Movies/` — TMDB search via MoviesService (HTTP, not Supabase), MoviesView, MoviesViewModel
- `ios/Venn/Models/Movie.swift` — Movie model for TMDB
- `ios/VennTests/MoviesServiceTests.swift` — unit tests for MoviesService
- Open branch `feat/feed-refreshed-design` — restyle of Feed with new FeedRow, MediaCoverTile, RatingLabel, RelativeTime

**Critical gaps (not built):**

1. Post composer — no way for users to log what they've consumed. FeedService comment says "Posting and reacting land in follow-up PRs"
2. Follow/unfollow — DB has `follows` table; no UI or service
3. Friend discovery / user search — no way to find other users
4. Venn overlap computation — VennOverlap component exists but pair mode not wired to real data; no RPC
5. Library detail views — ProfileLibrarySection has category cards but no tap-through to actual lists
6. Watchlist — LibraryCategoryCard shows "Watchlist" but feature doesn't exist
7. Onboarding — no post-auth flow (username setup, interests selection)
8. Avatar upload — ProfileService explicitly defers this
9. Media catalog search in Explorer — recommendation feed only, no search

**Why:** TestFlight target is December 2026. Core social loop (log → follow → feed → overlap) must ship first.
**How to apply:** Prioritize post composer, then follow system, then overlap calculation, then library views.
