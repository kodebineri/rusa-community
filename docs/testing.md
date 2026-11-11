# Testing — `test/`

Companion to root `AGENTS.md`. Seven files, **139 tests**:

| File | What it covers |
|---|---|
| `test/widget_test.dart` | widget-level tests for the whole app (the bulk) |
| `test/terminal_test.dart` | widget tests for the Shell prompt (Enter, ↑/↓ history, Tab, multi-line, Ctrl+L, output) |
| `test/mongosh_interpreter_test.dart` | unit tests for the terminal's command table (`MongoshInterpreter`) |
| `test/mongosh_completer_test.dart` | unit tests for Tab completion + `hasUnbalancedBrackets` |
| `test/mongo_json_parser_test.dart` | unit tests for the mongosh-flavoured JSON parser |
| `test/compass_density_test.dart` | unit tests for the desktop/touch density profiles |
| `test/json_auto_indent_formatter_test.dart` | unit tests for the JSON auto-indent formatter |

> **Status: 139 pass / 0 fail, `flutter analyze` clean.**

## Commands

```bash
flutter test                              # all — expect 139/139
flutter test test/widget_test.dart        # just the widget tests
flutter test test/mongosh_interpreter_test.dart
flutter analyze                           # expect "No issues found!"
```

## Three behaviors every full-app test must respect

These were introduced recently; tests written before them silently fail.

1. **A returning user boots into the connection popup.** `_isConnectModalOpen` is decided by
   `_loadPreferences` (a first-time user gets the welcome tour instead), so the
   `ConnectionModal` overlay covers the shell and `tester.tap(...)` on shell widgets lands on
   the backdrop. Every full-app test calls the `closeConnectionPopup(tester)` helper (defined
   at the top of the test file, right after the imports) immediately after pumping
   `const CompassApp()`. It taps the modal's close icon and is a no-op if the popup is already
   closed.
2. **Queries do not execute on type.** `CompassQueryBar` commits the filter/options only when
   **Find** is tapped (`_executeWithCurrentFilter`); `_handleFilterChange` merely validates.
   Test 2 therefore taps `find.text('Find')` before asserting `onChangeOptions` fired — typing
   alone leaves `last` null.
3. **The first run is the welcome tour, which ends in EULA acceptance.** The app reads
   `SharedPreferences` on startup; if `eula_accepted` is unset (or `onboarding_done` is
   `false`), `OnboardingModal` covers everything. `main()` has a global `setUp` that calls
   `SharedPreferences.setMockInitialValues({'eula_accepted': true})`, so every test except the
   onboarding ones sees a returning user (an absent `onboarding_done` counts as *done*).
   Without the plugin mock the read throws and the app would deadlock behind the cover.
   (`closeConnectionPopup` also does one extra `pump()` to let the stored flags load and clear
   the startup cover.)

Run `flutter analyze` before `flutter test` — analyzer errors usually mean a finder or API
misuse that would fail the test anyway.

## Test inventory (in execution order)

