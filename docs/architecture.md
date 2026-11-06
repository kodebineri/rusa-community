# Architecture — App Shell & `lib/main.dart`

Companion to root `AGENTS.md`. Covers the Flutter app shell: bootstrap, state, navigation,
tabs, document CRUD, modal orchestration, and the `build()` layout tree.
For the data layer see `docs/engine.md`; for widgets see `docs/ui.md`.

`lib/main.dart` ≈ 1997 lines — a single `StatefulWidget` file containing the entire
app shell. Line numbers below are approximate anchors; they drift as the file changes.

## Bootstrap

```dart
void main() => runApp(const DefaultTextEditingShortcuts(child: CompassApp()));
```

- **No `MaterialApp`/`WidgetsApp`**, so no default text-editing shortcuts would be installed.
  `DefaultTextEditingShortcuts` is load-bearing: inputs are bare `EditableText`
  (`CompassInput`), which accepts typed characters but ignores Backspace/arrows/Home/End/
  Ctrl+C/V without it. (Test 3 exists specifically for this.)
- No `Navigator`, no routing. There is exactly **one** `GlobalKey`: `_overlayKey`
  (`GlobalKey<OverlayState>`), because `CompassApp` hosts its own `Overlay` (there is no
  `WidgetsApp` to provide one). `_showInfoDialog` inserts an `OverlayEntry` through it.
- Root build wrap order (outermost → innermost):
  `AnnotatedRegion<SystemUiOverlayStyle>` (transparent status bar, brightness from the variant)
  → `CompassTheme(variant: _themeVariant, …)` → manual `MediaQuery` fallback
  (`MediaQuery.fromView` if none) → `Directionality(ltr)` → `TapRegionSurface`
  → `Overlay(key: _overlayKey, clipBehavior: Clip.none, initialEntries: [_shellEntry])`.
  The shell itself (built by `_shellEntry` → `_buildShell(context)`) is
  `LayoutBuilder` → `Container(bgApp)` → **`Stack`** (content column + all modal/action-sheet
  overlays) → `CompassDensity.forWidth(width: …)` (innermost: touch vs desktop metrics).
- Why `TapRegionSurface` + `Overlay` + `clipBehavior: Clip.none`: they are what `WidgetsApp`
  would normally supply. The custom copy/paste menu (`compass_text_menu.dart`) lives in the
  overlay and must count as part of the field's tap region (dismissal) and be allowed to paint
  past the window edge (it is anchored to the field).
- Breakpoint: `isDesktop = constraints.maxWidth >= 768` (sidebar is off-canvas below it).
- **Density is width-driven, not platform-driven**: `flutter_test` forces
  `TargetPlatform.android`, so a platform check would put the 1920 px test viewport into
  the touch profile. `CompassDensity.touchBreakpoint` is also 768.

## State fields of `_CompassAppState`

> Naming trap: the section field is **`_activeTab`**, the tab index is **`_activeTabIndex`**.
> There is no `_activeSection`/`_activeTabId`.

**Theme / connection (L220–231)**

| Field | Type | Purpose |
|---|---|---|
| `_themeVariant` | `CompassThemeVariant = .defaultVariant` (Dracula) | selected theme; drives `_theme` + root `CompassTheme`; changed via header menu / action sheet |
| `_connection` | `ConnectionProfile?` | current profile; **null at boot** (the connect popup is open), set on connect / sample-data, cleared on disconnect |
| `_realService` | `RealMongoService?` | non-null only while on a live server; also gates header `showResetSample` |
| `_savedConnections` | `List<ConnectionProfile>` | two seeded profiles (`1` "Local Standalone (27017)", `2` "Atlas Production ReplicaSet") |

