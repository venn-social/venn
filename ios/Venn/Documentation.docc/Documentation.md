# ``Venn``

Native iOS social app where people log what they consume — movies, music, books, restaurants, games — and share their favorites with friends. Every profile shows a Venn diagram of where your tastes overlap with the person you're viewing.

## Overview

This is the API documentation for the Venn iOS app, generated from the doc comments in the Swift source. For project-level docs (architecture, workflow, coding standards, ADRs), see [the docs/ directory](https://github.com/venn-social/venn/tree/main/docs) on GitHub.

The app is structured as feature slices under `ios/Venn/Features/<name>/`, each containing a `*Service.swift` (Supabase wrapper), `*ViewModel.swift` (`@Observable` state holder), and `*View.swift` (SwiftUI). Cross-feature primitives live in `Components/`, `Services/`, `Models/`, and `Resources/`.

> Tip: every public type below carries a one-paragraph doc comment explaining what it does and why. Click through to read it.

## Topics

### App layer

- ``VennApp``
- ``RootView``

### Auth

- ``AuthService``
- ``AuthServicing``
- ``AuthState``
- ``AuthView``
- ``AuthViewModel``

### Profile

- ``ProfileService``
- ``ProfileServicing``
- ``ProfileView``
- ``ProfileViewModel``
- ``ProfileEditView``
- ``ProfileEditViewModel``
- ``UserProfile``

### Components (design system)

- ``PrimaryButton``
- ``SecondaryButton``
- ``LoadingView``
- ``EmptyStateView``
- ``Screen``
- ``VennOverlap``

### Services

- ``AppConfig``
- ``SupabaseClientProvider``
- ``Observability``

### Errors

- ``AppError``

### Utilities

- ``Sanitize``
- ``RateLimiter``
