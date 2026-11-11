# AGENTS.md — Rusa (MongoDB database client)

Read this first. It is the index and the rulebook; **do not rescan the whole repo** —
open only the specific doc and file listed for your task.

## What this is

**Rusa** is a MongoDB database client written in Flutter (Dart) — an independent
re-implementation of the MongoDB Compass UI, ported from a React/TSX reference app. By default
it runs fully against an **in-memory local Mongo engine** seeded with sample data; connecting to
a **real MongoDB server** (via `mongo_dart`) swaps the global engine instance.

- Active product: `lib/` (Dart/Flutter) — this is what you modify.
- Reference only: `src/` (TSX) — read-only, not compiled by Flutter. Comments in Dart files say
  "Converted from `src/components/X.tsx`".
- Platforms: `windows/`, `android/`, `ios/`, `linux/` (macOS is not scaffolded).
- Saved connection profiles live in platform secure storage (`flutter_secure_storage`;
  Android `minSdk 24`, Linux needs `libsecret-1-dev` to build); EULA/theme flags stay in
  `SharedPreferences`.
- Tests: seven files in `test/`, **139 tests** — widget tests in `test/widget_test.dart` plus
  `compass_density`, `json_auto_indent_formatter`, `mongo_json_parser`, `mongosh_interpreter`,
  `mongosh_completer`, `terminal`. Patterns live in `docs/testing.md`.
- Sample data sources of truth: `sample_library.json`, `sample_social_network.json` (repo root).
- Legal text: `EULA.md` and `PRIVACY.md` (repo root) — bundled as Flutter assets
  (`pubspec.yaml`) and rendered by `EulaModal` / `OnboardingModal` (its last slide) /
  `PrivacyPolicyModal` via `CompassMarkdownView`; edit the Markdown, not the widgets.
- `README.md` is the user-facing README (about + per-OS install instructions). Keep its
  commands, URLs, and GPG fingerprint in sync when the release pipeline, package names,
  Pages repo layout, or signing key change.
- **Branding:** the product name is **Rusa**, tagline "a MongoDB database client". User-visible
  strings must not say "Compass" and must not use the MongoDB leaf logo — the brand mark is
  `CompassSvgIcons.rusa` (placeholder deer mark). "MongoDB" appears only descriptively, and
  About / EULA / Privacy carry a non-affiliation disclaimer.
- **Launcher icon:** `assets/icon/icon.png` (1024×1024, no alpha) is the source of truth.
  `flutter_launcher_icons` (dev dependency, configured under `flutter_launcher_icons:` in
  `pubspec.yaml`) generates the Android mipmaps, the iOS `AppIcon` set and
  `windows/runner/resources/app_icon.ico`. After replacing the PNG, run
  `dart run flutter_launcher_icons` — then check
  `ios/Runner.xcodeproj/project.pbxproj`: recent versions wrongly rewrite
  `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` to `AppIcon` (it must stay
  `YES`).
- **Identifiers:** OS app id is **`com.kodebineri.rusa`** (Android `applicationId`/`namespace`
  + `MainActivity` package, iOS `PRODUCT_BUNDLE_IDENTIFIER`, Windows `CompanyName`). The **Dart
  package name is `rusa`** (`name:` in `pubspec.yaml`, so imports use `package:rusa/…`).

## Current status — read before you change anything

_Verified 2026-11-10 at HEAD `609e38b`._

- **`flutter analyze` is clean.** `analysis_options.yaml` excludes `build/`, `windows/`,
  `android/`, `ios/` and `linux/`, so native-side edits are never analyzed.
- **`flutter test` is 139/139.** Keep both analyze and tests green. The seven `mobile:` tests
  guard the phone layouts (aggregations/schema/indexes at 320 px, the action sheet height cap,
  the connection-modal footer, the export format cards, and the keyboard inset above the Shell
  prompt).
- **`docs/ui.md` is stale on theme names**: it still says Dracula is the default, lists six
  variants, and shows `Material Light` in the tour. Trust
  `lib/theme/compass_theme_presets.dart`, `OnboardingModal` and the current 139-test suite over
  those lines.
- **A returning user boots into the connection popup** (`_isConnectModalOpen = true`, decided
  by `_loadPreferences`). Full-app widget tests must dismiss it first — use the
  `closeConnectionPopup(tester)` helper in `test/widget_test.dart`, or shell taps land on the
  modal backdrop. A first-time user boots into the welcome tour instead (see below).
- **Queries do not execute on type.** `CompassQueryBar` commits filter/options only on
  **Find** (`_executeWithCurrentFilter`); typing just validates. Tests must tap Find before
  asserting `onChangeOptions`.
