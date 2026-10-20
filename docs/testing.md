# Testing — `test/widget_test.dart`

Companion to root `AGENTS.md`. Single test file, **15 `testWidgets` tests**, all widget
level (no unit tests, no integration tests, no golden tests).

## Commands

```bash
flutter test                              # all (expect 15/15)
flutter test test/widget_test.dart        # the only test file
flutter analyze                           # must stay "No issues found"
```

Run `flutter analyze` before `flutter test` — analyzer errors usually mean a finder or API
misuse that would fail the test anyway.

## Test inventory (in execution order)

| # | Name | Covers |
|---|---|---|
| 1 | `CompassApp builds without error` | smoke; full app at 1920×1080 |
| 2 | `query bar filter stays editable across empty/non-empty` | element identity of the filter `EditableText` across rebuilds (the `Visibility(maintainState)` fix) |
| 3 | `CompassInput handles Backspace and arrow keys (needs DefaultTextEditingShortcuts)` | `sendKeyEvent` on `CompassInput`; proves the `DefaultTextEditingShortcuts` wrapper in `main.dart` |
| 4 | `CompassHeader respects top safe area inset` | `tester.view.padding = FakeViewPadding(top: 48)` propagates through header |
| 5 | `CompassHeader hides Reset Samples button when showResetSample is false` | `showResetSample` gating |
| 6 | `AggregationsView allows editing stage content, adding stages, and running pipeline` | `Visual Pipeline Stages` → `Add Stage` → `Stage 4:` → `Run Pipeline` → `Pipeline Results` (uses `pumpAndSettle`) |
| 7 | `selecting collections opens them in tabs` | sidebar click → tab appears; close icon; `'<n> open'` counter |
| 8 | `collection tab bar follows CompassTheme light mode` | `CompassTheme(isDarkMode: false)` wrapper around the widget |
| 9 | `toggling the theme switches the chrome to light mode` | tap the header sun/moon `CompassSvg` → root `CompassTheme.isDarkMode` + header chrome colors flip |
| 10 | `content views follow light mode (documents, aggregations, schema, indexes)` | helper closures `selectSection(label)` / `expectLightSurfaces(section)` walking every section |
| 11 | `tree-mode copy icon opens a popup with the copied value and an Insert Document button` | **duplicate/duplicate-popup flow**: copy icon → `InsertDocumentModal` in clone mode with cloned JSON + fresh `_id`, no silent insert; unmodified insert → `E11000` banner, count unchanged; edit isbn → insert succeeds, modal closes, count +1, `#3` card appears |
| 12 | `Analyze Schema button shows progress and re-runs the analysis` | open Schema → auto-analysis shows disabled `Analyzing...` → 250 ms pump → idle + field cards; insert a doc with a new field directly via `mongoEngine.insertDocument` (schema stays stale) → tap **Analyze Schema** → `Analyzing...` → pump → new field card + header count `10 unique fields` |
| 13 | `Create Index modal creates an index and reports duplicate names` | Indexes section → **Create Index** opens `CreateIndexModal`; empty field → `'Field name is required'`; `year` + `-1 (Descending)` + unique checkbox → create → modal closes, `year_-1` row + `{year: -1}` in the table, engine index `unique == true` / `keys['year'] == -1`; re-create the same name → `'An index with this name or key pattern already exists'` banner, engine count unchanged |
| 14 | `Drop Index modal removes a non-protected index after confirmation` | trash count = `indexes.length - 1` (`_id_` row shows "Protected"); first trash (`isbn_1`, seed order) → `DropIndexModal` shows header title + danger button `'Drop Index'` (`findsNWidgets(2)`) and `isbn_1`; **Cancel** keeps the index; reopen → danger button → engine no longer has `isbn_1`, row + trash disappear, `_id_` untouched |
| 15 | `tree view starts with data structures collapsed` | default `library.books` tree: zero `chevronDown`, two `chevronRight` (one `genre_ids` per doc), `[ ... 2 items ]` + `[ ... 1 items ]` summaries, no `0:` child rows; tap chevron → child rows `0:`/`1:` appear + summary gone; tap again → summary restored |

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
`MediaQuery(data: MediaQueryData(size: …))` wrapper.

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

### Tapping icons (no Material `Icon`, so no semantic labels)

```dart
await tester.tap(find.byWidgetPredicate(
  (w) => w is CompassSvg && w.svgString == CompassSvgIcons.sun,
));
```

Icons: `sun` (theme toggle), `close` (tab close), `copy` (tree-mode duplicate),
`trash` (indexes table — one per droppable index, so scope or index into the finder).
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
tester.widget<CompassTheme>(find.byType(CompassTheme)).isDarkMode
tester.widget<CollectionTabBar>(find.byType(CollectionTabBar)).tabs
tester.widgetList<Container>(...)            // inspect BoxDecoration colors vs CompassColors
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
- The default boot state (fresh `CompassApp`): `library.books` open, section `documents`,
  view mode `tree`, empty query, dark mode, sidebar with `library` + `social_networks`
  pre-expanded.