| # | Name | Covers |
|---|---|---|
| 1 | `CompassApp builds without error` | smoke; full app at 1920×1080 |
| 2 | `query bar filter stays editable across empty/non-empty` | element identity of the filter `EditableText` across rebuilds (the `Visibility(maintainState)` fix); taps **Find** to commit before asserting `onChangeOptions` |
| 3 | `CompassInput handles Backspace and arrow keys (needs DefaultTextEditingShortcuts)` | `sendKeyEvent` on `CompassInput`; proves the `DefaultTextEditingShortcuts` wrapper in `main.dart` |
| 4 | `CompassHeader respects top safe area inset` | `tester.view.padding = FakeViewPadding(top: 48)` propagates through header |
| 5 | `CompassHeader hides Reset Samples button when showResetSample is false` | `showResetSample` gating |
| 6 | `AggregationsView allows editing stage content, adding stages, and running pipeline` | `Visual Pipeline Stages` → `Add Stage` → `Stage 4:` → `Run Pipeline` → `Pipeline Results` (uses `pumpAndSettle`) |
| 7 | `selecting collections opens them in tabs` | sidebar click → tab appears; close icon; `'<n> open'` counter |
| 8 | `collection tab bar follows the selected CompassTheme variant` | pumps `CollectionTabBar` inside `CompassTheme(variant: monokaiLight, …)` and asserts the strip decoration uses `variant.palette.bgPanel` / `.border` |
| 9 | `options menu lists every theme and applies the selected one` | full app: closes the popup, opens the header `⋮` menu, expects every `CompassThemeVariant.label` + `DARK THEMES` / `LIGHT THEMES` headings, taps `Monokai Light` → root `CompassTheme.variant` + header color flip |
| 10 | `content views follow the selected light theme (documents, aggregations, schema, indexes)` | full app: closes the popup, selects `materialLight` via the `⋮` menu, then walks every section with `selectSection(label)` / `expectLightSurfaces(section)` (asserts no dark-palette surface remains) |
| 11 | `tree-mode copy icon opens a popup with the copied value and an Insert Document button` | **duplicate/duplicate-popup flow**: copy icon → `InsertDocumentModal` in clone mode with cloned JSON + fresh `_id`, no silent insert; unmodified insert → `E11000` banner, count unchanged; edit isbn → insert succeeds, modal closes, count +1, `#3` card appears |
| 12 | `Analyze Schema button shows progress and re-runs the analysis` | open Schema → auto-analysis shows disabled `Analyzing...` → 250 ms pump → idle + field cards; insert a doc with a new field directly via `mongoEngine.insertDocument` (schema stays stale) → tap **Analyze Schema** → `Analyzing...` → pump → new field card + header count `10 unique fields` |
| 13 | `Create Index modal creates an index and reports duplicate names` | Indexes section → **Create Index** opens `CreateIndexModal`; empty field → `'Field name is required'`; `year` + `-1 (Descending)` + unique checkbox → create → modal closes, `year_-1` row + `{year: -1}` in the table, engine index `unique == true` / `keys['year'] == -1`; re-create the same name → `'An index with this name or key pattern already exists'` banner, engine count unchanged |
| 14 | `Drop Index modal removes a non-protected index after confirmation` | trash count = `indexes.length - 1` (`_id_` row shows "Protected"); first trash (`isbn_1`, seed order) → `DropIndexModal` shows header title + danger button `'Drop Index'` (`findsNWidgets(2)`) and `isbn_1`; **Cancel** keeps the index; reopen → danger button → engine no longer has `isbn_1`, row + trash disappear, `_id_` untouched |
| 15 | `tree view starts with data structures collapsed` | default `library.books` tree: zero `chevronDown`, two `chevronRight` (one `genre_ids` per doc), `[ ... 2 items ]` + `[ ... 1 items ]` summaries, no `0:` child rows; tap chevron → child rows `0:`/`1:` appear + summary gone; tap again → summary restored |
| 16 | `json view edit button saves changes to the document` | switch to **JSON** mode → one pencil per card; tap pencil → body becomes an `EditableText` (pencil replaced by check/close on that card only); edit `copies_available`, **remove `rating`**, enterText, tap **check** → engine doc updated, `rating` gone (replacement semantics), `_id` preserved, editor closes, pencil returns. Uses `resetToDefaults` teardown |
| 17 | `updateMany with a plain map replaces matched documents` | engine-level: `mongoEngine.updateMany(db, coll, {_id:…}, {title, copies_available})` → matched doc has only those fields (+`_id`), `author`/`rating` gone, the other doc untouched; a `$set` update then merges without removing fields. Uses `resetToDefaults` teardown |
| 18 | `first-time user lands on the welcome tour and accepts the EULA` | overrides the prefs mock with `{}` → `OnboardingModal` slide 1 (`Step 1 of 4`), **no** connect popup; **Next** → sample data (`library`, `social_networks`) → theme (tap **Sunny Rain Forest**, root `CompassTheme` switches) → terms (`EULA.md` body + **I Accept**); `eula_accepted` still unset until the tap, then `eula_accepted`/`onboarding_done`/`theme_variant` persisted and the shell revealed |
| 19 | `the welcome tour's Skip jumps to the licence slide` | `{}` → **Skip** lands on the terms slide (`I Accept` present, `Skip` gone) and nothing is persisted yet |
| 20 | `unticking "don't show this again" replays the tour without re-asking for consent` | `{eula_accepted: true, onboarding_done: false}` → tour shown, last slide reads **Done** (not `I Accept`), finishing leaves `onboarding_done == false` |
| 21 | `a returning user skips the tour and gets the connect popup` | default prefs (no `onboarding_done`) → no tour, connect popup open at boot |
| 22 | `the theme stored on the device is restored on the next launch` | `{eula_accepted: true, theme_variant: 'monokaiLight'}` → root `CompassTheme.variant == monokaiLight` |
| 23 | `"Show Welcome Screen" in the header menu replays the tour` | returning user → `⋮` menu → **Show Welcome Screen** → `Step 1 of 4` |
| 24-28 | `mobile: …` layout regressions | Aggregations / Schema / Indexes at **320 px** wide, the header action sheet on a short phone (first row stays below the status bar, last row scrolls into view), and the connection-modal footer (no overflow) |
| 29 | `saved connections round-trip through AppPreferences` | Profile JSON preserves id, name, URI (including credentials), colour, favourite, lastConnected and readOnly; writing `[]` stays empty instead of restoring the sample profiles |
| 30 | `saved connections are restored from device storage` | `saved_connections` seeded in secure storage → booting `CompassApp` shows the persisted profile in `ConnectionModal` |
| 31 | `legacy plaintext connections migrate to secure storage` | A `saved_connections` value left in `SharedPreferences` is read, written to secure storage, removed from preferences, and survives a second load |
| 32 | `mobile: soft keyboard keeps the Shell prompt visible` | 360 px phone, Shell opened from the header action sheet, `viewInsets.bottom = 300` → no overflow and the prompt sits above the keyboard; the body yields to the terminal while typing |
| 33 | `mobile: export format cards fit a phone` | 360 px Export Collection modal: JSON/CSV cards stack below 360 px and their descriptions wrap; Cancel / Copy / Download stay on one footer row |