- **First run is the welcome tour, which ends in EULA acceptance.** `OnboardingModal`
  (`lib/widgets/modals/onboarding_modal.dart`) covers the whole window with four slides —
  welcome → sample data → theme → terms — and its last slide is the only way past it (no
  close button, no backdrop dismiss; **Skip** jumps *to* the terms slide, never past it).
  The terms slide renders the **full `EULA.md` inline** and the primary action stays
  **disabled until the "I accept the End User License Agreement (EULA)." box is ticked**
  (first run only; a replay shows **Done** with no acceptance box).
  Accepting persists `eula_accepted`; the "don't show this again" box persists
  `onboarding_done`; the theme slide persists `theme_variant`. All three go through
  `AppPreferences` (`lib/services/app_preferences.dart`). The tour is shown when
  `!eula_accepted || !onboarding_done` (an absent `onboarding_done` means *done*, so
  upgrades never see it), and while it is shown the **connect popup does not auto-open** —
  the user lands on the sample data and opens Connect from the header. Re-open the tour from
  the header `⋮` menu / touch action sheet → **Show Welcome Screen** (above About).
  **Design language:** mirrors the reference `mongodb-compass-web-client` `OnboardingPage.tsx`
  (minimal header + `n / N` counter + Skip, one centered 448 px column, 12 px-radius cards with
  an accent border/ring when selected, quiet bottom bar). Keep new slides in that vocabulary
  (see `docs/ui.md` → `OnboardingModal`).
- **Theme default changed:** `rainForestNight` is now the default (not Dracula); the eight
  variant names are in invariant 11. The header options menu and touch action sheet group them
  as `DARK THEMES` / `LIGHT THEMES`.
- **Releases:** pushing a `v*` tag triggers `.github/workflows/build-linux-packages.yml`.
  It builds Debian, Arch and Fedora packages for amd64/arm64 (native arm runners), then
  publishes one GitHub Pages site with `apt/`, `arch/` and `rpm/` subdirectories plus one
  GitHub release. **No CI runs analyze or tests.** Windows has a separate workflow.

## Commands

| Task | Command |
|---|---|
| Static analysis (must be clean) | `flutter analyze` |
| Tests (target 129/129; baseline 127/129 — see status) | `flutter test` |
| Run a single test file | `flutter test test/widget_test.dart` |
| Run one test by name | `flutter test test/widget_test.dart --plain-name "exact test name"` |
| Run desktop app (Windows) | `flutter run -d windows` |
| Run desktop app (Linux) | `flutter run -d linux` |
| Run on Android | `flutter run -d <device>` (needs `INTERNET` — already in the main manifest) |
| Build Linux release | `flutter build linux --release` |
| Regenerate launcher icons | `dart run flutter_launcher_icons` (after replacing `assets/icon/icon.png`) |

There is no JS build step for the Flutter app (root `package.json`/`vite.config.ts` belong to
the legacy `src/` React app; `npm` is not needed for Flutter work).

## Doc index

| Doc | Read when you need to… |
|---|---|
| `docs/architecture.md` | understand app shell, state fields, navigation, tabs, CRUD handlers, modal orchestration, `build()` layout, or edit `lib/main.dart` |
| `docs/engine.md` | touch data/query/aggregation behavior, seed data, indexes, models, or connect/real-server logic (`lib/services/*`, `lib/models/*`) |
| `docs/ui.md` | touch any widget: modals, document views, header/sidebar/query bar/tab bar/terminal, icons, or theme (`lib/widgets/*`, `lib/theme/*`, `lib/icons/*`) — but note its theme section is stale |
| `docs/testing.md` | write or fix tests in `test/widget_test.dart` — but note its status/default-theme claims are stale |
| `docs/play-store-listing.md` | prepare Google Play metadata, screenshots, data-safety answers, or a release checklist |

## Hard invariants (do not break)

1. **No Material app.** No `MaterialApp`, `Scaffold`, `Navigator`, `Theme`, or `Icon` widgets.
   Root is `AnnotatedRegion` → `CompassTheme` → manual `MediaQuery` → `Directionality` →
   `TapRegionSurface` → `Overlay(key: _overlayKey, initialEntries: [_shellEntry])`; the shell
   (`_buildShell`) is a `Stack` living inside that overlay (see `docs/architecture.md`). The
   `TapRegionSurface` + `Overlay` exist so bare `EditableText` fields get tap-outside dismissal
   for the custom copy/paste menu. `runApp(const DefaultTextEditingShortcuts(child: CompassApp()))`
   is **load-bearing** — `CompassInput` uses bare `EditableText`, which loses
   Backspace/arrows/Ctrl+C without it.
2. **No Atlas sample data.** Seed data comes only from the two root JSON files, mirrored as
   Dart literals inside `LocalMongoEngine.seedSampleData()`. Never reintroduce `sample_mflix`,
   `sample_airbnb`, `sample_restaurants`, etc.
