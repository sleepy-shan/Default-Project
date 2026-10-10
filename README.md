# Dartotsu Web

A responsive web app for discovering anime and manga and tracking your
personal watching/reading progress. Built with **Flutter Web (Dart)**,
powered by the public **AniList API** for metadata, with an optional
**Supabase** (PostgreSQL + Auth + RLS) backend for cloud-synced lists.

This project follows the "Dartotsu Web App Plan" (MVP scope): responsive
dashboard, browse/search with filters, media detail pages, personal list
with status/progress/score, airing calendar, account connections, settings,
and a credits page — with loading, empty, error and success states handled
throughout.

## Features (MVP scope)

| Area | What works |
| --- | --- |
| Discover | Home dashboard with trending anime/manga and "popular this year" rails |
| Browse | Anime & Manga pages with genre/status/format/season/year/sort filters and infinite scroll |
| Search | Debounced full-text search across anime and manga (URL-shareable: `/search?q=...`) |
| Details | Covers, synopsis, genres, tags, metadata, studios, relations, recommendations, AniList link |
| Track | Add to list, change status, episode/chapter progress stepper, 0–10 score, remove |
| My List | Filter by status, sort, quick "+1", reset/mark completed, remove with confirmation |
| Calendar | Weekly AniList airing schedule with day grouping and week navigation |
| Connections | Account + service connection status and capability overview |
| Settings | System/Light/Dark theme (persisted), storage mode, clear-list action |
| About | Version, credits and links |
| UX | Responsive rail/bottom-nav shell, keyboard-friendly controls, long-title + missing-image handling, 429/rate-limit and offline states with retry |

## Run it

Requirements: Flutter SDK (stable 3.47 or newer) with the web target.

```bash
flutter pub get
flutter run -d chrome          # or: flutter run -d web-server
```

That's all you need. Without any additional configuration the app runs in
**local demo mode**: browsing/searching real AniList data, while your list
is stored in this browser's localStorage.

### Connect Supabase (optional, for real accounts)

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR-ANON-OR-PUBLISHABLE-KEY
```

1. Create a Supabase project and run [`supabase/schema.sql`](supabase/schema.sql)
   in the SQL editor (tables + Row Level Security policies).
2. In Authentication → Providers, enable Email (password or magic link).
3. Build/run with the two `--dart-define` flags above.

The anon/publishable key is a *public* client key protected by RLS — it is
safe to ship. The **service-role key must never be used in the client**.
Do not commit keys; pass them at build time (see `.gitignore` notes /
your CI secrets).

## Project structure

```
lib/
  main.dart                      App entry + Supabase init (config-gated)
  app.dart                       MaterialApp.router, theme wiring
  core/
    config/app_config.dart       dart-define configuration (no hardcoded secrets)
    theme/                       Design tokens + light/dark ThemeData
    utils/                       AppException (typed errors), Formatters, Debouncer
  data/
    anilist/                     GraphQL client, queries, JSON→model mapper
    models/                      Media, MediaEntry, AiringScheduleItem, enums
    repositories/                MediaRepository, TrackingRepository (+ local
                                  and Supabase implementations), AuthRepository
  state/                         Riverpod controllers (browse, search, detail,
                                  lists, calendar) + future providers
  ui/
    router/app_router.dart       go_router routes (deep-linkable)
    layout/app_shell.dart        Responsive shell (rail ⇄ bottom nav + top bar)
    components/                  Poster cards, grids, state views, editors…
    screens/                     Home, Browse, Search, Detail, My List,
                                  Calendar, Connections, Settings, About
supabase/schema.sql              PostgreSQL schema + RLS policies
test/                            Unit + widget tests (40 tests)
```

### Architecture notes

- **Metadata vs. personal data.** AniList is the source of truth for public
  metadata; the connected tracking store is the source of truth for the
  user's list. Only a small metadata subset is cached per entry so the list
  renders without re-fetching the catalog.
- **One tracking interface.** All screens talk to `TrackingRepository`.
  `LocalTrackingRepository` (browser storage) and
  `SupabaseTrackingRepository` (PostgreSQL, RLS-scoped) are interchangeable;
  adding AniList/MAL/Simkl account sync later means adding another
  implementation, not rewriting screens.
- **State management.** Riverpod 3 (`NotifierProvider` + `FutureProvider`
  families). Custom `LoadState` drives the explicit
  loading/empty/error/success UI contract.
- **Rate limiting.** AniList allows 90 req/min (30 degraded). The client
  retries transient failures with backoff and surfaces 429 as a friendly
  error with a retry action.

## Tests

```bash
flutter test          # unit + widget tests
flutter analyze       # static analysis
```

- `test/anilist_mapper_test.dart` — API payload mapping (incl. fuzzy dates, incomplete data)
- `test/media_entry_test.dart`, `test/formatters_test.dart` — model + formatting rules
- `test/local_tracking_repository_test.dart` — add/update/status/progress/score/remove, clamping, serialization
- `test/widget_test.dart` — StateView/ErrorView/EmptyView/StatusBadge/ProgressEditor behavior

Manual QA worth doing on a real device: search with no results, image-less
titles, very long titles, 429 handling, adding/updating/removing entries
after a page reload (local mode), theme persistence, keyboard-only
navigation, and mobile (≤600px) → tablet → desktop layouts.

## Deploy

```bash
flutter build web --release
```

Output in `build/web` is a static bundle — host it on any static host
(GitHub Pages, Netlify, Vercel, Firebase Hosting, Supabase Storage + CDN).
The router is URL-based, so configure the host to rewrite unknown paths to
`index.html` for deep links (e.g. `/media/anime/154587`).

## Known limitations

- AniList OAuth (connecting a personal AniList *account* to two-way sync
  list changes) is not implemented; AniList is used as the metadata
  source. Account scopes require a server-side flow (Edge Function) to
  keep tokens out of the client.
- MAL/Simkl connections are status-only placeholders.
- No PWA offline support yet (the plan lists "browser-only vs PWA" as an
  open decision); the manifest exists but service-worker caching does not.
- Local demo data never leaves the browser.

## Credits

- [Dartotsu project](https://github.com/aayush2622/Dartotsu) — feature reference
- [AniList API](https://docs.anilist.co/) — anime & manga metadata
- [Flutter](https://flutter.dev) · [Supabase](https://supabase.com) — app stack

This is an independent project for personal/educational use. It hosts no
media and is not affiliated with AniList or the Dartotsu project.