## Recurring techniques (copy these patterns)

### Desktop surface

Most tests need the app's desktop width or it lays out differently/overflows:

```dart
tester.view.physicalSize = const Size(1920.0, 1080.0);
tester.view.devicePixelRatio = 1.0;
addTearDown(tester.view.resetPhysicalSize);
addTearDown(tester.view.resetDevicePixelRatio);
```

Test 4 additionally uses `tester.view.padding = FakeViewPadding(top: 48.0)` +
`addTearDown(tester.view.resetPadding)`. Tests 2/3/8 instead pump inside an explicit
`MediaQuery(data: MediaQueryData(size: …))` wrapper; tests 2/3 also wrap in an `Overlay`
(the custom copy/paste menu is inserted there — see `compass_text_menu.dart`).

### Exception drain loop

```dart
await tester.pump();
for (var i = 0; i < 50 && tester.takeException() != null; i++) {}
```

Place after almost every `pump()` (including after taps). It swallows `RenderFlex` overflow
artifacts caused by the test placeholder font (font metrics differ from runtime). If a real
bug surfaces, it will fail an `expect`, not this loop — but if an assertion mysteriously
fails, comment the loop out temporarily to see the hidden exception.

### Pump pattern

```dart
await tester.pumpWidget(const CompassApp());
await tester.pump();
for (var i = 0; i < 50 && tester.takeException() != null; i++) {}
```

No `pumpAndSettle` for the full app (animations/timers can hang it) — only test 6 uses
`pumpAndSettle`, on a standalone `AggregationsView`.

**Full-app tests must dismiss the connection popup first.** A fresh `CompassApp` opens
`ConnectionModal` over the shell (`_isConnectModalOpen = true`), so taps on the header,
sidebar or section tabs hit the modal backdrop. Close it (backdrop tap / its close control)
before driving the shell.

### Tapping icons (no Material `Icon`, so no semantic labels)

```dart
await tester.tap(find.byWidgetPredicate(
  (w) => w is CompassSvg && w.svgString == CompassSvgIcons.sun,
));
```

Icons: `moreVertical` (header options / theme menu), `close` (tab close), `copy` (tree-mode
duplicate), `trash` (indexes table — one per droppable index, so scope or index into the finder).
Scope with `find.descendant(of: find.byType(SomeWidget), matching: …)` when several of the
same icon exist (e.g. one copy icon per document card).

### Scoping finders (critical — same strings appear in multiple places)

- `'Insert Document'` matches the **header button + modal title + modal footer button** —
  always scope: `find.descendant(of: find.byType(InsertDocumentModal),
  matching: find.text('Insert Document'))` (title + button = `findsNWidgets(2)` when open,
  `findsNothing` when closed, because `CompassModalShell` unmounts children).