3. **JSON files ⇄ Dart seed are hand-mirrored.** The JSON files are NOT loaded at runtime
   (not in pubspec assets). If you edit `sample_library.json` / `sample_social_network.json`,
   you must edit `seedSampleData()` in `lib/services/local_mongo_engine.dart` to match
   (normalization: `$oid` → 24-hex string; `$date` → ISO-8601 with `.000Z`).
4. **Engine access is only through the global `mongoEngine`** (`lib/services/mongo_engine.dart`):
   `LocalMongoEngine mongoEngine = LocalMongoEngine.instance;`. It is a mutable top-level
   global, swapped to a `RealMongoService` on connect and back on disconnect; call `setState`
   afterwards. All reads are synchronous during `build()` — never make the engine async.
5. **Closed modals render `SizedBox.shrink()`.** `CompassModalShell.build` returns shrink when
   `!isOpen`, so closed modal children are constructed but **not mounted** (finders won't see
   them; no stray hit-testing). All 16 modals plus **two** `CompassActionSheet` overlays (header
   + query-bar) live permanently in the root `Stack` (`main.dart` ~L1277–L1405). The
   `OnboardingModal` follows the same rule (it returns shrink when closed) but is a
   full-window cover, not a `CompassModalShell` (root-stack child at ~L1548).
6. **`InsertDocumentModal.onInsert` returns `String?`**: `null` = success (modal closes
   itself), non-null = error message shown in the modal's `CompassErrorBanner`. The handler in
   `main.dart` (`_handleInsertDocument`) must NOT close the modal.
7. **Insert-vs-update guard:** update only when `_editingDoc != null && _clonedDoc == null`.
   A duplicate/clone (`_clonedDoc != null`) must always insert a new document (fresh `_id`).
8. **Exact unique-index error text** (engine throws, modal surfaces it):
   `Exception: E11000 duplicate key error collection: <db>.<coll> index: <indexName>`
9. **Never throw out of `build()`.** The engine's `findDocuments` returns an empty result on
   parse errors; UI input parsing uses `tolerantParse` inside try/catch. Keep it that way.
10. **Icons are `CompassSvg` + `CompassSvgIcons.<name>`** (inline SVG string constants in
    `lib/icons/compass_svg_icons.dart`), never Material `Icon`. 38 icons exist; add new ones
    as new `static const String` SVG literals.
11. **Theme:** colors come from `CompassTheme.of(context)` getters, which resolve the
    selected `CompassThemeVariant`'s `CompassPalette` (`lib/theme/compass_theme_presets.dart`:
    dark = `rainForestNight` (**default**), `dracula`, `tokyoNight`, `nightOwl`; light =
    `sunnyRainForest`, `monokaiLight`, `tokyoNightLight`, `materialLight`). The
    `CompassTheme` InheritedWidget carries the `variant`; `CompassColors` still holds semantic
    tokens (error/warning/info, `modalOverlay`, scrollbars). Styles come from
    `CompassTypography` factories. In `main.dart` State use
    `CompassTheme.palette(_themeVariant)` — the State's context sits *above* the provider, so
    `CompassTheme.of(context)` would silently fall back to the default. Users pick a theme from
    the header options menu (above Report Bug) or the touch action sheet; both call
    `onSelectTheme` → `setState(_themeVariant)`.
12. **State field names (easy to get wrong):** section = `_activeTab`
    (`documents|aggregations|schema|indexes|ddl`; `ddl` — the "Show DDL" tab — exists only for
    views), view mode = `_docViewMode` (`tree|json|table`), tab index = `_activeTabIndex`
    (`-1` = none sentinel). There is no `_activeSection` or `_activeTabId`.
13. **Touch layer (mobile/tablet):** metrics come from `CompassDensity.of(context)`
    (`lib/theme/compass_density.dart`; tap target 20 dp desktop / **44 dp** touch). The touch
    profile is used when the viewport is < 768 dp wide **or**
    `CompassDensity.isTouchPrimaryPlatform` is true (Android/iOS/Fuchsia, read from `dart:io`
    so `flutter test` stays on the desktop profile) — this keeps 8-inch tablets in landscape
    finger-sized. The docked desktop layout switches at 1024 dp on touch platforms
    (`desktopBreakpointFor`). Icon-only controls use `CompassIconButton` (guarantees the hit
    area without changing the glyph size); hover/tap feedback uses `CompassHover` (builder
    API — the control paints its own hover fill); actions that do not fit go into
    `CompassActionSheet`, which is a root-`Stack` child like the modals. Never hard-code
    tap-target sizes. The OS text scale is clamped to **0.8–1.3** and the shell `Column` is
    wrapped in `SafeArea(top: false)` (both in `_CompassAppState.build`), so the dense layout
    survives an Android/iOS font-size setting and the bottom inset (nav bar / home indicator)
    — see `docs/ui.md` → "System insets and OS text scaling".
