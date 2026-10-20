# UI Layer — Widgets, Icons, Theme

Companion to root `AGENTS.md`. Covers the shared modal primitives, every modal, every
document/collection view, the chrome widgets (header/sidebar/query bar/tab bar/terminal),
the icon system, and the theme system. Line numbers are approximate anchors.

Rules that apply everywhere in this layer (see AGENTS.md): **no Material widgets** — no
`MaterialApp`/`Scaffold`/`Theme`/`Icon`/`TextField`; icons are `CompassSvg`; text inputs are
bare `EditableText` via `CompassInput` (hence `DefaultTextEditingShortcuts` at bootstrap);
all colors resolve from `CompassTheme` + `CompassColors`; all styles from
`CompassTypography`.

## Shared modal primitives — `lib/widgets/modals/compass_modal.dart`

Only these 9 public widgets exist (there is **no** `CompassSelect`/`CompassToggle`/
`CompassDropdown` — selects/checkboxes are built ad hoc per modal, e.g. pill `Wrap`s and
hand-rolled check rows in `create_collection_modal.dart`):

| Widget | Key params | Behavior |
|---|---|---|
| `CompassModalShell` | `isOpen`, `maxWidth = 448`, `children`, `onBackdropTap?` | **`if (!isOpen) return const SizedBox.shrink()`** → else `Positioned.fill` → `CompassColors.modalOverlay` (60% black) → centered card: width `min(maxWidth, constraints.maxWidth - 32)`, `maxHeight = constraints.maxHeight - 64`, margin 16, padding 20, radius 12, `bgPanel` + `border`, shadow; content = `SingleChildScrollView > Column(stretch)`. Backdrop: outer `GestureDetector(onTap: onBackdropTap)` with an inner tap-absorber so only backdrop clicks close. **Must be a direct child of a `Stack`.** |
| `CompassModalHeader` | `title`, `subtitle?`, `iconSvg`, `iconColor?/iconBg?/iconBorder?`, `onClose` | 32×32 icon chip (green badge defaults) + title (`CompassTypography.header`) + optional subtitle + close `CompassSvg(close, 14)`; bottom border |
| `CompassFieldLabel` | `label`, `hint?`, `trailing?` | label row with optional right hint |
| `CompassInput` | `controller`, `placeholder`, `autofocus`, `maxLines = 1`, `minLinesAuto = true`, `minLines?`, `mono = true`, `obscureText`, `onChanged?`, `onSubmitted?` | **Built directly on `EditableText`** (documented: avoid Material `TextField` dependency). Own `FocusNode` (disposed). Boxed container + placeholder shown only when text empty. `resolvedMinLines = minLines ?? (minLinesAuto && maxLines > 1 ? maxLines : 1)` |
| `CompassPrimaryButton` | `label`, `iconSvg?`, `onTap` (null = disabled), `fullWidth` | green accent button; label rendered as `Text(label, CompassTypography.header(...))` |
| `CompassSecondaryButton` | `label`, `iconSvg?`, `onTap` | subtle `bgSubtle` + border |
| `CompassDangerButton` | `label`, `iconSvg?`, `onTap` | red; ⚠ the rendered icon is **hardcoded to `CompassSvgIcons.trash`** — `iconSvg` is ignored |
| `CompassErrorBanner` | `message` | rose banner: `errorRedBg/Border` + activity icon + `Text(message)` |
| `CompassModalFooter` | `children` | right-aligned row, 8px gaps, top border |

## Modal inventory — `lib/widgets/modals/`

All modals (except the three noted) render via `CompassModalShell`; all reset
controllers/errors in `didUpdateWidget` when `isOpen` flips false→true; all are instantiated
permanently in `main.dart`'s root `Stack` (~L864–984).