- `find.text` / `find.textContaining` also match `EditableText` controller text — read the
  controller directly when asserting JSON content:
  `jsonDecode(tester.widget<EditableText>(editor).controller.text)`.
- Button finder: `find.widgetWithText(CompassPrimaryButton, 'Insert Document')`.
- `'Drop Index'` (test 14) matches the **modal header title + danger button** when
  `DropIndexModal` is open — scope by `find.descendant(of: find.byType(DropIndexModal), …)`
  or use `find.widgetWithText(CompassDangerButton, 'Drop Index')` to hit only the button.
- Closed modals are `SizedBox.shrink()` → their contents are not in the element tree; don't
  expect to find them. Note that the modal **widget itself** (e.g. `find.byType(CreateIndexModal)`)
  is always mounted — it is the permanent root-Stack child.

### Engine singleton & test isolation

`mongoEngine` is a **shared mutable global across tests in the same run**:

```dart
addTearDown(mongoEngine.resetToDefaults);   // restore seed data after a mutating test
final books = mongoEngine.getCollection('library', 'books')!;
final count = books.documents.length;       // capture BEFORE the interaction
```

- Seed facts: `library.books` = 2 docs (isbns `978-3-16-148410-0`, `978-1-23-456789-7`);
  `_id` `60c72b2f9b1d8b0015f8a001` on *The Silent Horizon*; `username`/`email`/`isbn` have
  unique indexes → **unmodified duplicate inserts throw E11000 by design** (test 11 relies
  on this: use a unique isbn like `978-0-00-000000-1` for the success path).
- Mutating tests should be appended at the end of the file and use the `resetToDefaults`
  teardown for safety.
- `MongoCollection.documents` is a live list mutated in place — a reference captured before
  an insert still reflects it afterwards.

### Reading widget state directly

```dart
tester.widget<CompassTheme>(find.byType(CompassTheme)).variant   // not isDarkMode (variant is authoritative)
tester.widget<CollectionTabBar>(find.byType(CollectionTabBar)).tabs
tester.widgetList<Container>(...)            // inspect BoxDecoration colors vs variant.palette / CompassColors
```

### Keyboard events (test 3)

```dart
tester.sendKeyEvent(LogicalKeyboardKey.backspace);
tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
```

Needs `DefaultTextEditingShortcuts` — wrap `Directionality` around a `CompassInput`, or pump
the full `CompassApp` (which includes it via `main()`'s wrapper).

## Recipe: adding a test

1. Append at the end of `main()` (after the last test) so shared-engine mutations can't
   affect earlier tests.
2. Start with the desktop surface setup + exception-drain loop (copy from test 1).
3. Pump `const CompassApp()` (full-app tests) or wrap a single widget in
   `Directionality(textDirection: TextDirection.ltr)` (+ `MediaQuery` + `CompassTheme` if it
   reads theme/inherits media).
4. `addTearDown(mongoEngine.resetToDefaults)` if you mutate documents; capture counts before
   interacting.
5. Prefer `find.descendant` scoping; tap icons via `CompassSvg.svgString` predicates; drain
   exceptions after every `pump()`.
6. Verify: `flutter analyze` then `flutter test` (expect `+N` then `All tests passed!`).

## Known quirks that look like bugs (they aren't)

- Overflow exceptions after pumps → drained by the loop (placeholder font).
- `executionTimeMs` from `findDocuments` is the constant `0.8` — don't assert real timing.
- Test 10's `selectSection`/`expectLightSurfaces` helpers iterate `Container`s and drain
  exceptions internally; they're local closures inside that test.
- Tabs counter text is `'<n> open'` (e.g. `1 open`, `2 open`).
- **Schema analysis runs on a 250 ms `Timer`** (mirrors the React `setTimeout(…, 250)`).
  `tester.pump()` without a duration never fires it — always follow up with
  `tester.pump(const Duration(milliseconds: 300))` to reach the completed state. `SchemaView`
  cancels the timer in `dispose()` (test 10 leaves the section mid-analysis; no pending-timer
  failure).
- The default boot state (fresh `CompassApp`): **the connection popup is open** over
  `library.books` (section `documents`, view mode `tree`, empty query, Dracula dark theme,
  sidebar with `library` + `social_networks` pre-expanded). Dismiss the popup before asserting
  on the shell.
- The custom copy/paste menu is inserted into the root `Overlay`; a widget pumped in isolation
  without an `Overlay` ancestor will throw when the menu tries to open.
