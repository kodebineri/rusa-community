# UI Layer — Widgets, Icons, Theme

Companion to root `AGENTS.md`. Covers the shared modal primitives, every modal, every
document/collection view, the chrome widgets (header/sidebar/query bar/tab bar/terminal),
the icon system, and the theme system. Line numbers are approximate anchors.

Rules that apply everywhere in this layer (see AGENTS.md): **no Material widgets** — no
`MaterialApp`/`Scaffold`/`Theme`/`Icon`/`TextField`; icons are `CompassSvg`; text inputs are
bare `EditableText` via `CompassInput` (hence `DefaultTextEditingShortcuts` at bootstrap);
all colors resolve from `CompassTheme` + `CompassColors`; all styles from
`CompassTypography`.

## Touch layer — density, hit areas, overflow sheet

The React reference this app was ported from assumes a mouse: glyphs are 11–16 px and are
packed tightly together. With a finger that is unusable, so the UI reads its metrics from
three new primitives instead of hard-coding sizes.

### `lib/theme/compass_density.dart` — `CompassDensity extends InheritedWidget`

Mirrors the `CompassTheme` pattern (no Material, no `ThemeData`):

| Metric | Desktop | Touch |
|---|---|---|
| `isTouch` | `false` | `true` |
| `minTapTarget` | 20 dp | **44 dp** (Apple HIG minimum; Material's 48 is close enough) |
| `iconScale` | 1.0 | 1.15 |
| `rowHeight` | 36 dp | 48 dp |

- `CompassDensity.touchBreakpoint = 768.0`; `CompassDensity.forWidth(width: …, child: …)`
  picks the profile. **`main.dart` wires it from the viewport width** (`constraints.maxWidth`),
  and the profile also promotes to touch when `CompassDensity.isTouchPrimaryPlatform` is true
  so an 8-inch tablet in landscape (wider than the breakpoint) still gets 44 dp targets.
- `isTouchPrimaryPlatform` reads `dart:io`'s `Platform.isAndroid/isIOS/isFuchsia`, **not**
  `defaultTargetPlatform`: `flutter_test` reports the latter as Android, which would push every
  desktop-layout test into the touch profile. `dart:io` reports the real host, so tests keep the
  desktop profile.
- The docked desktop layout switches later on touch platforms
  (`CompassDensity.desktopBreakpointFor`: 1024 dp vs 768 dp), so a portrait tablet keeps the
  roomier touch layout instead of a cramped docked sidebar.
- `CompassDensity.of(context)` resolves the nearest ancestor and **falls back to the desktop
  profile** when there is none (widgets pumped in isolation by a test).

### `lib/widgets/compass_icon_button.dart` — `CompassIconButton`

`{svgString, onTap, onLongPress?, color?, size = 14, padding = 4, semanticLabel?,
background?, borderColor?, borderRadius = 6, boxSize?, hoverBackground?,
showHoverBackground = true}`.

- **Scales the hit box, not the glyph.** `ConstrainedBox(minWidth/minHeight:
  density.minTapTarget)` → `CompassHover` → `Container(padding + decoration)` →
  `Stack(alignment: center)` → `CompassSvg(size * density.iconScale)`. The desktop layout
  is pixel-identical to the old bare `GestureDetector`; only the invisible target grows.
  A `Stack` is used instead of `Center` because `Center` expands to infinity inside a `Row`.
- `boxSize` forces a square chip (e.g. the query bar's reset button is 36 px on desktop,
  44 px on touch — the density minimum always wins).
- ⚠ `StatelessWidget` has **no `widget` getter** (that is `State`); read the fields directly.

### `lib/widgets/compass_hover.dart` — `CompassHover`

`{builder: Widget Function(bool isHovered), onTap?, onLongPress?, semanticLabel?}`.
A `MouseRegion` + optional `GestureDetector` + optional `Semantics(button: true)` wrapper.

- **Builder API on purpose:** a wrapper-level hover fill is *invisible* behind a control's
  own solid fill, so the hovered control has to repaint itself (the primary button swaps
  `theme.accent` → `CompassColors.greenHover`, the secondary button swaps `bgSubtle` →
  `bgHover` + `borderHover`, the danger button swaps to `Color(0xFFFF6B85)`).
- `MouseCursor.defer` / `SystemMouseCursors` come from `package:flutter/widgets.dart` — no
  Material import needed.

### `lib/widgets/modals/compass_action_sheet.dart` — `CompassActionSheet`

`{isOpen, items: List<CompassActionSheetItem>, onClose, title = ''}` where an item is
`{label, svg, onTap, color?, destructive = false}`.

- A **bottom sheet** for the header actions that do not fit on a narrow screen
  (change connection / reset samples / Shell / disconnect).
- Like the modals it is a `Positioned.fill` child of the root `Stack` in `main.dart`
  (invariant 5) — there is no `Navigator` and no Material `showModalBottomSheet`.
  `if (!isOpen) return const SizedBox.shrink()` → closed sheets are never mounted.
- Backdrop = `CompassColors.modalOverlay`, tapping it closes the sheet; there is also an
  explicit `Cancel` row because backdrop-only dismissal is not finger-discoverable.
- Rows are `≥ density.minTapTarget` tall, icon + label, destructive rows use
  `CompassColors.errorRed`.

### Layout rules that follow from the density

- **Icon-only chrome on touch:** the header's Reset Samples / Shell / Disconnect move
  into the action sheet; the collection breadcrumb actions (`New Coll`, `Rename Coll`,
  `Drop Coll`), the documents-tab `Insert Document`, `Import` and `Export` collapse into
  `CompassIconButton`s. Labelled chips are kept on wide windows.
- **Two-row query bar only when narrow:** below 640 px (700 px on a touch device, where
  the buttons are larger) the filter input takes the full width and the action buttons wrap
  onto a second row (`Wrap`). Tablets and wider windows keep Options / Reset / Find inline
  with the filter, like desktop.
- **Horizontally scrollable toolbars:** the documents toolbar (view-mode switcher, range
  label, pager) becomes a `SingleChildScrollView(scrollDirection: horizontal)` with
  `Row(mainAxisSize: MainAxisSize.min)`.
- **Ellipsizing instead of overflowing:** the breadcrumb names, the `ObjectId` badge and
  the tree rows use `Flexible` + `TextOverflow.ellipsis`; the tree row splits the width
  `3:2:5` between key / type / value on touch.
- **Keyboard affordances disappear:** the "Tip: Press Enter to find" hint is hidden below
  900 px.
- The sidebar becomes an overlay drawer (`min(320, 85 % of the viewport)`) and its search
  input grows to 44 px; the table view's ACTIONS column grows from 100 to 132 px and its
  rows from 36 to 48 px.
- ⚠ `flutter_test` substitutes a **very wide placeholder font**, so a probe at 1024 px
  still reports a header overflow that does not happen with the real fonts. The layout was
  verified overflow-free at 320/360/390/414/600/767/768/1024/1920 px with a temporary
  probe that was deleted afterwards.

### System insets and OS text scaling (`lib/main.dart` → `_CompassAppState.build`)

The shell is dense and pixel-precise, so two OS-level inputs are normalised in `build()`:

- **Text scaling is clamped to 0.8–1.3.** The app builds its own `MediaQuery` (there is no
  Material app), so `build()` wraps the tree in a `Builder` that re-provides
  `mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 0.8, maxScaleFactor: 1.3))`.
  Android/iOS "font size" then moves the UI within a range the layout can absorb instead of
  blowing it up; desktop reports 1.0, so it is a no-op there.
- **The shell honours the bottom system inset.** The `Column` (header + body + terminal) that
  the `appShell` `Stack` hosts is wrapped in `SafeArea(top: false)`, so the sidebar footer,
  pagination bar and docked terminal stay clear of the Android navigation bar / iOS home
  indicator. Top is left to `CompassHeader`, which has its own `SafeArea`. The modals and
  action sheets are siblings of that widget in the `Stack` and keep their own `SafeArea`, so
  they still reach the screen edge (invariant 5).

## Text selection context menu & syntax colouring

Two small cross-cutting helpers make bare `EditableText`s usable (no Material
`AdaptiveTextSelectionToolbar` is available).

### `lib/widgets/compass_text_menu.dart`

- `CompassTextContextMenu` (`{density, onCut, onCopy, onPaste, onSelectAll, canCut/canCopy/canPaste}`) —
  a themed panel with Cut / Copy / Paste / Select-all rows, `minWidth 168`, rows
  `≥ density.minTapTarget`. Tapping the panel (not a row) closes it.
- `compassTextContextMenuBuilderFor(LayerLink anchorLink, {required CompassDensity density})` —
  the `EditableTextContextMenuBuilder`. It anchors the menu to the field (`below` when it fits,
  `above` otherwise for the bottom-docked Shell prompt) via `CompositedTransformFollower`.
  **The field must be wrapped in a `CompositedTransformTarget` with the same `LayerLink`**, or
  the menu opens in the window corner. Every action closes the menu (`ContextMenuController.removeAny`).
- `compassHandleTapOutside(event, focusNode)` — the `onTapOutside` handler; closes the menu and
  only unfocuses on non-touch pointers (so the soft keyboard stays open on a phone).
- The menu lives in the root `Overlay`, hence `main.dart`'s `TapRegionSurface` + `Overlay`
  (see `docs/architecture.md` → Bootstrap) and its `CompassDensity` must be passed in
  (the overlay sits above the app's density provider).

Wired in: `CompassInput`, `CompassQueryBar`'s fields, `CompassTerminal`'s prompt. The sidebar
search field does **not** wire it (plain `EditableText`).

### `lib/utils/json_syntax_text_controller.dart` — `JsonSyntaxTextController`

A `TextEditingController` subclass whose `buildTextSpan` regex-highlights JSON: keys →
`theme.accent`, strings → `0xFF6A9955`, numbers → `0xFFB5CEA8`, `true/false/null` →
`0xFF569CD6`, punctuation → `theme.textMuted`. Its `theme` field is mutable and refreshed in
`didChangeDependencies`. Used **only** by the query bar's filter / project / sort fields (not
by the insert-document JSON editor, which uses a plain controller).

## Shared modal primitives — `lib/widgets/modals/compass_modal.dart`

Only these 9 public widgets exist (there is **no** `CompassSelect`/`CompassToggle`/
`CompassDropdown` — selects/checkboxes are built ad hoc per modal, e.g. pill `Wrap`s and
hand-rolled check rows in `create_collection_modal.dart`):

| Widget | Key params | Behavior |
|---|---|---|
| `CompassModalShell` | `isOpen`, `maxWidth = 448`, `children`, `onBackdropTap?` | **`if (!isOpen) return const SizedBox.shrink()`** → else `Positioned.fill` → `CompassColors.modalOverlay` (60% black) → centered card: width `min(maxWidth, constraints.maxWidth - 32)`, `maxHeight = constraints.maxHeight - 64`, margin 16, padding 20, radius 12, `bgPanel` + `border`, shadow; content = `SingleChildScrollView > Column(stretch)`. Backdrop: outer `GestureDetector(onTap: onBackdropTap)` with an inner tap-absorber so only backdrop clicks close. **Must be a direct child of a `Stack`.** |
| `CompassModalHeader` | `title`, `subtitle?`, `iconSvg`, `iconColor?/iconBg?/iconBorder?`, `onClose?`, `showClose = true` | 32×32 icon chip (green badge defaults) + title (`CompassTypography.header`) + optional subtitle + close `CompassIconButton(close, 14)` (only when `showClose && onClose != null`); bottom border |
| `CompassFieldLabel` | `label`, `hint?`, `trailing?` | label row with optional right hint |
| `CompassInput` | `controller`, `placeholder`, `autofocus`, `maxLines = 1`, `minLinesAuto = true`, `minLines?`, `mono = true`, `obscureText`, `onChanged?`, `onSubmitted?` | **Built directly on `EditableText`** (documented: avoid Material `TextField` dependency). Own `FocusNode` (disposed). **Wrapped in `CompositedTransformTarget(link: _menuAnchor)`** and wires the custom copy/paste menu: `contextMenuBuilder: compassTextContextMenuBuilderFor(_menuAnchor, …)` + `onTapOutside: compassHandleTapOutside` (see "Text selection context menu"). Boxed container + placeholder shown only when text empty. `resolvedMinLines = minLines ?? (minLinesAuto && maxLines > 1 ? maxLines : 1)` |
| `CompassPrimaryButton` | `label`, `iconSvg?`, `onTap` (null = disabled), `fullWidth` | green accent button; label rendered as `Text(label, CompassTypography.header(...))`. Wrapped in `ConstrainedBox(minHeight: density.minTapTarget)` + `CompassHover` (hover fill `CompassColors.greenHover`) |
| `CompassSecondaryButton` | `label`, `iconSvg?`, `onTap` | subtle `bgSubtle` + border; hover swaps to `bgHover` + `borderHover` |
| `CompassDangerButton` | `label`, `iconSvg?`, `onTap` | red; ⚠ the rendered icon is **hardcoded to `CompassSvgIcons.trash`** — `iconSvg` is ignored. Hover fill `Color(0xFFFF6B85)` |
| `CompassErrorBanner` | `message` | rose banner: `errorRedBg/Border` + activity icon + `Text(message)` |
| `CompassModalFooter` | `children` | right-aligned row (8px gaps, top border) — becomes a `Wrap` on touch so the buttons can wrap instead of overflowing |

## Modal inventory — `lib/widgets/modals/`

All modals (except the three noted) render via `CompassModalShell`; all reset
controllers/errors in `didUpdateWidget` when `isOpen` flips false→true; all are instantiated
permanently in `main.dart`'s root `Stack` (~L1123–1367). **Two** touch-only
`CompassActionSheet`s live in the same stack (last children, so they paint above the
modals): the header overflow sheet and the query-bar overflow sheet.

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
| `EulaModal` | `isOpen, onClose` | `maxWidth 640`. Reads the bundled `EULA.md` asset (`pubspec.yaml` → `assets:`) **lazily, the first time it opens** (it is a permanent root-`Stack` child, so loading at startup would be wasted work) and renders it with `CompassMarkdownView`; shows a muted "Loading license text..." placeholder, or a `CompassErrorBanner` if the asset cannot be read. Opened from the header more-menu (desktop) and the touch action sheet. Edit `EULA.md`, never the widget, to change the license text |
| `PrivacyPolicyModal` | `isOpen, onClose` | `maxWidth 640`. Same pattern as `EulaModal` (lazy load on first open) but reads the bundled `PRIVACY.md` asset (`shieldCheck` header icon, "Loading privacy policy..." placeholder). Opened from the header more-menu (desktop) and the touch action sheet. Edit `PRIVACY.md`, never the widget, to change the policy text |
| `OnboardingModal` | `isOpen, needsEulaConsent, initialDontShowAgain, onSelectTheme, onFinish({dontShowAgain})` | **First-run welcome tour**, a full-window cover (not a `CompassModalShell`): four slides — welcome (brand tile + `HELLO, WELCOME TO` kicker + tagline) → sample data (`library`, `social_networks` in a labelled box) → theme (Dracula vs Material Light previews, applied live) → terms (**the full `EULA.md` in a bordered box that scrolls on its own**, with the acceptance controls pinned below it so they are always visible — no "read full text" toggle). No close button and no backdrop dismissal; **Skip** jumps *to* the terms slide. The primary action is **gated**: it reads **Done** and stays disabled (`onTap: null`, muted fill) until the **I accept the End User License Agreement (EULA).** box is ticked (with a muted "Tick the box above to continue." hint); when consent is already given the acceptance box is hidden and **Done** is enabled. The last slide also carries the **Don't show this again in the future** checkbox row (ticked by default). Rendered by `main.dart` as the last root-`Stack` child while `_isOnboardingOpen`; `onFinish` persists `eula_accepted` / `onboarding_done` and reveals the app. Re-opened from **Show Welcome Screen** (header `⋮` menu and touch action sheet, above About). **Design language** (mirrors the reference `OnboardingPage`): minimal 56 px header (gradient brand chip + `r u s a` + `n / N` step counter + **Skip**), one centered 448 px column — **vertically centered in the body** by `LayoutBuilder` → `SingleChildScrollView` → `ConstrainedBox(minHeight: viewport)` → `Center` (a `Center` shrink-wraps when the height is unbounded, so the `minHeight` makes it fill and centre; tall slides simply grow and scroll). The terms slide is the exception: it is given the body height (`SizedBox`) so its licence box can flex and the acceptance controls stay pinned — led by a 48 px rounded icon tile (64 px gradient tile on the welcome slide), 12 px-radius cards whose *selected* state is accent border + 7 % accent tint + soft accent ring, and a quiet bottom bar — borderless **Back** on the left, dots in the middle (active dot larger with an accent ring), one `CompassPrimaryButton` on the right (`Next` / `Done`), laid out in a `Stack` so the dots stay centred while the buttons keep their natural widths. Slides cross-fade over 150 ms (`AnimatedSwitcher`) and ←/→ step through them; Enter never finishes the tour. ⚠ Do **not** size the body with `SliverFillRemaining`/`IntrinsicHeight`: they measure the child's *intrinsic* height, and `Row` + `Expanded` (the markdown list rows) reports a one-line height for wrapped text — the long terms slide then overflows and its bottom becomes unreachable |
| `AboutModal` | `isOpen, onClose` | `maxWidth 320`. Stateless: the brand mark (72 px, `CompassSvgIcons.rusa`, tinted with `CompassTheme.brandMark`), the `Rusa` wordmark (in a `FittedBox` so it cannot overflow a phone), the tagline **A MongoDB database client**, a `Version <pubspec>` chip (`AboutModal.appVersion`, mirrored from `pubspec.yaml` through `lib/app_info.dart` — a test fails if the two drift), and a non-affiliation disclaimer ("not affiliated with, endorsed by, or sponsored by MongoDB, Inc."). No header bar — a footer `Close` + backdrop dismiss. Opened from the header more-menu (desktop) and the touch action sheet |

### `lib/widgets/compass_markdown_view.dart` - `CompassMarkdownView`

Dependency-free Markdown renderer used for long-form legal text (the EULA and Privacy Policy). No Markdown
package ships (see `pubspec.yaml`), so `{markdown, blockSpacing = 10}` parses a deliberately
small subset: `#`/`##`/`###` headings, `-`/`*`/`+` bullets, `1.` ordered lists, `---` rules,
and `**bold**` / `*italic*` / `` `code` `` inline spans. Anything unrecognised degrades to a
paragraph, so the parser never throws. The text is read from the bundled `EULA.md` / `PRIVACY.md`
assets by `EulaModal` / `OnboardingModal` (terms slide) / `PrivacyPolicyModal` — do not
duplicate legal copy as Dart literals.

## Document / collection views - `lib/widgets/views/`

| View | Props (callbacks) | Behavior |
|---|---|---|
| `DocumentTreeView` | `documents`, `onEditDocument(doc)`, `onCloneDocument(doc)`, `onDeleteDocument(docId, doc)` | Stateless. One card per doc: header `#<i+1>` + green `ObjectId("<id>")` badge + action strip — **copy → `onCloneDocument`**, pencil → edit, trash → delete. Body: recursive `_TreeNodeWidget`; chevron expandable for Object/Array, **collapsed by default at every depth** (deliberate deviation from the React reference, which expanded `depth < 2`); expanding a node starts its own children collapsed; BSON-colored type labels (`theme.bson*`); collapsed shows `{ ... }` / `[ ... n items ]`. Empty: "No documents match the current query". **On touch the badge ellipsizes and the tree row splits its width `3:2:5` between key / type / value** |
| `DocumentJsonView` | `documents`, `onUpdateDocument(docId, fields)`, `onCloneDocument`, `onDeleteDocument` | Stateful. Card per doc: `#n` + `_id` + copy/pencil/trash; body = pretty JSON. **Inline edit works**: tapping the pencil swaps the body for a multi-line `CompassInput` (autofocus) and replaces the pencil with **Save** (check) / **Cancel** (close). Save parses the JSON, forces `_id` back to the original, calls `onUpdateDocument` and exits edit mode; invalid JSON shows a `CompassErrorBanner` and keeps the editor open. **A field removed from the JSON is removed persistently** (the engine's plain-map update is a full replace). Edit state is dropped if the document leaves the list (filter/delete/switch) |
| `DocumentTableView` | `documents`, `onEditDocument`, `onDeleteDocument` | Horizontal-scroll table: `#` col (48px), dynamic columns from key union, `_id` first (220px, others 160px, header click client-side sorts), ACTIONS col (100px, **132px on touch**) pencil/trash. Rows 36px (**48px on touch**), BSON-styled cells. **No clone callback — no copy icon in table mode** |
| `SchemaView` | `dbName, collName` | **StatefulWidget** owning `fields` + `isAnalyzing`: auto-runs analysis on open / db-coll change and on **Analyze Schema** (250 ms `Timer` mirrors the React `setTimeout(…, 250)`; while running the button is disabled `Opacity 0.5` with label **Analyzing...**); reads `analyzeSchema` from the global `mongoEngine`. Header "Schema Analysis" + `Analyzed N unique fields in <coll>`; per-field cards: type badges with %, 8px multi-color distribution bar (incl. red missing segment), first-3 samples, min/max |
| `IndexesView` | `dbName, collName, indexes, onCreateIndex, onDropIndex(name)` | Header + **Create Index**; table `INDEX NAME / FIELDS & ORDER / PROPERTIES / SIZE / ACTIONS`; `_id_` row = shieldCheck "Protected" (no trash); `unique` → blue badge. Stateless — `onCreateIndex`/`onDropIndex` only open the root-Stack modals (`CreateIndexModal` / `DropIndexModal`), which mutate the engine; the table refreshes on the next `setState` because `indexes` is the live `activeColl.indexes` list |
| `AggregationsView` | `dbName, collName, onSaveAsView?: fn(pipeline, json), initialPipeline?` | ~1300 lines / 47 KB. Classes: `AggregationPreset {id, name, description, stages}`; `_availableOperators = [$match,$group,$sort,$project,$limit,$skip,$unwind,$count,$lookup]`. State: `_activeMode ('visual'\|'raw')`, **starts with an empty pipeline** (like Compass — an empty pipeline returns the collection's documents; a view's "Copy to Aggregations" can seed it via `initialPipeline`), per-stage controllers, `_rawController`, 5 presets (Match & Group, Unwind & Count, Top 10 Rated, Lookup Publishers, Count Documents), results (`_results`, `_executionTimeMs`, `_errorMessage`, `_isRunning`, `_resultPage`, `_resultViewMode 'json'\|'table'`). Auto-runs once post-frame in `initState` and on db/coll change. Sections: mode switcher + action bar (**Run Pipeline** / Save as View; stacks below 620 dp so the buttons are never clipped, touch-sized targets), presets strip, visual builder (quick-add chips, Add Stage, stage cards with operator picker/enable/move/duplicate/delete; **content edits re-run the pipeline live**), raw editor (`CompassInput maxLines 14`; the action bar's **Run Pipeline** is the only run control), results panel (paged **preview** — only 20 documents per page with a prev/next pager, `n docs (x.x ms)` pill, JSON/Table switch, copy); pressing **Run Pipeline** scrolls the results panel into view |
| `ShowDdlView` | `dbName, collName, viewOn, pipeline, onUpdateView(pipeline)->String?, onCopyToAggregations(pipeline)` | **Only for views**; hosts the `ddl` ("Show DDL") section tab that appears after **Indexes** when `activeColl.isView`. Renders the view's pipeline as an editable, JSON-syntax-coloured `CompassInput` (`JsonSyntaxTextController` + auto-indent). **Update View** re-applies the edited DDL via `mongoEngine.updateView` (drop + recreate; the real service sequences both server calls in one queued op); **Copy to Aggregations** loads the pipeline into the Aggregations tab (`_pendingAggregationPipeline`). Error/success banners below the editor |

## Chrome widgets — `lib/widgets/`

| Widget | Props & behavior |
|---|---|
| `CompassHeader` | `connection, onOpenConnectModal, onDisconnect, onResetData?, showResetSample = true, isTerminalOpen, onToggleTerminal, themeVariant, onSelectTheme, onToggleMobileSidebar, isMobile = false, onOpenActions?, onReportBug?, onShowEula?, onShowPrivacyPolicy?, onShowAbout?, onShowWelcome?`. 56px bar: hamburger (`isMobile` only — the sidebar is docked on desktop), theme-tinted `rusa` mark + `r u s a` wordmark → connect modal, connection pill (or amber Connect), **Reset Samples** (only when `showResetSample` — passed as `_realService == null`), Shell toggle, Disconnect/Connect. Note: the selected theme is passed in as `themeVariant` (the header does not read it from `CompassTheme`). **Below a 1100 px window the bar collapses**: the divider and the connection pill are replaced by a status dot, the labelled actions move into the `CompassActionSheet` and a `⋮` (`moreVertical`) button opens it via `onOpenActions`. The `moreVertical` menu hosts the **theme picker above Report Bug** — a `DARK THEMES` section (`Dracula` / `Tokyo Night` / `Night Owl`) and a `LIGHT THEMES` section (`Monokai Light` / `Tokyo Night Light` / `Material Light`), each row a swatch + name + check for the active variant, selecting one calls `onSelectTheme(variant)`. Below a divider it also hosts **Report Bug** (opens the GitHub issue tracker in the system browser via `url_launcher`, falling back to an info dialog with a **Copy link** button when no handler exists), **EULA** (`EulaModal`), **Privacy Policy** (`PrivacyPolicyModal`), **Show Welcome Screen** (`onShowWelcome` → replays `OnboardingModal`) and **About** (`AboutModal`). The touch `CompassActionSheet` carries the same theme list (labelled `<name> (dark\|light)`) and the same Report Bug / EULA / Privacy Policy / Show Welcome Screen / About rows |
| `CompassSidebar` | 256px. Props: `databases, selectedDb, selectedColl, onSelectCollection, onSelectDatabase, onOpenCreateDb, onOpenCreateColl, onRenameDb, onRenameColl, onDropDb, onDropColl, onRefresh`. Sections: header (refresh + create-DB icons, **working search box** filtering the DB tree client-side on db name or any collection name), DB tree (chevron toggles `_expandedDbs`, **pre-seeded `library:true`, `social_networks:true`**; row tap → `onSelectDatabase` + auto-expand; trailing plus/pencil/trash; collections show doc counts, amber eye for views), footer Create Database button. **On touch it becomes an overlay drawer** of `min(320, 85 % of the viewport)` and the search input grows to 44 px |
| `CompassQueryBar` | `options: QueryFilterOptions, onChangeOptions(fn), onExecuteQuery, onResetQuery, optionsExpanded, onToggleOptions, onOpenOverflow, executionTimeMs?, totalResultsCount?`. **Uses its own `EditableText`** (not `CompassInput`) wrapped in `Visibility(maintainState/maintainSize)` so the element identity survives empty↔non-empty (documented fix for test 2). FILTER / PROJECT / SORT use a `JsonSyntaxTextController` (**JSON syntax colouring**); filter/project/sort also get the custom context menu + **auto-close bracket pairs** (`_handleAutoClosePairs`) and Enter-between-brackets formatting (`_handleEnterFormatting`). **Nothing executes on type anymore** — `_handleFilterChange` only validates (amber/green status icon) and typing in SKIP/LIMIT is a no-op; values commit on **Find** via `_executeWithCurrentFilter` (Enter fires `onSubmitted`). Options toggle expands the panel (`optionsExpanded` lives in `main.dart` so the root query-action sheet can toggle it); skip clamps ≥0, limit ≥1; Reset / **Find** buttons; stats ribbon `Matches: n · Time: xms`. **Below 640 px (700 px on touch) the filter input takes the full width and the action buttons wrap onto a second row; the options panel stacks (PROJECT / SORT full width, SKIP + LIMIT side by side) and the "press Enter" hint disappears; a `onOpenOverflow` control opens the query-action sheet** |
| `CollectionTabBar` | 36px strip. `tabs, activeIndex, onSelect(i), onClose(i)`. Tabs `minWidth 140/maxWidth 200`, active = `bgSubtle` + 2px accent bottom border; icon = `table` (or `database` when coll name empty); close = `CompassSvg(close, 11)`; right counter `'<n> open'`; active tab auto-revealed via `Scrollable.ensureVisible` post-frame |
| `CompassTerminal` | Docked **Shell** drawer. `isOpen, onClose, activeDbName, onCommandExecuted?, onRequestConfirmation?`. `SizedBox.shrink()` when closed; heights 220/380; hardcoded dark palette. Input line `<db>> ` + `EditableText`. **All parsing/execution lives in `MongoshInterpreter`** (`lib/services/mongosh_interpreter.dart`), not in the widget: the widget runs the command once, appends the output (errors in `CompassColors.errorRed`) and hands the `MongoshResult` to `onCommandExecuted`, which `main.dart` uses only to apply UI side effects (switch database, close tabs for dropped targets) and `setState`. `_detectRisky` asks the interpreter's command table whether the command is risky, then builds the `RiskyOperationDetails` copy; the command is deferred until confirmed via `onRequestConfirmation`. The prompt supports ↑/↓ history, Tab completion, multi-line commands and Ctrl+L/Ctrl+C/Esc — see "Shell prompt" below |

### `lib/services/mongosh_interpreter.dart` — `MongoshInterpreter`

A deliberately small, **honest** shell (a mongosh-compatible command subset). It is *not* a
JavaScript REPL:
it recognises a fixed command table and says so when a command is unsupported, instead of
pretending success (the old `"Command acknowledged."` fallback is gone).

- **Two command tables** drive dispatch, `help` and the risky-operation confirmation, so they
  cannot drift:
  - `MongoshInterpreter.commands` (`List<MongoshCommand>`) — top-level commands. Each row is
    `{name, usage, summary, pattern, risky, run}`; `pattern` matches the whole normalised
    command (trailing `;` stripped).
  - `MongoshInterpreter.collectionCommands` (`List<MongoshCollectionCommand>`) —
    `db.<coll>.<method>` methods. Each row is
    `{method, usage, summary, risky, supportsChain, run}`.
- **Top-level commands:** `help [command]`, `show dbs`, `show collections`, `use <db>`,
  `db.getName()`, `db.getCollectionNames()`, `print(value)`, `JSON.stringify(value)`,
  `db.dropDatabase()`.
- **Collection methods:** `find`, `findOne`, `countDocuments`, `count` (alias), `distinct`,
  `aggregate`, `insertOne`, `insertMany`, `updateOne`, `updateMany`, `replaceOne`,
  `deleteOne`, `deleteMany`, `remove` (legacy alias), `createIndex`, `getIndexes`,
  `dropIndex`, `stats`, `drop`.
- **Update operators:** `$set`, `$unset`, `$inc`, `$push` (including `$each`) and `$pull`; a
  plain map is a full replacement. `updateDocument` and `updateMany` share one `_applyUpdate`
  helper in the engine, so both understand the same operators.
- **Cursor chains:** `find` is the only chainable method (`supportsChain`). A real call parser
  (`_parseCollectionCall` + `_matchingParen`, string-aware) splits
  `db.<coll>.find(args).sort(…).limit(n).skip(n).count()`; `sort`/`limit`/`skip` map onto
  `QueryFilterOptions`, `count()` returns the total (ignoring skip/limit), and `pretty()` /
  `toArray()` are accepted no-ops. Chaining a non-cursor method is rejected with
  `does not support chaining`.
- **Honest failures:** anything else returns `isError: true` with
  `db.<coll>.<method>(...) is not supported by this shell yet.` (or `Unrecognized command`)
  plus a pointer to `help`. `use` on a missing database reports that instead of claiming a
  switch.
- **Single executor:** the interpreter runs the command exactly once and returns
  `MongoshResult{output, sideEffect?, isError}`. `main.dart` only applies the side effect
  (`switchDatabase` / `dropDatabase` / `dropCollection`) and refreshes — it must never run
  the command again (that double-execution bug made `deleteOne` delete two documents and
  `updateOne` behave like `updateMany`).
- **Testable:** pure Dart, no widgets. `test/mongosh_interpreter_test.dart` covers help,
  honest errors, reads, cursor chains, writes, side effects and risky detection. Add a
  top-level command to `_buildCommands()` or a collection method to
  `_buildCollectionCommands()` — `help`, Tab completion and the confirmation gate pick it up
  automatically.
- **Output:** documents render mongosh-style — `ObjectId("…")` for BSON ids (the engine's
  `MongoObjectId` type) and a `[n docs]` footer, with a `(of N — add .limit(n) to see more)`
  hint when the page is truncated. `ISODate("…")` is deliberately not rendered: dates are
  stored as plain ISO strings, so the BSON type is already lost.

### Shell prompt — history, completion, multi-line

`CompassTerminal` handles the prompt keys on its `FocusNode.onKeyEvent` (set in `initState`),
which runs before the text field's own shortcuts:

| Key | Action |
|---|---|
| `Enter` | submit — unless brackets are unbalanced, then insert a newline (multi-line command) |
| `Shift+Enter` | always a newline |
| `↑` / `↓` | recall command history (single-line input; on a multi-line command they move the caret except at the very start/end) |
| `Tab` | complete the word at the end of the line |
| `Ctrl+L` | clear the log |
| `Ctrl+C` / `Esc` | clear the current line |

- **History** is per session (`_commandHistory`), with the in-progress line kept as a draft so
  `↓` past the newest command restores it.
- **Completion** lives in `lib/services/mongosh_completer.dart` (`MongoshCompleter`, pure Dart,
  unit-tested): `use <db>` → database names, `db.<coll>` → collection names,
  `db.<coll>.<method>` → method names **from the interpreter's command table**, `show` →
  `dbs`/`collections`, `help` → command names. A unique match is inserted (plus a space in the
  word contexts); an ambiguous one extends to the common prefix and, when that changes
  nothing, prints the candidates. Tab on an already-complete word is a no-op.
- **Multi-line** is decided by `hasUnbalancedBrackets()` (same file), which ignores brackets
  inside quoted strings. The input row grows from 38 px to at most 120 px and scrolls beyond
  that.

## Icons — `lib/icons/compass_svg_icons.dart`

- **`CompassSvg extends StatelessWidget`** — defined in the *same file* (L6):
  `{required String svgString, double size = 14, Color? color}` → `SvgPicture.string(...)`
  with optional `ColorFilter`. The only icon renderer in the app.
- **`CompassSvgIcons`** — 38 `static const String` raw SVG literals (mostly 24×24 viewBox,
  `stroke="currentColor"`): `mongoLeaf, rusa, terminal, search, sliders, rotateCcw, database,
  table, code, layers, barChart, key, shieldCheck, activity, plus, trash, copy, file,
  upload, download, check, pencil, eye, chevronDown, chevronLeft, chevronRight, chevronUp,
  close, play, menu, sun, moon, zap, arrowUpDown, moreVertical, cut, paste, selectAll`.
  `rusa` (a deer mark) is the **brand mark** used in the header / About modal / connection
  modal. Everywhere it is tinted with `CompassTheme.brandMark` — `#FFFFFFFF` on dark variants,
  `#FF2B2119` on light ones (`CompassColors.darkBrandMark` / `lightBrandMark`), so it stays
  visible whichever background it sits on (the connection modal draws it on a fixed
  green-gradient badge). `mongoLeaf` is retained in the catalog but no longer used
  in branding (MongoDB trademark hygiene).
- Usage: `CompassSvg(svgString: CompassSvgIcons.<name>, size: <px>, color: <theme color>)`.
  Tests find icons via `find.byWidgetPredicate((w) => w is CompassSvg && w.svgString ==
  CompassSvgIcons.<name>)` (`svgString` is a public field).

## Theme — `lib/theme/`

`compass_theme_presets.dart` (the variant catalog + palettes), `compass_theme.dart`
(the InheritedWidget that resolves a palette), `compass_colors.dart` (semantic tokens),
`compass_typography.dart` (styles) and **`compass_density.dart`** (touch metrics — see
"Touch layer" above).

### `compass_theme_presets.dart` — `CompassThemeVariant` / `CompassPalette`

The selectable themes, modelled after popular VS Code colour themes. `CompassPalette` is a
`@immutable` holder of every resolved colour a widget can ask for (the same set the old
dark/light getters returned, plus `accentHover`). `CompassThemeVariant` is an enum carrying
`{ label, isDark, palette }` with six members:

| Group | Variants |
|---|---|
| Dark | `dracula`, `tokyoNight`, `nightOwl` |
| Light | `monokaiLight`, `tokyoNightLight`, `materialLight` |

- `CompassThemeVariant.defaultVariant == dracula` (dark) — the app's default theme.
- `CompassThemeVariant.darkThemes` / `.lightThemes` return the group in menu order
  (`values.where((v) => v.isDark)`); the options menu iterates them.
- `CompassColors` still owns the semantic tokens (error/warning/info, `modalOverlay`,
  scrollbars) and the terminal's palette. The old `darkBg*`/`lightBg*` pairs in
  `CompassColors` are now only referenced by `CompassTypography`'s default argument values.

### `compass_theme.dart` — `CompassTheme extends InheritedWidget`

- Single field `final CompassThemeVariant variant` (default `dracula`). `static
  CompassTheme of(context)` → `dependOnInheritedWidgetOfExactType<CompassTheme>() ?? const
  CompassTheme(child: SizedBox.shrink())` — **fail-safe dark fallback** (Dracula if asked
  above the provider — that's the `main.dart` trap, see AGENTS.md invariant 11).
- Extra named ctor `const CompassTheme.palette(this.variant)` (child = shrink) for
  palette lookups above the provider: `main.dart` uses
  `CompassTheme get _theme => CompassTheme.palette(_themeVariant);`.
- Propagation: `_CompassAppState._themeVariant` (default `dracula`) → root wrap
  `CompassTheme(variant: _themeVariant, child: content)` → selecting a theme in the header
  options menu (or touch action sheet) calls `onSelectTheme` in `setState` (and updates
  `SystemUiOverlayStyle` from `variant.isDark`).
- `bool get isDarkMode => variant.isDark` is kept as a brightness convenience.
- Widgets read **resolved color getters** (never branch on dark/light themselves):
  `bgApp, bgSidebar, bgPanel, bgSubtle, bgHover, bgInput, border, borderHover, textPrimary,
  textSecondary, textMuted, accent, accentHover, onAccent, greenBadgeBg, greenBadgeBorder`,
  and BSON syntax colors `bsonObjectId, bsonString, bsonNumber, bsonBoolean, bsonDate,
  bsonNull` — each forwards to `palette.*`, so adding a theme touches only the preset file.
  Hover fills use `theme.accentHover` (not `CompassColors.greenHover`).

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
`fontSans = 'Inter'`, `fontMono = 'JetBrains Mono'`, `fontTitle = 'Outfit'`. Sans: `title`
(14/Outfit w700), `header` (13/w600), `bodyMedium` (12/w500), `bodyRegular` (12/w400),
`caption` (11), `badge` (10/w600). Mono: `monoBold/monoMedium/monoRegular({Color color,
double size = 12})`, `monoSmall` (11), `queryInput` (12), `terminal` (12, height 1.5).

✅ The three families **ship with the app** — declared under `flutter: fonts:` in `pubspec.yaml`
and committed in `assets/fonts/` (`Inter` 18pt static 400/500/600/700, `JetBrains Mono`
400/500/700, `Outfit` 400/600/700, with their OFL licenses). So the UI renders with the same
typefaces on Windows, Android and iOS instead of falling back to the system font. `google_fonts`
is still in pubspec but never imported. If you change a family/weight in `CompassTypography`, add
the matching file+weight to `pubspec.yaml` (or Flutter synthesises the missing weight).

## Recipe: adding a new view/section

1. Create `lib/widgets/views/<name>_view.dart` (Stateless/StatefulWidget, no Material);
   required props for target db/coll + data + callbacks; theme via `CompassTheme.of(context)`,
   styles via `CompassTypography`, icons via `CompassSvg`.
2. In `main.dart` `_buildCollectionHeader`: add a `_buildTab('<key>', '<Title>', icon)` call.
3. In `main.dart` `_buildActiveTabView`: add `case '<key>'` returning your view with the
   engine-derived data (`service.findDocuments(...)` already ran at the top of `build()`).
4. Remember: the section key is stored per-tab in `CollectionTab.activeSection`.
5. Add a test (e.g. extend the light-mode section walk in test 10) — see `docs/testing.md`.
