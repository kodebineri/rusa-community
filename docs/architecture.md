# Architecture — App Shell & `lib/main.dart`

Companion to root `AGENTS.md`. Covers the Flutter app shell: bootstrap, state, navigation,
tabs, document CRUD, modal orchestration, and the `build()` layout tree.
For the data layer see `docs/engine.md`; for widgets see `docs/ui.md`.

`lib/main.dart` ≈ 1488 lines, 55 KB — a single `StatefulWidget` file containing the entire
app shell. Line numbers below are approximate anchors; they drift as the file changes.

## Bootstrap

```dart
void main() => runApp(const DefaultTextEditingShortcuts(child: CompassApp()));
```

- **No `MaterialApp`/`WidgetsApp`**, so no default text-editing shortcuts would be installed.
  `DefaultTextEditingShortcuts` is load-bearing: inputs are bare `EditableText`
  (`CompassInput`), which accepts typed characters but ignores Backspace/arrows/Home/End/
  Ctrl+C/V without it. (Test 3 exists specifically for this.)
- No `Navigator`, no routing, no `GlobalKey`s anywhere in `main.dart`.
- Root build wrap order (outermost → innermost):
  `AnnotatedRegion<SystemUiOverlayStyle>` (transparent status bar, brightness from dark mode)
  → `CompassTheme(isDarkMode: _isDarkMode, …)` → manual `MediaQuery` fallback
  (`MediaQuery.fromView` if none) → `Directionality(ltr)` → `LayoutBuilder`
  → `Container(bgApp)` → **`Stack`** (content column + all modal overlays).
- Breakpoint: `isDesktop = constraints.maxWidth >= 768` (sidebar is off-canvas below it).

## State fields of `_CompassAppState`

> Naming trap: the section field is **`_activeTab`**, the tab index is **`_activeTabIndex`**.
> There is no `_activeSection`/`_activeTabId`.

**Theme / connection (L60–90)**

| Field | Type | Purpose |
|---|---|---|
| `_isDarkMode` | `bool = true` | dark default; drives `_theme` + root `CompassTheme` |
| `_connection` | `ConnectionProfile?` | current profile (seeded "Local Standalone"); null after disconnect |
| `_realService` | `RealMongoService?` | non-null only while on a live server; also gates header `showResetSample` |
| `_savedConnections` | `List<ConnectionProfile>` | two seeded profiles (Local Standalone, Atlas Production) |

**Panel flags (L74–76):** `_isConnectModalOpen`, `_isTerminalOpen` (docked mongosh shell),
`_isMobileSidebarOpen` (off-canvas sidebar < 768px).

**Modal state — flag + payload pairs (L95–142):**

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
| Export → Language | `_isExportLangModalOpen` |
| Save View | `_isSaveViewModalOpen`, `_saveViewPipeline`, `_saveViewPipelineJson` |
| Terminal confirm | `_pendingTerminalOperation?`, `_pendingTerminalConfirm?` (derived `isOpen`) |

**Selection / section / view (L144–149):** `_selectedDbName = 'library'`,
`_selectedCollName = 'books'`, `_activeTab = 'documents'`
(`documents|aggregations|schema|indexes`), `_docViewMode = 'tree'` (`tree|json|table`),
`_queryOptions: QueryFilterOptions` (mutable; `filter/project/sort/skip=0/limit=20`).

**Tabs (L157–160):** `_openTabs: List<CollectionTab>` seeded with
`[CollectionTab('library','books')]`, `_activeTabIndex = 0` (`-1` = none/sentinel).

**Not a state field:** `mongoEngine` is a mutable *top-level global* in
`lib/services/mongo_engine.dart`. Assigned during connect/disconnect inside `setState`.

There is **no `initState`** — everything initializes via field initializers, so the app boots
straight into `library.books` Documents/tree with empty query on the local engine.

## Layout tree of `build()` (~L706–1024)

