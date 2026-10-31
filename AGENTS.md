# AGENTS.md — MongoDB Compass Flutter Client

Read this first. It is the index and the rulebook; **do not rescan the whole repo** —
open only the specific doc and file listed for your task.

## What this is

A **MongoDB Compass clone written in Flutter** (Dart), ported from a React/TSX
reference app. It runs fully against an **in-memory local Mongo engine** seeded with sample
data by default, and can connect to a **real MongoDB server** (via `mongo_dart`) which swaps
the engine instance.

- **Responsive**: the desktop layout is the reference, but the app adapts to phone widths
  (tap targets 44 dp, drawer sidebar, overflow sheets). See invariant 13 and
  `docs/ui.md` → "Touch layer".
- Platform folders: `android/`, `ios/`, `windows/` (macOS/Linux are not scaffolded).
- Active product: `lib/` (Dart/Flutter) — this is what you modify.
- Original React reference: `src/` (TSX) — read-only reference for intended behavior;
  not compiled by Flutter. Comments in Dart files say "Converted from `src/components/X.tsx`".
- Tests: `test/widget_test.dart` (15 widget tests, single file).
- Sample data sources of truth: `sample_library.json`, `sample_social_network.json` (repo root).
- License text: `EULA.md` (repo root) — bundled as a Flutter asset (`pubspec.yaml`) and
  rendered by `EulaModal` via `CompassMarkdownView`; edit the Markdown, not the widget.
- `README.md` at repo root is **stale AI Studio boilerplate** — ignore it.

## Commands

| Task | Command |
|---|---|
| Static analysis (must be clean) | `flutter analyze` |
| Tests (must be 15/15) | `flutter test` |
| Run desktop app | `flutter run -d windows` |
| Run on Android | `flutter run -d <device>` (needs `INTERNET` — already in the main manifest) |
| Run a single test file | `flutter test test/widget_test.dart` |

There is no JS build step for the Flutter app (root `package.json`/`vite.config.ts` belong to
the legacy `src/` React app; `npm` is not needed for Flutter work).

## Doc index

| Doc | Read when you need to… |
|---|---|
| `docs/architecture.md` | understand app shell, state fields, navigation, tabs, CRUD handlers, modal orchestration, `build()` layout, or edit `lib/main.dart` |
| `docs/engine.md` | touch data/query/aggregation behavior, seed data, indexes, models, or connect/real-server logic (`lib/services/*`, `lib/models/*`) |
| `docs/ui.md` | touch any widget: modals, document views, header/sidebar/query bar/tab bar/terminal, icons, or theme (`lib/widgets/*`, `lib/theme/*`, `lib/icons/*`) |
| `docs/testing.md` | write or fix tests in `test/widget_test.dart` |

## Hard invariants (do not break)

1. **No Material app.** No `MaterialApp`, `Scaffold`, `Navigator`, `Theme`, or `Icon` widgets.
   Root is `Directionality` + manual `MediaQuery` + a `Stack` (see `docs/architecture.md`).
   `runApp(const DefaultTextEditingShortcuts(child: CompassApp()))` is **load-bearing** —
   `CompassInput` uses bare `EditableText`, which loses Backspace/arrows/Ctrl+C without it.
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
   them; no stray hit-testing). All 16 modals live permanently in the root `Stack`
   (`main.dart` ~L864–984).
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
    `lib/icons/compass_svg_icons.dart`), never Material `Icon`. 34 icons exist; add new ones
    as new `static const String` SVG literals.
11. **Theme:** colors come from `CompassTheme.of(context)` getters (a bool `isDarkMode`
    InheritedWidget over static `CompassColors` tokens) or `CompassTypography` factories.
    In `main.dart` State use `CompassTheme.palette(_isDarkMode)` — the State's context sits
    *above* the provider, so `CompassTheme.of(context)` would silently fall back to dark.
12. **State field names (easy to get wrong):** section = `_activeTab`
    (`documents|aggregations|schema|indexes`), view mode = `_docViewMode`
    (`tree|json|table`), tab index = `_activeTabIndex` (`-1` = none sentinel). There is no
    `_activeSection` or `_activeTabId`.
13. **Touch layer (mobile):** metrics come from `CompassDensity.of(context)`
    (`lib/theme/compass_density.dart`; tap target 20 dp desktop / **44 dp** touch, switched
    by viewport width < 768). Icon-only controls use `CompassIconButton` (guarantees the hit
    area without changing the glyph size); hover/tap feedback uses `CompassHover` (builder
    API — the control paints its own hover fill); actions that do not fit go into
    `CompassActionSheet`, which is a root-`Stack` child like the modals. Never hard-code
    tap-target sizes.

## Known dead-ends / no-op code (don't "fix" silently, don't rely on)

- `DocumentJsonView.onUpdateDocument` is declared/required but **never invoked** in the file.
- Sidebar search box is display-only (`_searchQuery` is final `''` — dead filter code).
- `google_fonts` is in pubspec but never imported; fonts ("Plus Jakarta Sans", "JetBrains
  Mono") are referenced by name and fall back at runtime — no font files ship.
- `QueryFilterOptions.collation` / `maxTimeMS` are stored but never consumed by the engine.

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
| `AboutModal` (logo, app name, version) | `lib/widgets/modals/about_modal.dart` |
| `CompassMarkdownView` (dependency-free Markdown renderer) | `lib/widgets/compass_markdown_view.dart` |
| `CompassActionSheet` (touch overflow sheet) | `lib/widgets/modals/compass_action_sheet.dart` |
| `CompassIconButton`, `CompassHover` | `lib/widgets/compass_icon_button.dart`, `lib/widgets/compass_hover.dart` |
| `CompassTheme`, `CompassColors`, `CompassTypography`, `CompassDensity` | `lib/theme/` |
| `CompassSvg`, `CompassSvgIcons` | `lib/icons/compass_svg_icons.dart` |
| Tests | `test/widget_test.dart` |