14. **Text selection is hand-rolled** (`lib/widgets/compass_text_menu.dart`). Material's
    `AdaptiveTextSelectionToolbar` needs `MaterialLocalizations`, so bare `EditableText`s get
    `contextMenuBuilder: compassTextContextMenuBuilderFor(link, density: …)` +
    `onTapOutside: compassHandleTapOutside`, and must be wrapped in a
    `CompositedTransformTarget(link: …)` carrying a matching `LayerLink` (otherwise the menu
    opens in the window corner). Copy/paste do nothing at all without this. The query bar's
    filter / project / sort fields additionally use `JsonSyntaxTextController`
    (`lib/utils/json_syntax_text_controller.dart`) for JSON syntax colouring.

## Known dead-ends / no-op code (don't "fix" silently, don't rely on)

- `google_fonts` is in pubspec but never imported. The UI fonts **do** ship: `Inter`,
  `JetBrains Mono` and `Outfit` are declared under `flutter: fonts:` in `pubspec.yaml` and
  committed in `assets/fonts/` (see `docs/ui.md` → `CompassTypography`), so the same typefaces
  render on Windows, Android, iOS and Linux. Keep `CompassTypography` families/weights in sync
  with `pubspec.yaml`.
- `QueryFilterOptions.collation` / `maxTimeMS` are stored but never consumed by the engine.
- `CompassQueryBar._handleSkipChange` / `_handleLimitChange` are **intentional no-ops**
  ("do not execute on type"); the numeric fields commit only on blur/Find.
The **sidebar search box works** — `_searchQuery` is mutable and filters the DB tree
client-side (`compass_sidebar.dart`); don't add it to the dead list.

## Quick symbol map

| Symbol | File |
|---|---|
| `CompassApp`, `_CompassAppState`, `main()` | `lib/main.dart` |
| `mongoEngine` (global) | `lib/services/mongo_engine.dart` |
| `LocalMongoEngine` (seed, find, CRUD, agg) | `lib/services/local_mongo_engine.dart` |
| `RealMongoService` (live server) | `lib/services/real_mongo_service.dart` |
| All models (`MongoDocument`, `QueryFilterOptions`, …) | `lib/models/mongo_models.dart` |
| `CollectionTab` | `lib/models/collection_tab.dart` |
| Modal primitives (`CompassModalShell`, `CompassInput`, buttons) | `lib/widgets/modals/compass_modal.dart` |
| `EulaModal` (renders the bundled `EULA.md`) | `lib/widgets/modals/eula_modal.dart` |
| `OnboardingModal` (first-run welcome tour + EULA acceptance) | `lib/widgets/modals/onboarding_modal.dart` |
| `PrivacyPolicyModal` (renders the bundled `PRIVACY.md`) | `lib/widgets/modals/privacy_policy_modal.dart` |
| `AboutModal` (logo, app name, version) | `lib/widgets/modals/about_modal.dart` |
| `appPreferences` (`shared_preferences` wrapper) | `lib/services/app_preferences.dart` |
| `AppInfo` (app version, mirror of `pubspec.yaml`) | `lib/app_info.dart` |
| `CompassMarkdownView` (dependency-free Markdown renderer) | `lib/widgets/compass_markdown_view.dart` |
| `CompassActionSheet` (touch overflow sheet) | `lib/widgets/modals/compass_action_sheet.dart` |
| `MongoshInterpreter` (terminal command table + single executor) | `lib/services/mongosh_interpreter.dart` |
| `MongoshCompleter` (Tab completion + `hasUnbalancedBrackets`) | `lib/services/mongosh_completer.dart` |
| `CompassTerminal` (docked Shell drawer) | `lib/widgets/compass_terminal.dart` |
| `CompassIconButton`, `CompassHover` | `lib/widgets/compass_icon_button.dart`, `lib/widgets/compass_hover.dart` |
| `CompassTheme`, `CompassThemeVariant` / `CompassPalette`, `CompassColors`, `CompassTypography`, `CompassDensity` | `lib/theme/` |
| `CompassSvg`, `CompassSvgIcons` | `lib/icons/compass_svg_icons.dart` |
| `CompassTextContextMenu`, `compassTextContextMenuBuilderFor`, `compassHandleTapOutside` | `lib/widgets/compass_text_menu.dart` |
| `JsonSyntaxTextController` (JSON syntax colouring) | `lib/utils/json_syntax_text_controller.dart` |
| Tests | `test/` (see `docs/testing.md`) |