```
Stack
├─ Column
│  1. CompassHeader                     (56px; connection, Reset Samples, terminal toggle, dark toggle)
│  2. Expanded > Row
│     ├ CompassSidebar                  (if isDesktop || _isMobileSidebarOpen)
│     └ Expanded > Column
│        ├ CollectionTabBar             (if _openTabs.isNotEmpty)
│        ├ _buildCollectionHeader       (breadcrumbs + section tabs + Insert/Import/Export) — if tab open
│        ├ CompassQueryBar              (if tab open && _activeTab == 'documents')
│        ├ _buildDocumentsPagination    (Tree/JSON/Table switcher + Prev/Next) — same condition
│        └ Expanded > SingleChildScrollView(16) > _buildActiveTabView(...)
│  3. CompassTerminal                   (docked mongosh drawer; the only "footer" region)
└─ 14 modal overlays (always-installed children; each closed one renders SizedBox.shrink)
```

Data derived at the top of `build()` (~L713–719), all synchronous:

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

### `_buildActiveTabView` (~L1444–1513)

- `activeColl == null` → centered "Select a collection to view data".
- `documents`: empty → `_buildDocumentsEmptyState` (Insert First Document button, hidden for
  views); else `_docViewMode` picks `DocumentTreeView` / `DocumentJsonView` /
  `DocumentTableView`:
  - tree: `onEditDocument: _openEditDocument`, `onCloneDocument: _handleCloneDocument`,
    `onDeleteDocument: _requestDeleteDocument`
  - json: `onUpdateDocument: _handleUpdateDocument`, clone, delete
  - table: edit + delete only (**no clone callback** — table view has no copy icon)
- `aggregations` → `AggregationsView(db, coll, onSaveAsView: _openSaveView, onExportCode: _openExportLanguage)`
- `schema` → `SchemaView(db, coll)` — stateful; no callbacks (it runs `analyzeSchema` via the
  global `mongoEngine` itself, see `docs/ui.md`)
- `indexes` → `IndexesView(db, coll, indexes: activeColl.indexes, onCreateIndex: () => setState(…), onDropIndex: (name) => setState(…))`
  — both callbacks are now wired: they only flip `_isCreateIndexModalOpen` / set
  `_dropIndexName` + `_isDropIndexModalOpen`, which open `CreateIndexModal` / `DropIndexModal`
  from the root `Stack`. The engine mutations happen in the modal (`createIndex`) and in
  `_confirmDropIndex` (`dropIndex`); the table re-reads the live `activeColl.indexes` list on
  the next `setState`. See `docs/ui.md`.

### Collection header (`_buildCollectionHeader`, ~L1026–1193)

- Breadcrumb row: db icon + db name + `>` + table icon + coll name + "N docs" chip;
  right side header actions (`_buildHeaderAction`): New Coll, Rename (eye icon for views),
  Drop.
- Section tabs Row: left = `_buildTab(tabKey, title, svg)` for
  documents/aggregations/schema/indexes → `setState(() => _activeTab = tabKey)`.
- Right actions gated on `_activeTab == 'documents' && activeColl != null`:
  amber **Read-Only View** badge when `activeColl.isView`, otherwise
  **Insert Document** primary button → `_openInsertDocument`; then Import / Export buttons.

### Pagination (`_buildDocumentsPagination`, ~L1298–1373)

Left = segmented Tree/JSON/Table switcher (`_buildViewModeBtn` → `_docViewMode`).
Right = `"start – end of total"` label + Prev/Next buttons that do
`_queryOptions = _queryOptions.copyWith(skip: …)` — **`limit` doubles as page size**
(default 20). Prev clamps at 0; Next adds `pageSize`, disabled when exhausted.

## Tab management (~L168–249)

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

## Document CRUD handlers (~L471–557)

| Handler | Behavior |
|---|---|
| `_openInsertDocument()` | clears `_editingDoc` **and** `_clonedDoc`, opens modal |
| `_openEditDocument(doc)` | clears `_clonedDoc`, sets `_editingDoc = Map.from(doc.data)`, opens modal |
| `_handleInsertDocument(doc) → String?` | **core rule:** update iff `_editingDoc != null && _clonedDoc == null`, else insert. `catch (err) → return '$err'` (e.g. E11000). Success → clears both fields, returns `null`. **Never closes the modal** — `InsertDocumentModal._submit` closes it only when `onInsert` returned `null`, otherwise shows the banner |
| `_handleCloneDocument(doc)` | `_editingDoc = null`; `_clonedDoc = Map.from(doc.data)..['_id'] = mongoEngine.generateObjectId()`; opens modal. Clone always inserts |
| `_requestDeleteDocument(id, doc)` | resolves doc if null, opens delete modal |
| `_confirmDeleteDocument()` | `mongoEngine.deleteDocument(...)`, clears payload (payload is NOT cleared by modal `onClose`) |
| `_handleUpdateDocument(id, fields)` | direct `updateDocument` in try/catch that swallows errors + `setState` (wired to JSON view inline edit — currently unused there) |