| Modal | Props | Notes |
|---|---|---|
| **`InsertDocumentModal`** | `isOpen, onClose, onInsert: String? Function(Map)`, `initialDoc?`, `isClone = false` | The tri-modal: insert / edit (`initialDoc != null && !isClone`) / **clone** (`isClone`). `maxWidth 576`. Title: `isEdit ? 'Edit Document' : 'Insert Document'`. JSON editor (`maxLines 12`, autofocus) prefilled via `JsonEncoder.withIndent('  ')`; "Generate New _id" action. **`_submit`**: `jsonDecode` → non-Map ⇒ `'Document must be a JSON object.'`; `final error = widget.onInsert(parsed)` — `null` = success → calls `onClose()`; non-null → shown in `CompassErrorBanner`, modal **stays open**. Footer label: `isEdit ? 'Save Changes' : (isClone ? 'Insert Document' : 'Insert')`. Parse exceptions ⇒ `'JSON Parse Error: $err'` |
| `DeleteDocumentModal` | `isOpen, onClose, onConfirm, dbName, collName, documentId, document?` | red header, warning box, `ObjectId("<id>")` row with copy→check icon swap, optional JSON preview, `Delete Document` danger button → `onConfirm(); onClose();` |
| `ImportExportModal` | `isOpen, onClose, mode: ImportExportMode{export,import}, dbName, collName, documents: List<MongoDocument>, onImportComplete` | `maxWidth 512`. Export: JSON/CSV format cards, CSV quoting, Copy to Clipboard / Download (`file_selector`), preview + status banner. Import: file picker (JSON only) + paste area (`maxLines 8`) → `mongoEngine.insertDocument` per item → `onImportComplete(); onClose()` |
| `SaveViewModal` | `isOpen, onClose, dbName, sourceCollName, pipeline, pipelineJsonString, onViewSaved: fn(String)` | auto-names `<coll>_view` (+4-digit suffix), validates (required, no `$`, no leading `.`, no clash), copies pipeline JSON to clipboard, `mongoEngine.createView(...)` |
| `ConnectionModal` | `isOpen, onClose, savedConnections, onConnect: Future<String?> fn, onSaveConnection, onDeleteConnection, onConnectSampleData` | **own overlay** (fixed width 560). URI + name + advanced fields (bi-directional URI sync via `_syncingUri` guard), "Local Sample Datasets" section (`Connect` → `onConnectSampleData`), saved connections list, footer Save & Connect / Connect. Default `mongodb://localhost:27017` |
| `MongoshConfirmationModal` | `isOpen, operation: RiskyOperationDetails?, onConfirm, onCancel` | **own overlay** (width 512). Keyboard-driven: Esc/N = cancel, Y = confirm, arrows/Tab select, Enter/Space execute; destructive confirm blocked for 200 ms after open (`_canConfirmDestructive`); defaults to cancel. Data class `RiskyOperationDetails {type, title, command, dbName, collName?, description, impact, filterPreview?, updatePreview?}` with `isDestructive`/`typeLabel` |
| `CreateCollectionModal` | `isOpen, onClose, databases, targetDbName, onCreated: fn(db, coll)` | target-DB pill selector, name input, collapsible Advanced Options (capped/collation check rows — hand-rolled 15×15 checkboxes). Validates empty/`$`/`system.`/dupes |
| `CreateIndexModal` | `isOpen, onClose, dbName, collName, onCreated` | Port of the modal React embeds *inside* `IndexesView`; in Flutter it is mounted in the root Stack (invariant #5) and driven by `_isCreateIndexModalOpen`. Field-name input + **pill selector** for direction (`1 (Ascending)` / `-1 (Descending)` / `text (Text Index)` — there is no dropdown primitive in the codebase) + hand-rolled unique checkbox (15×15, same as `CreateCollectionModal`). **`_submit`**: empty ⇒ `'Field name is required'`; name = `<field>_<direction>`, `keys = {field: 1 \| -1 \| 'text'}`; `mongoEngine.createIndex` ⇒ false ⇒ `'An index with this name or key pattern already exists'` (modal **stays open**); success ⇒ `onCreated(); onClose()`. State resets on open (`didUpdateWidget`) |
| `DropIndexModal` | `isOpen, onClose, onConfirm, dbName, collName, indexName` | Port of the React `confirm()` flow — Flutter has no browser confirm, so it is a danger modal following the `DeleteDocumentModal` pattern (red header, warning box, `INDEX NAME` card). `Cancel` / `Drop Index` → `onConfirm(); onClose()`; the engine call lives in `main.dart` (`_confirmDropIndex`). `_id_` never reaches it: the row shows "Protected" and the engine refuses `_id_` |
| `CreateDbModal` | `isOpen, onClose, onSubmit: fn(db, coll), defaultDbName, isCollectionOnly` | `isCollectionOnly` → "Create Collection in …" variant |
| `RenameModal` | `isOpen, onClose, type: RenameTarget{database,collection}, dbName, collName?, isView, onSuccess: fn(old, new, type)` | validates empty/identical, calls `mongoEngine.rename*` in try/catch → `CompassErrorBanner` |
| `DropDatabaseModal` | `isOpen, onClose, onConfirm, dbName, collectionsCount` | type-db-name-to-confirm + Auto-fill; danger button `onTap: null` until confirmed |
| `DropCollectionModal` | `isOpen, onClose, onConfirm, dbName, collName, documentCount, indexesCount, isView` | amber accent + "Drop View"/eye when `isView`, red otherwise; metadata card; type-name-to-confirm |
| `ExportLanguageModal` | `isOpen, onClose, dbName, collName, filter, sort` | **own overlay** (width 580). Language tabs `dart` (default, mongo_dart snippet) / `node` / `python`; generated-code box; single Done button. Used by query bar "Show Code" and aggregations "Export Code" |

## Document / collection views — `lib/widgets/views/`

| View | Props (callbacks) | Behavior |
|---|---|---|
| `DocumentTreeView` | `documents`, `onEditDocument(doc)`, `onCloneDocument(doc)`, `onDeleteDocument(docId, doc)` | Stateless. One card per doc: header `#<i+1>` + green `ObjectId("<id>")` badge + action strip — **copy → `onCloneDocument`**, pencil → edit, trash → delete. Body: recursive `_TreeNodeWidget`; chevron expandable for Object/Array, **collapsed by default at every depth** (deliberate deviation from the React reference, which expanded `depth < 2`); expanding a node starts its own children collapsed; BSON-colored type labels (`theme.bson*`); collapsed shows `{ ... }` / `[ ... n items ]`. Empty: "No documents match the current query" |
| `DocumentJsonView` | `documents`, `onUpdateDocument(docId, fields)`, `onCloneDocument`, `onDeleteDocument` | Stateful. Card per doc: `#n` + `_id` + copy/pencil/trash; body = pretty JSON. ⚠ **`onUpdateDocument` is never invoked** — `_editingId` only toggles the pencil color; inline edit is not implemented |
| `DocumentTableView` | `documents`, `onEditDocument`, `onDeleteDocument` | Horizontal-scroll table: `#` col (48px), dynamic columns from key union, `_id` first (220px, others 160px, header click client-side sorts), ACTIONS col (100px) pencil/trash. Rows 36px, BSON-styled cells. **No clone callback — no copy icon in table mode** |
| `SchemaView` | `dbName, collName` | **StatefulWidget** owning `fields` + `isAnalyzing`: auto-runs analysis on open / db-coll change and on **Analyze Schema** (250 ms `Timer` mirrors the React `setTimeout(…, 250)`; while running the button is disabled `Opacity 0.5` with label **Analyzing...**); reads `analyzeSchema` from the global `mongoEngine`. Header "Schema Analysis" + `Analyzed N unique fields in <coll>`; per-field cards: type badges with %, 8px multi-color distribution bar (incl. red missing segment), first-3 samples, min/max |
| `IndexesView` | `dbName, collName, indexes, onCreateIndex, onDropIndex(name)` | Header + **Create Index**; table `INDEX NAME / FIELDS & ORDER / PROPERTIES / SIZE / ACTIONS`; `_id_` row = shieldCheck "Protected" (no trash); `unique` → blue badge. Stateless — `onCreateIndex`/`onDropIndex` only open the root-Stack modals (`CreateIndexModal` / `DropIndexModal`), which mutate the engine; the table refreshes on the next `setState` because `indexes` is the live `activeColl.indexes` list |
| `AggregationsView` | `dbName, collName, onSaveAsView?: fn(pipeline, json), onExportCode?` | ~1300 lines / 47 KB. Classes: `AggregationPreset {id, name, description, stages}`; `_availableOperators = [$match,$group,$sort,$project,$limit,$skip,$unwind,$count,$lookup]`. State: `_activeMode ('visual'\|'raw')`, 3 seeded stages, per-stage controllers, `_rawController`, 5 presets (Match & Group, Unwind & Count, Top 10 Rated, Lookup Publishers, Count Documents), results (`_results`, `_executionTimeMs`, `_errorMessage`, `_isRunning`, `_resultViewMode 'json'\|'table'`). Auto-runs once post-frame in `initState` and on db/coll change. Sections: mode switcher + action bar (Run Pipeline / Save as View / Export Code), presets strip, visual builder (quick-add chips, Add Stage, stage cards with operator picker/enable/move/duplicate/delete; **content edits re-run the pipeline live**), raw editor (`CompassInput maxLines 14`), results panel (`n docs (x.x ms)` pill, JSON/Table switch, copy) |

## Chrome widgets — `lib/widgets/`

| Widget | Props & behavior |
|---|---|
| `CompassHeader` | `connection, onOpenConnectModal, onDisconnect, onResetData?, showResetSample = true, isTerminalOpen, onToggleTerminal, isDarkMode, onToggleDarkMode, onToggleMobileSidebar`. 56px bar: hamburger (mobile sidebar), mongoLeaf logo + "Compass Flutter" + 7.0.8 badge → connect modal, connection pill (or amber Connect), **Reset Samples** (only when `showResetSample` — passed as `_realService == null`), mongosh terminal toggle, **theme toggle showing `sun` when dark / `moon` when light**, Disconnect/Connect. Note: `isDarkMode` is a **constructor param**, not read from `CompassTheme` |
| `CompassSidebar` | 256px. Props: `databases, selectedDb, selectedColl, onSelectCollection, onSelectDatabase, onOpenCreateDb, onOpenCreateColl, onRenameDb, onRenameColl, onDropDb, onDropColl, onRefresh`. Sections: header (refresh + create-DB icons, search box — ⚠ **display-only, `_searchQuery` is final `''` (dead code)**), DB tree (chevron toggles `_expandedDbs`, **pre-seeded `library:true`, `social_networks:true`**; row tap → `onSelectDatabase` + auto-expand; trailing plus/pencil/trash; collections show doc counts, amber eye for views), footer Create Database button |
| `CompassQueryBar` | `options: QueryFilterOptions, onChangeOptions(fn), onExecuteQuery, onResetQuery, onExportToLanguage, executionTimeMs?, totalResultsCount?`. **Uses its own `EditableText`** (not `CompassInput`) wrapped in `Visibility(maintainState/maintainSize)` so the element identity survives empty↔non-empty (documented fix for test 2). FILTER field with lenient auto-quoting validation + amber/green status icon, Enter → find; Options toggle expands PROJECT/SORT/SKIP/LIMIT fields (each reports `options.copyWith(...)`, skip clamps ≥0, limit ≥1); Reset / Show Code / **Find** buttons; stats ribbon `Matches: n · Time: xms` |
| `CollectionTabBar` | 36px strip. `tabs, activeIndex, onSelect(i), onClose(i)`. Tabs `minWidth 140/maxWidth 200`, active = `bgSubtle` + 2px accent bottom border; icon = `table` (or `database` when coll name empty); close = `CompassSvg(close, 11)`; right counter `'<n> open'`; active tab auto-revealed via `Scrollable.ensureVisible` post-frame |
| `CompassTerminal` | Docked mongosh-like drawer. `isOpen, onClose, activeDbName, onExecuteCommand?, onRequestConfirmation?`. `SizedBox.shrink()` when closed; heights 220/380; hardcoded dark palette. Input line `<db>> ` + `EditableText`; `_simulateOutput` fakes `help`/`show dbs`/`show collections`/`db.*`/`use *`; `_detectRisky(command)` (regexes for `dropDatabase`, `drop/deleteMany/remove/deleteOne/updateMany/updateOne(`) → `RiskyOperationDetails` → deferred until confirmed via `onRequestConfirmation` |

## Icons — `lib/icons/compass_svg_icons.dart`

- **`CompassSvg extends StatelessWidget`** — defined in the *same file* (L6):
  `{required String svgString, double size = 14, Color? color}` → `SvgPicture.string(...)`
  with optional `ColorFilter`. The only icon renderer in the app.
- **`CompassSvgIcons`** — 33 `static const String` raw SVG literals (mostly 24×24 viewBox,
  `stroke="currentColor"`): `mongoLeaf, terminal, search, sliders, rotateCcw, database,
  table, code, layers, barChart, key, shieldCheck, activity, plus, trash, copy, file,
  upload, download, check, pencil, eye, chevronDown, chevronLeft, chevronRight, chevronUp,
  close, play, menu, sun, moon, zap, arrowUpDown`.
- Usage: `CompassSvg(svgString: CompassSvgIcons.<name>, size: <px>, color: <theme color>)`.
  Tests find icons via `find.byWidgetPredicate((w) => w is CompassSvg && w.svgString ==
  CompassSvgIcons.<name>)` (`svgString` is a public field).

## Theme — `lib/theme/`

### `compass_theme.dart` — `CompassTheme extends InheritedWidget`

- Single field `final bool isDarkMode`. `static CompassTheme of(context)` →
  `dependOnInheritedWidgetOfExactType<CompassTheme>() ?? const CompassTheme(isDarkMode:
  true, child: SizedBox.shrink())` — **fail-safe dark fallback** (silently dark if asked
  above the provider — that's the `main.dart` trap, see AGENTS.md invariant 11).
- Extra named ctor `const CompassTheme.palette(this.isDarkMode)` (child = shrink) for
  palette lookups above the provider: `main.dart` uses
  `CompassTheme get _theme => CompassTheme.palette(_isDarkMode);`.
- Propagation: `_CompassAppState._isDarkMode` (default `true`) → root wrap
  `CompassTheme(isDarkMode: _isDarkMode, child: content)` → header toggle flips it in
  `setState` (and updates `SystemUiOverlayStyle`).
- Widgets read **resolved color getters** (never branch on the bool themselves):
  `bgApp, bgSidebar, bgPanel, bgSubtle, bgHover, bgInput, border, borderHover, textPrimary,
  textSecondary, textMuted, accent` (greenAccent dark / greenForest light), `onAccent`,
  `greenBadgeBg, greenBadgeBorder`, and BSON syntax colors `bsonObjectId, bsonString,
  bsonNumber, bsonBoolean, bsonDate, bsonNull` — each `isDarkMode ? dark : light`.

### `compass_colors.dart` — `CompassColors`

Static `const Color` tokens only, no logic: dark palette (`darkBgApp 0xFF0C1014`,
`darkBgSidebar/darkBgPanel 0xFF11161B`, subtle/hover/input/border/text variants), greens
(`greenAccent 0xFF00ED64`, `greenHover`, `greenForest 0xFF00684A`, `greenDeep`,
`greenNavy 0xFF001E2B`), badge tokens (dark + light), full light palette
(`lightBgApp 0xFFF9FBFA` …), semantic (`errorRed/errorRedBg/errorRedBorder`,
`warningAmber*`, `infoBlue*`), `purpleBadge`, `cyanBadge`, BSON dark + light sets,
`scrollbarThumb/Hover`, `modalOverlay 0x99000000`.

### `compass_typography.dart` — `CompassTypography`

Static factories returning plain `TextStyle` (no `ThemeData`):
`fontSans = 'Plus Jakarta Sans'`, `fontMono = 'JetBrains Mono'`. Sans: `title` (14/w700),
`header` (13/w600), `bodyMedium` (12/w500), `bodyRegular` (12/w400), `caption` (11),
`badge` (10/w600). Mono: `monoBold/monoMedium/monoRegular({Color color, double size = 12})`,
`monoSmall` (11), `queryInput` (12), `terminal` (12, height 1.5).

⚠ `google_fonts` is in pubspec but **never imported**; no font files ship — families fall
back at runtime if the OS lacks them.

## Recipe: adding a new view/section

1. Create `lib/widgets/views/<name>_view.dart` (Stateless/StatefulWidget, no Material);
   required props for target db/coll + data + callbacks; theme via `CompassTheme.of(context)`,
   styles via `CompassTypography`, icons via `CompassSvg`.
2. In `main.dart` `_buildCollectionHeader`: add a `_buildTab('<key>', '<Title>', icon)` call.
3. In `main.dart` `_buildActiveTabView`: add `case '<key>'` returning your view with the
   engine-derived data (`service.findDocuments(...)` already ran at the top of `build()`).
4. Remember: the section key is stored per-tab in `CollectionTab.activeSection`.
5. Add a test (e.g. extend the light-mode section walk in test 10) — see `docs/testing.md`.
