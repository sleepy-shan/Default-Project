# Ikigai

A responsive web app for discovering anime and manga and tracking your
personal watching/reading progress. Built with **Flutter Web (Dart)**,
powered by the **AniList API** for metadata + account login. Lists are
stored locally in the browser.

This project follows the "Ikigai App Plan" (MVP scope): responsive
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
| Connections | AniList login status + service connection overview |
| Settings | System/Light/Dark theme (persisted), account info, clear-list action |
| About | Version, credits and links |
| UX | Responsive rail/bottom-nav shell, keyboard-friendly controls, long-title + missing-image handling, 429/rate-limit and offline states with retry |

## Run it

Requirements: Flutter SDK (stable 3.47 or newer) with the web target.

```bash
flutter pub get
flutter run -d chrome          # or: flutter run -d web-server
```

That's all you need. Without login the app runs as a **guest**: browsing/searching
real AniList data, while your list is stored in this browser's localStorage.

### Login with AniList

1. Create a client at https://anilist.co/settings/developer
   - Set the **Redirect URL** to where the app is served
     (e.g. `http://localhost:8000/` for `flutter run`, or your production origin).
2. Run/build with your client ID:

```bash
flutter run -d chrome --dart-define=ANILIST_CLIENT_ID=YOUR_CLIENT_ID
```

3. Open **Connections → Login with AniList**, approve on anilist.co —
   AniList redirects back with `#access_token=...` and the app signs you in.
   If the redirect doesn't land (wrong Redirect URL), you can also paste the
   token manually on the same page.

The token is stored only in this browser and only ever sent to AniList itself
(`Authorization: Bearer`). Do not commit client secrets; the implicit grant
needs only the public client ID.

## Project structure

```
lib/
  main.dart                      App entry + AniList redirect-token capture
  app.dart                       MaterialApp.router, theme wiring
  core/
    config/app_config.dart       dart-define configuration (no hardcoded secrets)
    theme/                       Design tokens + light/dark ThemeData
    utils/                       AppException (typed errors), Formatters, Debouncer
  data/
    anilist/                     GraphQL client, queries, JSON→model mapper
    models/                      Media, MediaEntry, AiringScheduleItem, enums
    repositories/                MediaRepository, TrackingRepository (local),
                                 AuthRepository (AniList OAuth)
  state/                         Riverpod controllers (browse, search, detail,
                                  lists, calendar) + future providers
  ui/
    router/app_router.dart       go_router routes (deep-linkable)
    layout/app_shell.dart        Responsive shell (rail ⇄ bottom nav + top bar)
    components/                  Poster cards, grids, state views, editors…
    screens/                     Home, Browse, Search, Detail, My List,
                                  Calendar, Connections, Settings, About
test/                            Unit + widget tests
```

### Architecture notes

- **Metadata vs. personal data.** AniList is the source of truth for public
  metadata and for account identity (OAuth + `Viewer` query). The local
  tracking store is the source of truth for the user's list. Only a small
  metadata subset is cached per entry so the list renders without re-fetching
  the catalog.
- **One tracking interface.** All screens talk to `TrackingRepository`
  (`LocalTrackingRepository` in browser storage); adding AniList/MAL/Simkl
  list sync later means adding another implementation, not rewriting screens.
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
titles, very long titles, 429 handling, AniList login → reload (session
persists) → logout, adding/updating/removing entries after a page reload,
theme persistence, keyboard-only navigation, and mobile (≤600px) → tablet →
desktop layouts.

### Verified in this environment

Built with Flutter 3.47.7 (Dart 3.13.5): `flutter analyze` clean, all
tests passing, `flutter build web --release` compiled, and the built bundle
was exercised headlessly against the live AniList API on desktop and mobile
viewports (home, browse, search, detail, calendar, lists, settings,
connections). Two browser-only issues found and fixed during verification:

- Deep links (`/anime`, `/media/anime/21`) fell back to `/` because Flutter
  web defaults to hash URLs — fixed with `usePathUrlStrategy()`.
- AniList returns **zero results when `status` is sent as an explicit
  `null`** — the query builder now omits unset filters entirely.

Two hosting notes that follow from this: the static host must rewrite
unknown paths to `index.html` (deep links), and pages must be served with
`Cache-Control: no-store` only for `index.html` (hashed assets can be
cached forever).

## Deploy

```bash
flutter build web --release --dart-define=ANILIST_CLIENT_ID=YOUR_CLIENT_ID
```

Output in `build/web` is a static bundle — host it on any static host
(GitHub Pages, Netlify, Vercel, Firebase Hosting). The router is URL-based,
so configure the host to rewrite unknown paths to `index.html` for deep
links (e.g. `/media/anime/154587`).

## Known limitations

- AniList list sync (two-way `SaveMediaListEntry` / `MediaListCollection`)
  is not implemented yet — login identifies the account, lists stay local.
- MAL/Simkl connections are status-only placeholders.
- No PWA offline support yet (the plan lists "browser-only vs PWA" as an
  open decision); the manifest exists but service-worker caching does not.
- Local list data never leaves the browser.

## Credits

- [sleepy-shan/Default-Project](https://github.com/sleepy-shan/Default-Project) — project repository
- [AniList API](https://docs.anilist.co/) — anime & manga metadata + account
- [Flutter](https://flutter.dev) — app stack

This is an independent project for personal/educational use. It hosts no
media and is not affiliated with AniList.