**Panel flags (L229–243):** `_isConnectModalOpen` (**defaults to `true`** — the app boots into
the connection popup), `_isTerminalOpen` (docked mongosh shell), `_isMobileSidebarOpen`
(off-canvas sidebar < 768px), `_isHeaderActionsOpen` (touch-only header overflow sheet),
`_isEulaModalOpen`, `_isAboutModalOpen`, `_isPrivacyPolicyModalOpen`, `_isQueryActionsOpen` (touch-only query-bar overflow
sheet), `_isQueryOptionsExpanded` (query-bar options panel; owned here so the overflow sheet
can toggle it), `_eulaAccepted` (`bool?` — first-run consent flag: `null` = still loading,
`false` = not accepted, `true` = accepted), `_onboardingDone` (the tour's "don't show this
again" choice) and `_isOnboardingOpen` (the welcome tour is covering the app).

**Layout flags (refreshed by the root `LayoutBuilder` on every layout pass):**

| Field | Type | Purpose |
|---|---|---|
| `_isTouchLayout` | `bool` | `!isDesktop` — below the 768 px breakpoint |
| `_windowWidth` | `double` | viewport width in logical pixels |
| `_isCompactLayout` | `bool` (getter) | `_windowWidth < 900` — the labelled chrome collapses into icon buttons |

**Modal state — flag + payload pairs (L276–323):**

| Modal group | Fields |
|---|---|
| Create DB | `_isCreateDbModalOpen` |
| Create Collection | `_isCreateCollModalOpen`, `_createCollTargetDb` |
| Create Index | `_isCreateIndexModalOpen` |
| Rename | `_isRenameModalOpen`, `_renameType` (`RenameTarget`), `_renameDbName`, `_renameCollName?`, `_renameIsView` |
| Drop DB | `_isDropDbModalOpen`, `_dropDbName` |
| Drop Collection | `_isDropCollModalOpen`, `_dropCollDbName`, `_dropCollName`, `_dropCollIsView`, `_dropCollDocCount`, `_dropCollIndexesCount` |
| Drop Index | `_isDropIndexModalOpen`, `_dropIndexName` |
| Delete Doc | `_isDeleteDocModalOpen`, `_deleteDocId`, `_deleteDocTarget` (`MongoDocument?`) |
| Insert/Edit/Clone Doc | `_isInsertDocModalOpen`, `_editingDoc?`, `_clonedDoc?` (clone set only by duplicate action) |
| Import/Export | `_isImportExportModalOpen`, `_importExportMode` |
| Save View | `_isSaveViewModalOpen`, `_saveViewPipeline`, `_saveViewPipelineJson` |
| Terminal confirm | `_pendingTerminalOperation?`, `_pendingTerminalConfirm?` (derived `isOpen`) |

**Selection / section / view (L325–347):** `_selectedDbName = 'library'`,
`_selectedCollName = 'books'`, `_activeTab = 'documents'`
(`documents|aggregations|schema|indexes`), `_docViewMode = 'tree'` (`tree|json|table`),
`_queryOptions: QueryFilterOptions` (mutable; `filter/project/sort/skip=0/limit=20`).

**Tabs (L331–347):** `_openTabs: List<CollectionTab>` seeded with
`[CollectionTab('library','books')]`, `_activeTabIndex = 0` (`-1` = none/sentinel).

**Not a state field:** `mongoEngine` is a mutable *top-level global* in
`lib/services/mongo_engine.dart`. Assigned during connect/disconnect inside `setState`.

State initializes via field initializers; the only `initState` reads the stored flags
(`_loadPreferences` → `appPreferences.load()`: consent, tour, theme). The shell lays out
`library.books` Documents/tree with an empty query on the local engine immediately, but on
first launch it is covered by the **welcome tour** (`OnboardingModal`, whose last slide is the
EULA acceptance). While the flags load, `_eulaAccepted` is `null` and a blank cover hides
everything. `_loadPreferences` then decides what covers the app: the tour
(`_isOnboardingOpen = true`, and the **connection popup stays closed** so the user lands on the
sample data) or, for a returning user, the **connection popup** (`_isConnectModalOpen = true`).

## Layout tree — `build()` (~L1381) hosts `_buildShell()` (~L940) in an `OverlayEntry`

`build()` only stacks the root wrappers (see "Bootstrap"); the shell is `_shellEntry`
(`OverlayEntry(builder: _buildShell)`), installed as the root `Overlay`'s first entry.

```
Shell Stack
├─ Column
│  1. CompassHeader                     (56px; connection, Reset Samples, terminal toggle, theme menu)
│  2. Expanded > Row
│     ├ CompassSidebar                  (if isDesktop || _isMobileSidebarOpen)
│     └ Expanded > Column
│        ├ CollectionTabBar             (if _openTabs.isNotEmpty)
│        ├ _buildCollectionHeader       (breadcrumbs + section tabs + Insert/Import/Export) — if tab open
│        ├ CompassQueryBar              (if tab open && _activeTab == 'documents')
│        ├ _buildDocumentsPagination    (Tree/JSON/Table switcher + Prev/Next) — same condition
│        └ Expanded > SingleChildScrollView(16) > _buildActiveTabView(...)
│  3. CompassTerminal                   (docked mongosh drawer; the only "footer" region)
└─ 16 modal overlays + TWO CompassActionSheet overlays (header actions, query actions)
   (always-installed children; each closed one renders SizedBox.shrink)
   + the conditionally-rendered first-run welcome tour (blank cover while the flags load,
     then OnboardingModal) as the LAST child, so it paints above everything until finished
```

Data derived at the top of `_buildShell()` (~L947–953), all synchronous:

```dart
service = mongoEngine
queryResult = service.findDocuments(db, coll, _queryOptions)  // filtered + paged
pageDocs   = queryResult.documents                            // fed to the docs views
```

**There is no explicit refresh call anywhere.** Every `setState` re-runs `build()`, which
re-queries the engine. Refresh triggers: query-bar `onExecuteQuery`, sidebar `onRefresh`,
import `onImportComplete`, index create/drop (`onCreated` / `_confirmDropIndex`), and
`RealMongoService.onDataChanged`. **Exception:** the schema
section no longer derives data in `build()` — `SchemaView` owns its analysis and re-runs
`analyzeSchema` itself (on open, on db/coll change, and via its Analyze button).

### `_buildActiveTabView` (~L1927–1997)

- `activeColl == null` → centered "Select a collection to view data".
- `documents`: empty → `_buildDocumentsEmptyState` (Insert First Document button, hidden for
  views); else `_docViewMode` picks `DocumentTreeView` / `DocumentJsonView` /
  `DocumentTableView`:
  - tree: `onEditDocument: _openEditDocument`, `onCloneDocument: _handleCloneDocument`,
    `onDeleteDocument: _requestDeleteDocument`
  - json: `onUpdateDocument: _handleUpdateDocument`, clone, delete
  - table: edit + delete only (**no clone callback** — table view has no copy icon)
- `aggregations` → `AggregationsView(db, coll, onSaveAsView: _openSaveView, initialPipeline: _pendingAggregationPipeline)`.
  For a **view**, `coll` is the view's source (`viewOn`) and `initialPipeline` is the view's own
  DDL, so the Aggregations tab shows the view's current data instead of re-applying the pipeline
  to the view's output; `_ensureAggregationTargetLoaded` (on tab select) and `_copyViewToAggregations`
  (Copy to Aggregations) both load the source's documents on a live server.
- `schema` → `SchemaView(db, coll)` — stateful; no callbacks (it runs `analyzeSchema` via the
  global `mongoEngine` itself, see `docs/ui.md`)
- `indexes` → `IndexesView(db, coll, indexes: activeColl.indexes, onCreateIndex: () => setState(…), onDropIndex: (name) => setState(…))`
  — both callbacks are now wired: they only flip `_isCreateIndexModalOpen` / set
  `_dropIndexName` + `_isDropIndexModalOpen`, which open `CreateIndexModal` / `DropIndexModal`
  from the root `Stack`. The engine mutations happen in the modal (`createIndex`) and in
  `_confirmDropIndex` (`dropIndex`); the table re-reads the live `activeColl.indexes` list on
  the next `setState`. See `docs/ui.md`.
- `ddl` → `ShowDdlView(db, coll, viewOn, pipeline, onUpdateView, onCopyToAggregations)` — **only
  for views**; the "Show DDL" tab is rendered after `indexes` only when `activeColl.isView`.
  `onUpdateView` calls `mongoEngine.updateView` (drop + recreate), `onCopyToAggregations` sets
  `_pendingAggregationPipeline` and switches to the `aggregations` tab.

### Collection header (`_buildCollectionHeader`, ~L1436–1594)

- Breadcrumb row: db icon + db name + `>` + table icon + coll name + "N docs" chip;
  right side header actions (`_buildHeaderAction`): New Coll, Rename (eye icon for views),
  Drop. The breadcrumb names ellipsize (`Flexible` + `TextOverflow.ellipsis`) and the "N docs"
  chip is hidden on touch.
- Section tabs Row: left = `_buildTab(tabKey, title, svg)` for
  documents/aggregations/schema/indexes → `setState(() => _activeTab = tabKey)`.
- Right actions gated on `_activeTab == 'documents' && activeColl != null`:
  amber **Read-Only View** badge when `activeColl.isView`, otherwise
  **Insert Document** primary button → `_openInsertDocument`; then Import / Export buttons.
- **Narrow-window behaviour:** `_buildHeaderAction` returns a `CompassIconButton` instead of
  a labelled chip when `_isCompactLayout` (< 900 px); `_buildDocumentsAction` does the same
  for the Insert Document button and the Read-Only badge. On desktop the labels stay.

### Pagination (`_buildDocumentsPagination`, ~L1766–1859)

Left = segmented Tree/JSON/Table switcher (`_buildViewModeBtn` → `_docViewMode`).
Right = `"start – end of total"` label + Prev/Next buttons that do
`_queryOptions = _queryOptions.copyWith(skip: …)` — **`limit` doubles as page size**
(default 20). Prev clamps at 0; Next adds `pageSize`, disabled when exhausted.
On touch the whole bar becomes a horizontal `SingleChildScrollView` (the switcher, the
label and the pager no longer fit on one phone-width line).

## Tab management (~L349–447)

`CollectionTab` (see `lib/models/collection_tab.dart`) stores per-tab UI state: `dbName`,
`collName`, `activeSection` (default `'documents'`), `docViewMode` (default `'tree'`),
`queryOptions`.

- `_saveActiveTabState()` — writes live `_activeTab`/`_docViewMode`/`_queryOptions` into
  `_openTabs[_activeTabIndex]`. Called before every tab switch/close.
- `_activateTabIndex(i)` — save current, set index, restore all live fields from the tab.
- `_openCollectionTab(db, coll)` — browser-like: focuses an existing tab with the same target
  (`isSameTarget`), else appends + activates.
- `_removeTabAt(i)` — sets `_activeTabIndex = -1` **first** (sentinel so `_activateTabIndex`
  doesn't save live state into the tab being removed), then activates a neighbor; empty list
  → clears selection, resets `_activeTab='documents'`, `_docViewMode='tree'`, fresh
  `QueryFilterOptions()`.
- `_closeTabsMatching(predicate)` — collects matching indices in reverse **before** removing
  (used by drop db/coll and terminal commands).
- `_resetTabsTo(db, coll)` — clear + one fresh tab (used after connect/reset/disconnect).

**Nuance:** live query edits replace the `_queryOptions` *instance*, while the tab still
holds the old reference — synced only when `_saveActiveTabState()` runs. Renames mutate tab
fields in place.

## Document CRUD handlers (~L667–753)

| Handler | Behavior |
|---|---|
| `_openInsertDocument()` | clears `_editingDoc` **and** `_clonedDoc`, opens modal |
| `_openEditDocument(doc)` | clears `_clonedDoc`, sets `_editingDoc = Map.from(doc.data)`, opens modal |
| `_handleInsertDocument(doc) → String?` | **core rule:** update iff `_editingDoc != null && _clonedDoc == null`, else insert. `catch (err) → return '$err'` (e.g. E11000). Success → clears both fields, returns `null`. **Never closes the modal** — `InsertDocumentModal._submit` closes it only when `onInsert` returned `null`, otherwise shows the banner |
| `_handleCloneDocument(doc)` | `_editingDoc = null`; `_clonedDoc = Map.from(doc.data)..['_id'] = mongoEngine.generateObjectId()`; opens modal. Clone always inserts |
| `_requestDeleteDocument(id, doc)` | resolves doc if null, opens delete modal |
| `_confirmDeleteDocument()` | `mongoEngine.deleteDocument(...)`, clears payload (payload is NOT cleared by modal `onClose`) |
| `_handleUpdateDocument(id, fields)` | direct `updateDocument` in try/catch that swallows errors + `setState` (used by the JSON view's inline editor) |

`InsertDocumentModal` instantiation in the Stack (~L1214–1223):

```dart
InsertDocumentModal(
  isOpen: _isInsertDocModalOpen,
  onInsert: _handleInsertDocument,
  initialDoc: _editingDoc ?? _clonedDoc,
  isClone: _clonedDoc != null,
  onClose: () => setState(() { _isInsertDocModalOpen = false; _clonedDoc = null; }),
)
```

Note: `onClose` does **not** clear `_editingDoc` (only `_openInsertDocument`,
`_openEditDocument`, and a successful `_handleInsertDocument` do).

## Modal orchestration

All modals are permanently installed children of the root `Stack` (~L1123–1367), each with an
`isOpen` boolean; `CompassModalShell` returns `SizedBox.shrink()` when closed (invariant 5 in
AGENTS.md). Order: Connection, CreateDb, CreateCollection, **CreateIndex**, Rename,
DropDatabase, DropCollection, **DropIndex**, **Eula**, **Privacy Policy**, **About**, DeleteDocument,
**InsertDocument**, ImportExport, ExportLanguage, SaveView, MongoshConfirmation
(`isOpen: _pendingTerminalOperation != null`).

Two modals hand-roll their own `Positioned.fill` overlay instead of `CompassModalShell`:
`ConnectionModal` (fixed width 560), `MongoshConfirmationModal` (width 512).

**Two** `CompassActionSheet` overlays are installed after them:

- header actions (`_isHeaderActionsOpen`) — opened from the header's `⋮` via `onOpenActions`:
  change connection / reset samples / `_mongosh` / disconnect / **theme picker** / Report Bug /
  EULA / About.
- query actions (`_isQueryActionsOpen`) — opened from the query bar's `onOpenOverflow`: toggle
  the options panel (`_isQueryOptionsExpanded`) / reset query / show generated code.

Both are root-`Stack` children (a `Positioned.fill` sheet hosted inside a widget would be
squeezed into a sliver).

Separately, the **first-run welcome tour** (`OnboardingModal`) is *conditionally* rendered as
the last `Stack` child while `_isOnboardingOpen` (with a blank `ColoredBox` cover while the
flags are still `null`). It is **not** one of the 16 permanently-installed modals: finishing it
(`_finishOnboarding`) persists consent + the "don't show this again" choice and reveals the
shell on the sample data (no connect popup).

Payload-clearing asymmetry to remember: most `onClose` closures only flip the boolean;
delete payload clears on confirm; insert payload (`_editingDoc`) clears on open/success.

## Connection flow (~L449–551)

- `_handleConnectProfile(profile)` → `RealMongoService.connect(profile.uri)` (async),
  `mongoEngine = connected`, `_resetTabsTo(firstDbWithCollections, firstColl)`,
  `onDataChanged → setState`, `onError → debugPrint`. On failure: `_formatConnectError`.
- `_handleConnectSampleData()` → load local sample datasets, back to
  `LocalMongoEngine.instance`, reset tabs to `library/books`.
- `_handleDisconnect()` → dispose service, `mongoEngine = LocalMongoEngine.instance`,
  reset tabs.
- `_handleResetData()` → for `RealMongoService`: `engine.resetToDefaults()` (which *reloads
  from server*) and returns **without setState** (relies on `onDataChanged`); for local:
  re-seed + `_resetTabsTo('library','books')`.
- Header `showResetSample: _realService == null` — Reset Samples hidden on live connections.

## Terminal / mongosh (~L817–920, terminal widget at L1110)

`CompassTerminal` (docked bottom drawer) → `onRequestConfirmation: _requestTerminalConfirmation`
→ sets `_pendingTerminalOperation`/`_pendingTerminalConfirm` → `MongoshConfirmationModal`.
`_executeTerminalCommand` recognizes only a regex subset: `db.dropDatabase()`,
`db.<coll>.drop/deleteMany/remove/deleteOne/updateMany/updateOne/insertOne`.
Helpers: `_splitArgs` (bracket-depth aware), `_parseMap`.

## Line map of `main.dart` (approximate)

| Range | Section |
|---|---|
| 48–54 | `main()` + DefaultTextEditingShortcuts rationale |
| 55–67 | `CompassApp` + porting-constraint doc comment |
| 69–218 | state class head: `_overlayKey`, `_showInfoDialog`, Report-Bug helpers (`_bugReportUri` 185) |
| 220–323 | theme/connection fields + panel/modal flags |
| 325–347 | selection/section/view + tab seed |
| 349–447 | tab handlers |
| 449–551 | connection handlers (`_handleConnectProfile` 455) |
| 554–665 | db/collection/index modal handlers (create/rename/drop/drop-index) |
| 667–753 | document CRUD |
| 755–815 | import/export/language/save-view/reset/disconnect/terminal confirm |
| 817–920 | `_executeTerminalCommand` + arg helpers |
| 922 | `_theme` palette getter (workaround) |
| 924–937 | `_shellEntry` (`OverlayEntry(builder: _buildShell)`) |
| 940–1379 | `_buildShell()` (header ~963, sidebar ~1003, main pane ~1039, terminal ~1110, overlays ~1123–1367) |
| 1381–1434 | `build()` root wrappers (AnnotatedRegion → CompassTheme → MediaQuery → Directionality → TapRegionSurface → Overlay) |
| 1436–1594 | `_buildCollectionHeader` |
| 1596–1648 | `_buildDocumentsAction` (Insert Document / Read-Only badge) |
| 1650–1684 | `_buildTab` |
| 1686–1726 | `_buildHeaderAction` |
| 1728–1764 | `_buildViewModeBtn` |
| 1766–1859 | `_buildDocumentsPagination` |
| 1861–1876 | `_buildPageButton` |
| 1878–1925 | `_buildDocumentsEmptyState` |
| 1927–1997 | `_buildActiveTabView` |

## Recipe: adding a new modal

1. Create `lib/widgets/modals/<name>_modal.dart` using `CompassModalShell` +
   `CompassModalHeader` + `CompassModalFooter` (see `docs/ui.md`); props always include
   `bool isOpen` + `VoidCallback onClose`; reset controllers in `didUpdateWidget` when
   `isOpen` flips false→true.
2. In `main.dart`: add `_is<Name>ModalOpen` flag (+ payload fields) near L276–323.
3. Add an `_open…` setter and a `_confirm…`/`_handle…` callback near the related handlers.
4. Instantiate it once in the root `Stack` (~L1123–1367) with `isOpen`/`onClose`.
5. Add a widget test if behavior matters — see `docs/testing.md`.