`InsertDocumentModal` instantiation in the Stack (~L940–949):

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

All modals are permanently installed children of the root `Stack` (~L864–984), each with an
`isOpen` boolean; `CompassModalShell` returns `SizedBox.shrink()` when closed (invariant 5 in
AGENTS.md). Order: Connection, CreateDb, CreateCollection, **CreateIndex**, Rename,
DropDatabase, DropCollection, **DropIndex**, DeleteDocument, **InsertDocument**, ImportExport,
ExportLanguage, SaveView, MongoshConfirmation (`isOpen: _pendingTerminalOperation != null`).

Three modals hand-roll their own `Positioned.fill` overlay instead of `CompassModalShell`:
`ConnectionModal` (fixed width 560), `ExportLanguageModal` (width 580),
`MongoshConfirmationModal` (width 512).

Payload-clearing asymmetry to remember: most `onClose` closures only flip the boolean;
delete payload clears on confirm; insert payload (`_editingDoc`) clears on open/success.

## Connection flow (~L261–357, L559–606)

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

## Terminal / mongosh (~L600–703, 852–862, 979–984)

`CompassTerminal` (docked bottom drawer) → `onRequestConfirmation: _requestTerminalConfirmation`
→ sets `_pendingTerminalOperation`/`_pendingTerminalConfirm` → `MongoshConfirmationModal`.
`_executeTerminalCommand` recognizes only a regex subset: `db.dropDatabase()`,
`db.<coll>.drop/deleteMany/remove/deleteOne/updateMany/updateOne/insertOne`.
Helpers: `_splitArgs` (bracket-depth aware), `_parseMap`.

## Line map of `main.dart` (approximate)

| Range | Section |
|---|---|
| 40–52 | `main()` + DefaultTextEditingShortcuts rationale |
| 54–59 | `CompassApp` + porting-constraint doc comment |
| 61–160 | all state fields (grouped) |
| 162–249 | tab handlers |
| 251–357 | connection handlers |
| 358–469 | db/collection/index modal handlers (create/rename/drop/drop-index) |
| 471–557 | document CRUD |
| 559–619 | import/export/language/save-view/reset/disconnect/terminal confirm |
| 621–701 | `_executeTerminalCommand` + arg helpers |
| 703 | `_theme` palette getter (workaround) |
| 706–1024 | `build()` (header 729, sidebar 756, main pane 797–848, terminal 852, modals 864–984) |
| 1026–1193 | `_buildCollectionHeader` |
| 1195–1229 | `_buildTab` |
| 1231–1258 | `_buildHeaderAction` |
| 1260–1296 | `_buildViewModeBtn` |
| 1298–1373 | `_buildDocumentsPagination` |
| 1375–1393 | `_buildPageButton` |
| 1395–1442 | `_buildDocumentsEmptyState` |
| 1444–1513 | `_buildActiveTabView` |

## Recipe: adding a new modal

1. Create `lib/widgets/modals/<name>_modal.dart` using `CompassModalShell` +
   `CompassModalHeader` + `CompassModalFooter` (see `docs/ui.md`); props always include
   `bool isOpen` + `VoidCallback onClose`; reset controllers in `didUpdateWidget` when
   `isOpen` flips false→true.
2. In `main.dart`: add `_is<Name>ModalOpen` flag (+ payload fields) near L95–142.
3. Add an `_open…` setter and a `_confirm…`/`_handle…` callback near the related handlers.
4. Instantiate it once in the root `Stack` (~L864–984) with `isOpen`/`onClose`.
5. Add a widget test if behavior matters — see `docs/testing.md`.
