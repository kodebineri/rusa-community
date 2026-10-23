import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'dart:async';
import 'theme/compass_colors.dart';
import 'theme/compass_density.dart';
import 'theme/compass_theme.dart';
import 'theme/compass_typography.dart';
import 'icons/compass_svg_icons.dart';
import 'models/mongo_models.dart';
import 'models/collection_tab.dart';
import 'services/local_mongo_engine.dart';
import 'services/mongo_engine.dart';
import 'services/real_mongo_service.dart';
import 'widgets/compass_header.dart';
import 'widgets/compass_icon_button.dart';
import 'widgets/collection_tab_bar.dart';
import 'widgets/compass_sidebar.dart';
import 'widgets/compass_query_bar.dart';
import 'widgets/compass_terminal.dart';
import 'widgets/views/document_tree_view.dart';
import 'widgets/views/document_json_view.dart';
import 'widgets/views/document_table_view.dart';
import 'widgets/views/aggregations_view.dart';
import 'widgets/views/schema_view.dart';
import 'widgets/views/indexes_view.dart';
import 'widgets/modals/connection_modal.dart';
import 'widgets/modals/create_db_modal.dart';
import 'widgets/modals/create_collection_modal.dart';
import 'widgets/modals/create_index_modal.dart';
import 'widgets/modals/rename_modal.dart';
import 'widgets/modals/drop_collection_modal.dart';
import 'widgets/modals/drop_database_modal.dart';
import 'widgets/modals/drop_index_modal.dart';
import 'widgets/modals/delete_document_modal.dart';
import 'widgets/modals/insert_document_modal.dart';
import 'widgets/modals/import_export_modal.dart';
import 'widgets/modals/export_language_modal.dart';
import 'widgets/modals/save_view_modal.dart';
import 'widgets/modals/mongosh_confirmation_modal.dart';
import 'widgets/modals/compass_modal.dart';
import 'widgets/modals/compass_action_sheet.dart';

void main() {
  // The app intentionally avoids MaterialApp/WidgetsApp, which normally install
  // the default text-editing shortcuts (Backspace, arrow keys, Home/End,
  // Ctrl+C/V...). Without this, bare EditableText fields accept typed
  // characters but ignore those editing keys.
  runApp(const DefaultTextEditingShortcuts(child: CompassApp()));
}
/// Root MongoDB Compass Web & Desktop Flutter application.
/// Converted from React TSX (src/App.tsx) adhering strictly to:
/// 1. Layout & Flexbox (LayoutBuilder, Column, Row, Wrap, exact gaps)
/// 2. Color & Styling (Color(0xFF...), no default Material 3 palettes)
/// 3. Typography (CompassTypography, JetBrains Mono & Plus Jakarta Sans)
/// 4. Platform Agnosticism (desktop-first layout, docked panels, no mobile FAB)
/// 5. Icons (CompassSvg everywhere, no generic Icon widget)
class CompassApp extends StatefulWidget {
  const CompassApp({super.key});

  @override
  State<CompassApp> createState() => _CompassAppState();
}

class _CompassAppState extends State<CompassApp> {
  bool _isDarkMode = true;
  ConnectionProfile? _connection = ConnectionProfile(
    id: 'default',
    name: 'Local Standalone',
    uri: 'mongodb://localhost:27017',
    lastConnected: 'Just now',
  );

  /// Non-null while the UI is backed by an actual MongoDB server (rather than
  /// the bundled sample data).
  RealMongoService? _realService;

  bool _isConnectModalOpen = false;
  bool _isTerminalOpen = false;
  bool _isMobileSidebarOpen = false;

  /// True while the touch-only header overflow sheet is open.
  bool _isHeaderActionsOpen = false;

  /// True while the touch-only query-bar overflow sheet is open.
  bool _isQueryActionsOpen = false;

  /// Whether the query bar's options panel (project / sort / skip / limit) is
  /// expanded. It lives here so the root-level overflow sheet can toggle it.
  bool _isQueryOptionsExpanded = false;

  /// True while the app is laid out for touch: the viewport is narrower than
  /// the 768 px breakpoint. Refreshed by the root `LayoutBuilder` on every
  /// layout pass, so the builder helpers below can adapt without having to
  /// thread a `BuildContext` through every signature.
  bool _isTouchLayout = false;

  /// Width of the app viewport in logical pixels. Refreshed by the root
  /// `LayoutBuilder` on every layout pass.
  double _windowWidth = 1440.0;

  /// True when the window is too narrow for the labelled chrome: the
  /// labelled action chips collapse into icon buttons.
  bool get _isCompactLayout => _windowWidth < 900.0;

  // Saved connection profiles (mirrors the React `savedConnections` state).
  List<ConnectionProfile> _savedConnections = [
    ConnectionProfile(
      id: '1',
      name: 'Local Standalone (27017)',
      uri: 'mongodb://localhost:27017',
      favorite: true,
    ),
    ConnectionProfile(
      id: '2',
      name: 'Atlas Production ReplicaSet',
      uri: 'mongodb+srv://admin@cluster0.mongodb.net/test',
      favorite: true,
    ),
  ];

  // --- Popup / modal state (mirrors the React App.tsx modal flags) ---
  bool _isCreateDbModalOpen = false;
  bool _isCreateCollModalOpen = false;
  String _createCollTargetDb = '';

  bool _isCreateIndexModalOpen = false;

  bool _isRenameModalOpen = false;
  RenameTarget _renameType = RenameTarget.database;
  String _renameDbName = '';
  String? _renameCollName;
  bool _renameIsView = false;

  bool _isDropDbModalOpen = false;
  String _dropDbName = '';

  bool _isDropCollModalOpen = false;
  String _dropCollDbName = '';
  String _dropCollName = '';
  bool _dropCollIsView = false;
  int _dropCollDocCount = 0;
  int _dropCollIndexesCount = 1;

  bool _isDropIndexModalOpen = false;
  String _dropIndexName = '';

  bool _isDeleteDocModalOpen = false;
  String _deleteDocId = '';
  MongoDocument? _deleteDocTarget;

  bool _isInsertDocModalOpen = false;
  Map<String, dynamic>? _editingDoc;

  /// Set while the copy/duplicate action has pre-filled the Insert Document
  /// modal with a copy of an existing document (fresh `_id`). Inserting always
  /// creates a new document — it never updates the source document.
  Map<String, dynamic>? _clonedDoc;

  bool _isImportExportModalOpen = false;
  ImportExportMode _importExportMode = ImportExportMode.export;

  bool _isExportLangModalOpen = false;

  bool _isSaveViewModalOpen = false;
  List<dynamic> _saveViewPipeline = const [];
  String _saveViewPipelineJson = '[]';

  RiskyOperationDetails? _pendingTerminalOperation;
  VoidCallback? _pendingTerminalConfirm;

  String _selectedDbName = 'library';
  String _selectedCollName = 'books';
  String _activeTab = 'documents'; // documents, aggregations, schema, indexes
  String _docViewMode = 'tree'; // tree, json, table

  QueryFilterOptions _queryOptions = QueryFilterOptions();

  // --- Open collection tabs (tab navigation, mirrors MongoDB Compass) ---
  // Every collection selected in the sidebar opens in its own tab. Each tab
  // remembers its section/document-view/query state, which is saved when the
  // tab is left and restored when it is re-activated — so `_selectedDbName`,
  // `_selectedCollName`, `_activeTab`, `_docViewMode` and `_queryOptions`
  // always mirror the *active* tab.
  final List<CollectionTab> _openTabs = [
    CollectionTab(dbName: 'library', collName: 'books'),
  ];
  int _activeTabIndex = 0;

  // ---------------------------------------------------------------------------
  // Tab navigation handlers
  // ---------------------------------------------------------------------------

  /// Writes the live section/view/query state back into the active tab so it
  /// can be restored whenever the tab becomes active again.
  void _saveActiveTabState() {
    if (_activeTabIndex < 0 || _activeTabIndex >= _openTabs.length) return;
    final tab = _openTabs[_activeTabIndex];
    tab.activeSection = _activeTab;
    tab.docViewMode = _docViewMode;
    tab.queryOptions = _queryOptions;
  }

  /// Makes `_openTabs[index]` active, restoring its section, document view
  /// mode and query state.
  void _activateTabIndex(int index) {
    if (index < 0 || index >= _openTabs.length) return;
    _saveActiveTabState();
    _activeTabIndex = index;
    final tab = _openTabs[index];
    _selectedDbName = tab.dbName;
    _selectedCollName = tab.collName;
    _activeTab = tab.activeSection;
    _docViewMode = tab.docViewMode;
    _queryOptions = tab.queryOptions;
  }

  /// Opens `dbName`.`collName` in a new tab — or focuses the existing tab when
  /// that collection is already open (like a browser's "open link" behavior).
  void _openCollectionTab(String dbName, String collName) {
    final existing = _openTabs.indexWhere((t) => t.isSameTarget(dbName, collName));
    if (existing >= 0) {
      _activateTabIndex(existing);
      return;
    }
    _saveActiveTabState();
    _openTabs.add(CollectionTab(dbName: dbName, collName: collName));
    _activateTabIndex(_openTabs.length - 1);
  }

  /// Closes the tab at [index]. An inactive tab is closed without touching the
  /// live selection; when the active tab is closed, its neighbor takes over.
  /// Callers wrap this in `setState`.
  void _removeTabAt(int index) {
    if (index < 0 || index >= _openTabs.length) return;
    final wasActive = index == _activeTabIndex;
    _openTabs.removeAt(index);
    if (_openTabs.isEmpty) {
      _activeTabIndex = -1;
      _selectedDbName = '';
      _selectedCollName = '';
      _activeTab = 'documents';
      _docViewMode = 'tree';
      _queryOptions = QueryFilterOptions();
      return;
    }
    if (wasActive) {
      // Activate the neighbor without saving into the removed tab.
      _activeTabIndex = -1;
      _activateTabIndex(index >= _openTabs.length ? _openTabs.length - 1 : index);
    } else if (index < _activeTabIndex) {
      _activeTabIndex--;
    }
  }

  /// Closes every tab matching [test]. The predicate is evaluated for all tabs
  /// *before* any removal so a mid-loop selection change cannot skew matching.
  /// Callers wrap this in `setState`.
  void _closeTabsMatching(bool Function(CollectionTab tab) test) {
    final indices = [
      for (var i = _openTabs.length - 1; i >= 0; i--)
        if (test(_openTabs[i])) i,
    ];
    for (final i in indices) {
      _removeTabAt(i);
    }
  }

  /// Replaces the whole strip with a single fresh tab (used when the data
  /// source changes: connect, disconnect, load sample data).
  void _resetTabsTo(String dbName, String collName) {
    _openTabs
      ..clear()
      ..add(CollectionTab(dbName: dbName, collName: collName));
    _activeTabIndex = -1; // skip saving state into the discarded tabs
    _activateTabIndex(0);
  }

  // ---------------------------------------------------------------------------
  // Modal handlers (ported from src/App.tsx)
  // ---------------------------------------------------------------------------

  /// Opens a connection. Returns `null` on success, or a human-readable error
  /// message for the connection dialog to display.
  ///
  /// Mirrors React's `handleConnectProfile`, but actually opens a `mongo_dart`
  /// session when the URI points at a real server (the bundled sample data is
  /// still reachable through the dialog's "Load Sample Datasets" card).
  Future<String?> _handleConnectProfile(ConnectionProfile profile) async {
    RealMongoService connected;
    try {
      connected = await RealMongoService.connect(profile.uri);
    } catch (err) {
      return _formatConnectError(err);
    }

    if (!mounted) {
      unawaited(connected.dispose());
      return null;
    }

    _disposeRealService();
    _realService = connected;
    connected.onDataChanged = () {
      if (mounted) setState(() {});
    };
    connected.onError = (message) => debugPrint('MongoDB error: $message');

    final firstDb = connected.databases.firstWhere(
      (d) => d.collections.isNotEmpty,
      orElse: () => connected.databases.isNotEmpty
          ? connected.databases.first
          : MongoDatabase(name: '', collections: const {}),
    );
    final firstColl = firstDb.collections.keys.firstOrNull;

    setState(() {
      mongoEngine = connected;
      _connection = profile;
      _resetTabsTo(firstDb.name, firstColl ?? '');
      _isConnectModalOpen = false;
    });
    return null;
  }

  void _disposeRealService() {
    final service = _realService;
    if (service == null) return;
    service.onDataChanged = null;
    service.onError = null;
    unawaited(service.dispose());
    _realService = null;
  }

  /// Turns a driver/socket exception into a concise, user-facing message.
  String _formatConnectError(Object error) {
    final text = error.toString();
    if (text.contains('Connection refused') ||
        text.contains('SocketException') ||
        text.contains('Failed host lookup') ||
        text.contains('Connection timed out')) {
      return 'Could not reach the MongoDB server. Make sure it is running and reachable from this machine.';
    }
    if (text.contains('Authentication failed') || text.contains('auth')) {
      return 'Authentication failed. Check the username, password and auth source.';
    }
    return text.replaceFirst('MongoDartError: ', '').replaceFirst('Exception: ', '');
  }

  void _handleSaveConnection(ConnectionProfile profile) {
    setState(() {
      final existingIndex = _savedConnections.indexWhere((c) => c.uri == profile.uri);
      if (existingIndex >= 0) {
        _savedConnections[existingIndex] = profile;
      } else {
        _savedConnections = [..._savedConnections, profile];
      }
    });
  }

  void _handleDeleteConnection(String id) {
    setState(() {
      _savedConnections = _savedConnections.where((c) => c.id != id).toList();
    });
  }

  /// Connects to the bundled sample datasets: (re)loads the built-in seed data
  /// and selects `library.books`, mirroring React's "Load Sample
  /// Datasets" (`handleResetData`).
  void _handleConnectSampleData() {
    _disposeRealService();
    LocalMongoEngine.instance.resetToDefaults();
    setState(() {
      mongoEngine = LocalMongoEngine.instance;
      _connection = ConnectionProfile(
        id: 'sample-data',
        name: 'Sample Data',
        uri: 'mongodb://localhost:27017',
        lastConnected: 'Just now',
      );
      _resetTabsTo('library', 'books');
      _isConnectModalOpen = false;
    });
  }

  void _openCreateDb() {
    setState(() => _isCreateDbModalOpen = true);
  }

  void _openCreateCollection([String? targetDb]) {
    final dbToUse = targetDb ??
        (_selectedDbName.isNotEmpty ? _selectedDbName : (mongoEngine.getDatabases().firstOrNull?.name ?? ''));
    setState(() {
      _createCollTargetDb = dbToUse;
      _isCreateCollModalOpen = true;
    });
  }

  void _handleCreateDbSubmit(String dbName, String collName) {
    mongoEngine.createDatabase(dbName, collName);
    setState(() => _openCollectionTab(dbName, collName));
  }

  void _handleCreateCollSubmit(String dbName, String collName) {
    setState(() => _openCollectionTab(dbName, collName));
  }

  void _openRenameDb(String dbName) {
    setState(() {
      _renameType = RenameTarget.database;
      _renameDbName = dbName;
      _renameCollName = null;
      _renameIsView = false;
      _isRenameModalOpen = true;
    });
  }

  void _openRenameColl(String dbName, String collName, bool isView) {
    setState(() {
      _renameType = RenameTarget.collection;
      _renameDbName = dbName;
      _renameCollName = collName;
      _renameIsView = isView;
      _isRenameModalOpen = true;
    });
  }

  void _handleRenameSuccess(String oldName, String newName, RenameTarget type) {
    setState(() {
      if (type == RenameTarget.database) {
        for (final tab in _openTabs) {
          if (tab.dbName == oldName) tab.dbName = newName;
        }
        if (_selectedDbName == oldName) _selectedDbName = newName;
      } else {
        for (final tab in _openTabs) {
          if (tab.dbName == _renameDbName && tab.collName == oldName) {
            tab.collName = newName;
          }
        }
        if (_selectedDbName == _renameDbName && _selectedCollName == oldName) {
          _selectedCollName = newName;
        }
      }
    });
  }

  void _openDropDb(String dbName) {
    setState(() {
      _dropDbName = dbName;
      _isDropDbModalOpen = true;
    });
  }

  void _confirmDropDb() {
    final service = mongoEngine;
    final droppedDb = _dropDbName;
    service.dropDatabase(droppedDb);
    setState(() {
      _closeTabsMatching((tab) => tab.dbName == droppedDb);
      if (_openTabs.isEmpty) {
        // Nothing left open: fall back to the first remaining collection.
        final first = service.getDatabases().firstOrNull;
        final firstColl = first?.collections.keys.firstOrNull;
        if (first != null && firstColl != null) {
          _openCollectionTab(first.name, firstColl);
        }
      }
    });
  }

  void _openDropColl(String dbName, String collName) {
    final coll = mongoEngine.getDatabase(dbName)?.collections[collName];
    setState(() {
      _dropCollDbName = dbName;
      _dropCollName = collName;
      _dropCollIsView = coll?.isView ?? false;
      _dropCollDocCount = coll?.documents.length ?? 0;
      _dropCollIndexesCount = coll?.indexes.length ?? 1;
      _isDropCollModalOpen = true;
    });
  }

  void _confirmDropColl() {
    final service = mongoEngine;
    final droppedDb = _dropCollDbName;
    final droppedColl = _dropCollName;
    service.dropCollection(droppedDb, droppedColl);
    setState(() {
      _closeTabsMatching((tab) => tab.isSameTarget(droppedDb, droppedColl));
    });
  }

  void _confirmDropIndex() {
    mongoEngine.dropIndex(_selectedDbName, _selectedCollName, _dropIndexName);
    setState(() {}); // re-read `activeColl.indexes` so the dropped row disappears
  }

  void _openInsertDocument() {
    setState(() {
      _editingDoc = null;
      _clonedDoc = null;
      _isInsertDocModalOpen = true;
    });
  }

  void _openEditDocument(MongoDocument doc) {
    setState(() {
      _clonedDoc = null;
      _editingDoc = Map<String, dynamic>.from(doc.data);
      _isInsertDocModalOpen = true;
    });
  }

  /// Inserts (or, when editing, updates) the document from the Insert Document
  /// modal. Returns `null` on success or a human-readable error message that
  /// the modal surfaces (e.g. an E11000 duplicate-key failure).
  String? _handleInsertDocument(Map<String, dynamic> doc) {
    if (_selectedDbName.isEmpty || _selectedCollName.isEmpty) {
      return 'No collection selected.';
    }
    final service = mongoEngine;
    try {
      if (_editingDoc != null && _clonedDoc == null) {
        final id = (_editingDoc!['_id'] ?? doc['_id'])?.toString();
        if (id != null) {
          service.updateDocument(_selectedDbName, _selectedCollName, id, doc);
        }
      } else {
        service.insertDocument(_selectedDbName, _selectedCollName, doc);
      }
    } catch (err) {
      return '$err';
    }
    setState(() {
      _editingDoc = null;
      _clonedDoc = null;
    });
    return null;
  }

  /// Opens the Insert Document popup pre-filled with a copy of [doc] (with a
  /// fresh `_id`), mirroring Compass's "Duplicate document" action: the popup
  /// shows the copied value and the user confirms it with the Insert Document
  /// button.
  void _handleCloneDocument(MongoDocument doc) {
    if (_selectedDbName.isEmpty || _selectedCollName.isEmpty) return;
    setState(() {
      _editingDoc = null;
      _clonedDoc = Map<String, dynamic>.from(doc.data)
        ..['_id'] = mongoEngine.generateObjectId();
      _isInsertDocModalOpen = true;
    });
  }

  void _requestDeleteDocument(String docId, MongoDocument? doc) {
    final target = doc ??
        (mongoEngine
            .getDatabase(_selectedDbName)
            ?.collections[_selectedCollName]
            ?.documents
            .where((d) => d.id == docId)
            .firstOrNull);
    setState(() {
      _deleteDocId = docId;
      _deleteDocTarget = target;
      _isDeleteDocModalOpen = true;
    });
  }

  void _confirmDeleteDocument() {
    mongoEngine.deleteDocument(_selectedDbName, _selectedCollName, _deleteDocId);
    setState(() {
      _deleteDocTarget = null;
      _deleteDocId = '';
    });
  }

  void _handleUpdateDocument(String docId, Map<String, dynamic> updatedFields) {
    if (_selectedDbName.isEmpty || _selectedCollName.isEmpty) return;
    try {
      mongoEngine.updateDocument(_selectedDbName, _selectedCollName, docId, updatedFields);
    } catch (_) {}
    setState(() {});
  }

  void _openImportExport(ImportExportMode mode) {
    setState(() {
      _importExportMode = mode;
      _isImportExportModalOpen = true;
    });
  }

  void _openExportLanguage() {
    setState(() => _isExportLangModalOpen = true);
  }

  void _openSaveView(List<dynamic> pipeline, String pipelineJson) {
    setState(() {
      _saveViewPipeline = pipeline;
      _saveViewPipelineJson = pipelineJson;
      _isSaveViewModalOpen = true;
    });
  }

  void _handleResetData() {
    final engine = mongoEngine;
    if (engine is RealMongoService) {
      // Re-read the live server (the callback rebuilds the tree once done).
      engine.resetToDefaults();
      return;
    }
    engine.resetToDefaults();
    setState(() {
      _resetTabsTo('library', 'books');
    });
  }

  void _handleDisconnect() {
    _disposeRealService();
    setState(() {
      mongoEngine = LocalMongoEngine.instance;
      _connection = null;
      _resetTabsTo('library', 'books');
    });
  }

  void _requestTerminalConfirmation(RiskyOperationDetails operation, VoidCallback onConfirm) {
    setState(() {
      _pendingTerminalOperation = operation;
      _pendingTerminalConfirm = onConfirm;
    });
  }

  void _closeTerminalConfirmation() {
    setState(() {
      _pendingTerminalOperation = null;
      _pendingTerminalConfirm = null;
    });
  }

  void _confirmTerminalOperation() {
    final confirm = _pendingTerminalConfirm;
    _closeTerminalConfirmation();
    confirm?.call();
  }

  /// Executes a (already confirmed) mongosh command against the mock engine.
  void _executeTerminalCommand(String command) {
    final service = mongoEngine;
    final cmd = command.trim();

    if (RegExp(r'db\.dropDatabase\s*\(\s*\)').hasMatch(cmd)) {
      final droppedDb = _selectedDbName;
      service.dropDatabase(droppedDb);
      setState(() {
        _closeTabsMatching((tab) => tab.dbName == droppedDb);
        if (_openTabs.isEmpty) {
          final first = service.getDatabases().firstOrNull;
          final firstColl = first?.collections.keys.firstOrNull;
          if (first != null && firstColl != null) {
            _openCollectionTab(first.name, firstColl);
          }
        }
      });
      return;
    }

    final match = RegExp(r'db\.([A-Za-z0-9_]+)\.(\w+)\s*\((.*)\)\s*;?\s*$', dotAll: true).firstMatch(cmd);
    if (match == null) return;
    final collName = match.group(1)!;
    final method = match.group(2)!;
    final args = match.group(3) ?? '';

    Map<String, dynamic> parseArgs() {
      try {
        final parsed = service.tolerantParse(args);
        return parsed is Map ? Map<String, dynamic>.from(parsed) : <String, dynamic>{};
      } catch (_) {
        return <String, dynamic>{};
      }
    }

    if (method == 'drop') {
      final droppedDb = _selectedDbName;
      service.dropCollection(droppedDb, collName);
      _closeTabsMatching((tab) => tab.isSameTarget(droppedDb, collName));
    } else if (method == 'deleteMany' || method == 'remove') {
      service.deleteMany(_selectedDbName, collName, parseArgs());
    } else if (method == 'deleteOne') {
      service.deleteOne(_selectedDbName, collName, parseArgs());
    } else if (method == 'updateMany' || method == 'updateOne') {
      final split = _splitArgs(args);
      service.updateMany(_selectedDbName, collName, _parseMap(split.$1), _parseMap(split.$2));
    } else if (method == 'insertOne') {
      try {
        service.insertDocument(_selectedDbName, collName, parseArgs());
      } catch (_) {}
    }
    setState(() {});
  }

  (String, String) _splitArgs(String args) {
    // Splits a two-argument call such as `{...}, { $set: {...} }` at the top level.
    var depth = 0;
    for (var i = 0; i < args.length; i++) {
      final ch = args[i];
      if (ch == '{' || ch == '[' || ch == '(') depth++;
      if (ch == '}' || ch == ']' || ch == ')') depth--;
      if (ch == ',' && depth == 0) {
        return (args.substring(0, i), args.substring(i + 1));
      }
    }
    return (args, '{}');
  }

  Map<String, dynamic> _parseMap(String text) {
    try {
      final parsed = mongoEngine.tolerantParse(text);
      return parsed is Map ? Map<String, dynamic>.from(parsed) : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  /// Resolved theme palette for the current dark/light mode.
  ///
  /// NOTE: this state's own `context` sits *above* the root [CompassTheme]
  /// created in `build`, so `CompassTheme.of(context)` here would not find it
  /// and silently fall back to dark. Use the palette-only instance instead.
  CompassTheme get _theme => CompassTheme.palette(_isDarkMode);

  /// The app shell, hosted in an [OverlayEntry].
  ///
  /// The app has no [Navigator] (see the class doc comment), so it has to
  /// provide a root [Overlay] itself: Flutter inserts the text selection UI —
  /// the copy / paste context menu — into the nearest overlay, and a bare
  /// [EditableText] without an overlay ancestor throws when it tries.
  ///
  /// The entry is created once and rebuilt through [OverlayState]; the builder
  /// is a method so every rebuild produces a fresh shell (an [OverlayEntry]
  /// only calls its builder when the overlay rebuilds it).
  late final OverlayEntry _shellEntry = OverlayEntry(builder: _buildShell);

  /// Builds the app shell that lives inside the overlay entry.
  ///
  /// The shell is hosted by [_shellEntry] so that the root [Overlay] is an
  /// ancestor of every text field — Flutter's selection UI needs one.
  Widget _buildShell(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 768;
        _isTouchLayout = !isDesktop;
        _windowWidth = constraints.maxWidth;

        final service = mongoEngine;
        final dbs = service.getDatabases();
        final activeDb = service.getDatabase(_selectedDbName);
        final activeColl = activeDb?.collections[_selectedCollName];
        final docs = activeColl?.documents ?? [];
        final queryResult = service.findDocuments(_selectedDbName, _selectedCollName, _queryOptions);
        final pageDocs = queryResult.documents;

        final appShell = Container(
          color: _theme.bgApp,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header (h-14 / 56px)
                  CompassHeader(
                    connection: _connection,
                    showResetSample: _realService == null,
                    onOpenConnectModal: () {
                      setState(() => _isConnectModalOpen = true);
                    },
                    onDisconnect: _handleDisconnect,
                    onResetData: _handleResetData,
                    isTerminalOpen: _isTerminalOpen,
                    onToggleTerminal: () {
                      setState(() => _isTerminalOpen = !_isTerminalOpen);
                    },
                    isDarkMode: _isDarkMode,
                    onToggleDarkMode: () {
                      setState(() => _isDarkMode = !_isDarkMode);
                    },
                    onToggleMobileSidebar: () {
                      setState(() => _isMobileSidebarOpen = !_isMobileSidebarOpen);
                    },
                    isMobile: !isDesktop,
                    onOpenActions: () {
                      setState(() => _isHeaderActionsOpen = true);
                    },
                  ),

                  // Main Body: Side-by-side on desktop, or off-canvas sidebar
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (isDesktop || _isMobileSidebarOpen)
                          CompassSidebar(
                            databases: dbs,
                            selectedDb: _selectedDbName,
                            selectedColl: _selectedCollName,
                            onSelectDatabase: (dbName) {
                              setState(() {
                                final db = service.getDatabase(dbName);
                                final collName = db?.collections.keys.firstOrNull ?? '';
                                if (collName.isNotEmpty) {
                                  _openCollectionTab(dbName, collName);
                                } else {
                                  _selectedDbName = dbName;
                                  _selectedCollName = '';
                                }
                                _isMobileSidebarOpen = false;
                              });
                            },
                            onSelectCollection: (dbName, collName) {
                              setState(() {
                                _openCollectionTab(dbName, collName);
                                _isMobileSidebarOpen = false;
                              });
                            },
                            onOpenCreateDb: _openCreateDb,
                            onOpenCreateColl: (dbName) => _openCreateCollection(dbName),
                            onRenameDb: _openRenameDb,
                            onRenameColl: (dbName, collName, isView) =>
                                _openRenameColl(dbName, collName, isView),
                            onDropDb: _openDropDb,
                            onDropColl: _openDropColl,
                            onRefresh: () {
                              setState(() {});
                            },
                          ),

                        // Active Collection Main Pane
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_openTabs.isNotEmpty)
                                CollectionTabBar(
                                  tabs: _openTabs,
                                  activeIndex: _activeTabIndex,
                                  onSelect: (index) {
                                    setState(() => _activateTabIndex(index));
                                  },
                                  onClose: (index) {
                                    setState(() => _removeTabAt(index));
                                  },
                                ),

                              // Collection Header Bar: Title, Breadcrumbs, Tab Switcher
                              if (_activeTabIndex >= 0)
                                _buildCollectionHeader(activeDb, activeColl),

                              // Query Bar (only shown while a collection tab is open)
                              if (_activeTabIndex >= 0 && _activeTab == 'documents')
                                CompassQueryBar(
                                  options: _queryOptions,
                                  onChangeOptions: (updated) {
                                    setState(() => _queryOptions = updated);
                                  },
                                  onExecuteQuery: () {
                                    setState(() {});
                                  },
                                  onResetQuery: () {
                                    setState(() => _queryOptions = QueryFilterOptions());
                                  },
                                  onExportToLanguage: _openExportLanguage,
                                  optionsExpanded: _isQueryOptionsExpanded,
                                  onToggleOptions: () {
                                    setState(() =>
                                        _isQueryOptionsExpanded = !_isQueryOptionsExpanded);
                                  },
                                  onOpenOverflow: () {
                                    setState(() => _isQueryActionsOpen = true);
                                  },
                                  executionTimeMs: queryResult.executionTimeMs,
                                  totalResultsCount: queryResult.totalCount,
                                ),

                              // Documents View Sub-Header: Pagination
                              if (_activeTabIndex >= 0 && _activeTab == 'documents')
                                _buildDocumentsPagination(queryResult),

                              // Active Tab Content View
                              Expanded(
                                child: Container(
                                  color: _theme.bgApp,
                                  child: _activeTab == 'documents'
                                      ? _buildActiveTabView(activeColl, pageDocs)
                                      : SingleChildScrollView(
                                          padding: const EdgeInsets.all(16.0),
                                          child: _buildActiveTabView(activeColl, pageDocs),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Dockable Mongosh Shell at Bottom
                  CompassTerminal(
                    isOpen: _isTerminalOpen,
                    onClose: () {
                      setState(() => _isTerminalOpen = false);
                    },
                    activeDbName: _selectedDbName,
                    onExecuteCommand: (command) => _executeTerminalCommand(command),
                    onRequestConfirmation: _requestTerminalConfirmation,
                  ),
                ],
              ),

              // Connection Modal Overlay
              ConnectionModal(
                isOpen: _isConnectModalOpen,
                onClose: () {
                  setState(() => _isConnectModalOpen = false);
                },
                savedConnections: _savedConnections,
                onConnect: _handleConnectProfile,
                onSaveConnection: _handleSaveConnection,
                onDeleteConnection: _handleDeleteConnection,
                onConnectSampleData: _handleConnectSampleData,
              ),

              // ---- Popup / modal overlays (mirrors src/App.tsx) ----
              CreateDbModal(
                isOpen: _isCreateDbModalOpen,
                onClose: () => setState(() => _isCreateDbModalOpen = false),
                onSubmit: _handleCreateDbSubmit,
              ),
              CreateCollectionModal(
                isOpen: _isCreateCollModalOpen,
                onClose: () => setState(() => _isCreateCollModalOpen = false),
                databases: dbs,
                targetDbName: _createCollTargetDb,
                onCreated: _handleCreateCollSubmit,
              ),
              CreateIndexModal(
                isOpen: _isCreateIndexModalOpen,
                onClose: () => setState(() => _isCreateIndexModalOpen = false),
                dbName: _selectedDbName,
                collName: _selectedCollName,
                onCreated: () => setState(() {}),
              ),
              RenameModal(
                isOpen: _isRenameModalOpen,
                onClose: () => setState(() => _isRenameModalOpen = false),
                type: _renameType,
                dbName: _renameDbName,
                collName: _renameCollName,
                isView: _renameIsView,
                onSuccess: _handleRenameSuccess,
              ),
              DropDatabaseModal(
                isOpen: _isDropDbModalOpen,
                onClose: () => setState(() => _isDropDbModalOpen = false),
                onConfirm: _confirmDropDb,
                dbName: _dropDbName,
                collectionsCount: service.getDatabase(_dropDbName)?.collections.length ?? 0,
              ),
              DropCollectionModal(
                isOpen: _isDropCollModalOpen,
                onClose: () => setState(() => _isDropCollModalOpen = false),
                onConfirm: _confirmDropColl,
                dbName: _dropCollDbName,
                collName: _dropCollName,
                documentCount: _dropCollDocCount,
                indexesCount: _dropCollIndexesCount,
                isView: _dropCollIsView,
              ),
              DropIndexModal(
                isOpen: _isDropIndexModalOpen,
                onClose: () => setState(() => _isDropIndexModalOpen = false),
                onConfirm: _confirmDropIndex,
                dbName: _selectedDbName,
                collName: _selectedCollName,
                indexName: _dropIndexName,
              ),
              DeleteDocumentModal(
                isOpen: _isDeleteDocModalOpen,
                onClose: () => setState(() => _isDeleteDocModalOpen = false),
                onConfirm: _confirmDeleteDocument,
                dbName: _selectedDbName,
                collName: _selectedCollName,
                documentId: _deleteDocId,
                document: _deleteDocTarget,
              ),
              InsertDocumentModal(
                isOpen: _isInsertDocModalOpen,
                onClose: () => setState(() {
                  _isInsertDocModalOpen = false;
                  _clonedDoc = null;
                }),
                onInsert: _handleInsertDocument,
                initialDoc: _editingDoc ?? _clonedDoc,
                isClone: _clonedDoc != null,
              ),
              ImportExportModal(
                isOpen: _isImportExportModalOpen,
                onClose: () => setState(() => _isImportExportModalOpen = false),
                mode: _importExportMode,
                dbName: _selectedDbName,
                collName: _selectedCollName,
                documents: docs,
                onImportComplete: () => setState(() {}),
              ),
              ExportLanguageModal(
                isOpen: _isExportLangModalOpen,
                onClose: () => setState(() => _isExportLangModalOpen = false),
                dbName: _selectedDbName,
                collName: _selectedCollName,
                filter: _queryOptions.filter,
                sort: _queryOptions.sort,
              ),
              SaveViewModal(
                isOpen: _isSaveViewModalOpen,
                onClose: () => setState(() => _isSaveViewModalOpen = false),
                dbName: _selectedDbName,
                sourceCollName: _selectedCollName,
                pipeline: _saveViewPipeline,
                pipelineJsonString: _saveViewPipelineJson,
                onViewSaved: (newName) {
                  // A freshly saved view is a new collection: open it as a tab.
                  setState(() => _openCollectionTab(_selectedDbName, newName));
                },
              ),
              MongoshConfirmationModal(
                isOpen: _pendingTerminalOperation != null,
                operation: _pendingTerminalOperation,
                onConfirm: _confirmTerminalOperation,
                onCancel: _closeTerminalConfirmation,
              ),

              // Touch-only overflow sheet: the header actions that do not
              // fit on a narrow screen live here.
              CompassActionSheet(
                isOpen: _isHeaderActionsOpen,
                title: 'Actions',
                onClose: () => setState(() => _isHeaderActionsOpen = false),
                items: [
                  CompassActionSheetItem(
                    label: 'Change connection',
                    svg: CompassSvgIcons.zap,
                    onTap: () {
                      setState(() => _isConnectModalOpen = true);
                    },
                  ),
                  if (_realService == null)
                    CompassActionSheetItem(
                      label: 'Reset sample data',
                      svg: CompassSvgIcons.rotateCcw,
                      onTap: _handleResetData,
                    ),
                  CompassActionSheetItem(
                    label: _isTerminalOpen ? 'Close _mongosh' : 'Open _mongosh',
                    svg: CompassSvgIcons.terminal,
                    onTap: () {
                      setState(() => _isTerminalOpen = !_isTerminalOpen);
                    },
                  ),
                  if (_connection != null)
                    CompassActionSheetItem(
                      label: 'Disconnect',
                      svg: CompassSvgIcons.close,
                      destructive: true,
                      onTap: _handleDisconnect,
                    ),
                ],
              ),

              // Touch-only overflow sheet: the query-bar actions that do not
              // fit on a narrow screen live here. It has to be a root-level
              // child — the sheet is a `Positioned.fill` overlay, so hosting
              // it inside the query bar would squeeze it into a sliver.
              CompassActionSheet(
                isOpen: _isQueryActionsOpen,
                title: 'Query actions',
                onClose: () => setState(() => _isQueryActionsOpen = false),
                items: [
                  CompassActionSheetItem(
                    label: _isQueryOptionsExpanded
                        ? 'Hide options'
                        : 'Options (project, sort, skip, limit)',
                    svg: CompassSvgIcons.sliders,
                    onTap: () {
                      setState(() {
                        _isQueryOptionsExpanded = !_isQueryOptionsExpanded;
                      });
                    },
                  ),
                  CompassActionSheetItem(
                    label: 'Reset query',
                    svg: CompassSvgIcons.rotateCcw,
                    onTap: () {
                      setState(() => _queryOptions = QueryFilterOptions());
                    },
                  ),
                  CompassActionSheetItem(
                    label: 'Show generated code',
                    svg: CompassSvgIcons.code,
                    onTap: _openExportLanguage,
                  ),
                ],
              ),
            ],
          ),
        );

        // Touch-sized targets below the breakpoint, mouse-sized above it.
        return CompassDensity.forWidth(
          width: constraints.maxWidth,
          child: appShell,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content = Directionality(
      textDirection: TextDirection.ltr,
      child: TapRegionSurface(
        // [TapRegionSurface] is what [WidgetsApp] would normally provide: it
        // tells the text fields when the user taps outside of them, which is
        // how the copy / paste context menu is dismissed. It has to wrap the
        // overlay so that the menu — which lives in the overlay — counts as
        // part of the field's region.
        child: Overlay(
          // The context menu may extend past the window edge (it is anchored
          // to the text field), so the overlay must not clip its entries.
          clipBehavior: Clip.none,
          initialEntries: <OverlayEntry>[_shellEntry],
        ),
      ),
    );

    if (MediaQuery.maybeOf(context) == null) {
      final view = View.maybeOf(context);
      if (view != null) {
        content = MediaQuery.fromView(
          view: view,
          child: content,
        );
      } else {
        content = MediaQuery(
          data: const MediaQueryData(),
          child: content,
        );
      }
    }

    // Propagate the current theme mode to the whole tree so widgets can read
    // it via `CompassTheme.of(context)` instead of taking an `isDarkMode`
    // parameter. (See theme/compass_theme.dart.)
    content = CompassTheme(isDarkMode: _isDarkMode, child: content);

    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: const Color(0x00000000),
      statusBarIconBrightness: _isDarkMode ? Brightness.light : Brightness.dark,
      statusBarBrightness: _isDarkMode ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: _theme.bgApp,
      systemNavigationBarIconBrightness: _isDarkMode ? Brightness.light : Brightness.dark,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: content,
    );
  }

  Widget _buildCollectionHeader(MongoDatabase? activeDb, MongoCollection? activeColl) {
    return Container(
      decoration: BoxDecoration(
        color: _theme.bgPanel,
        border: Border(
          bottom: BorderSide(color: _theme.border, width: 1.0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Breadcrumbs Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // The breadcrumb takes whatever the actions leave behind and
                // ellipsizes the names instead of overflowing.
                Expanded(
                  child: Row(
                    children: [
                      CompassSvg(
                        svgString: CompassSvgIcons.database,
                        size: 15.0,
                        color: _theme.accent,
                      ),
                      const SizedBox(width: 6.0),
                      Flexible(
                        child: Text(
                          _selectedDbName,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: CompassTypography.header(color: _theme.textPrimary),
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Text('>', style: CompassTypography.caption(color: _theme.textMuted)),
                      const SizedBox(width: 8.0),
                      CompassSvg(
                        svgString: CompassSvgIcons.table,
                        size: 15.0,
                        color: _theme.textSecondary,
                      ),
                      const SizedBox(width: 6.0),
                      Flexible(
                        child: Text(
                          _selectedCollName,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: CompassTypography.title(color: _theme.textPrimary),
                        ),
                      ),
                      if (!_isTouchLayout) ...[
                        const SizedBox(width: 8.0),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                          decoration: BoxDecoration(
                            color: _theme.bgSubtle,
                            borderRadius: BorderRadius.circular(4.0),
                            border: Border.all(color: _theme.border, width: 1.0),
                          ),
                          child: Text(
                            '${activeColl?.documents.length ?? 0} docs',
                            style: CompassTypography.caption(color: _theme.textMuted),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Right-side actions: collection actions + view mode switcher
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8.0,
                  runSpacing: 6.0,
                  children: [
                    if (activeColl != null) ...[
                      _buildHeaderAction(
                        svg: CompassSvgIcons.plus,
                        label: 'New Coll',
                        iconColor: _theme.accent,
                        onTap: () => _openCreateCollection(_selectedDbName),
                      ),
                      _buildHeaderAction(
                        svg: activeColl.isView ? CompassSvgIcons.eye : CompassSvgIcons.pencil,
                        label: activeColl.isView ? 'Rename View' : 'Rename Coll',
                        iconColor: _theme.accent,
                        onTap: () => _openRenameColl(_selectedDbName, _selectedCollName, activeColl.isView),
                      ),
                      _buildHeaderAction(
                        svg: CompassSvgIcons.trash,
                        label: activeColl.isView ? 'Drop View' : 'Drop Coll',
                        iconColor: _theme.textMuted,
                        onTap: () => _openDropColl(_selectedDbName, _selectedCollName),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Tabs Strip
          Row(
            children: [
              // Left: section tabs
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 16.0),
                  child: Row(
                    children: [
                      _buildTab('documents', 'Documents', CompassSvgIcons.table),
                      _buildTab('aggregations', 'Aggregations', CompassSvgIcons.layers),
                      _buildTab('schema', 'Schema', CompassSvgIcons.barChart),
                      _buildTab('indexes', 'Indexes', CompassSvgIcons.key),
                    ],
                  ),
                ),
              ),

              // Right: documents-tab actions (Insert / Import / Export)
              if (_activeTab == 'documents' && activeColl != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      _buildDocumentsAction(activeColl),
                      const SizedBox(width: 8.0),
                      _buildHeaderAction(
                        svg: CompassSvgIcons.upload,
                        label: 'Import',
                        iconColor: _theme.textMuted,
                        onTap: () => _openImportExport(ImportExportMode.import),
                      ),
                      const SizedBox(width: 8.0),
                      _buildHeaderAction(
                        svg: CompassSvgIcons.download,
                        label: 'Export',
                        iconColor: _theme.textMuted,
                        onTap: () => _openImportExport(ImportExportMode.export),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// The documents-tab primary action: "Insert Document", or the read-only
  /// badge when the open collection is a view.
  ///
  /// On touch layouts the labelled variants do not fit next to the tab strip,
  /// so they collapse into icon buttons.
  Widget _buildDocumentsAction(MongoCollection activeColl) {
    if (activeColl.isView) {
      if (_isTouchLayout) {
        return CompassIconButton(
          svgString: CompassSvgIcons.eye,
          onTap: () {},
          size: 15.0,
          padding: 8.0,
          color: CompassColors.warningAmber,
          semanticLabel: 'Read-only view',
        );
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
        decoration: BoxDecoration(
          color: CompassColors.warningAmberBg,
          borderRadius: BorderRadius.circular(6.0),
          border: Border.all(color: CompassColors.warningAmberBorder, width: 1.0),
        ),
        child: Row(
          children: [
            const CompassSvg(
              svgString: CompassSvgIcons.eye,
              size: 13.0,
              color: CompassColors.warningAmber,
            ),
            const SizedBox(width: 6.0),
            Text(
              'Read-Only View',
              style: CompassTypography.bodyMedium(color: CompassColors.warningAmber),
            ),
          ],
        ),
      );
    }

    if (_isTouchLayout) {
      return CompassIconButton(
        svgString: CompassSvgIcons.plus,
        onTap: _openInsertDocument,
        size: 15.0,
        padding: 8.0,
        color: _theme.accent,
        semanticLabel: 'Insert document',
      );
    }

    return CompassPrimaryButton(
      label: 'Insert Document',
      iconSvg: CompassSvgIcons.plus,
      onTap: _openInsertDocument,
    );
  }

  Widget _buildTab(String tabKey, String title, String svgString) {
    final isActive = _activeTab == tabKey;
    return GestureDetector(
      onTap: () {
        setState(() => _activeTab = tabKey);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? _theme.accent : const Color(0x00000000),
              width: 2.0,
            ),
          ),
        ),
        child: Row(
          children: [
            CompassSvg(
              svgString: svgString,
              size: 14.0,
              color: isActive ? _theme.accent : _theme.textMuted,
            ),
            const SizedBox(width: 6.0),
            Text(
              title,
              style: isActive
                  ? CompassTypography.header(color: _theme.accent)
                  : CompassTypography.bodyRegular(color: _theme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderAction({
    required String svg,
    required String label,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    // On a narrow window the labelled chip does not fit next to the
    // breadcrumbs, so it collapses into a finger-sized icon button.
    if (_isCompactLayout) {
      return CompassIconButton(
        svgString: svg,
        onTap: onTap,
        size: 15.0,
        padding: 8.0,
        color: iconColor,
        semanticLabel: label,
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
        decoration: BoxDecoration(
          color: _theme.bgSubtle,
          borderRadius: BorderRadius.circular(6.0),
          border: Border.all(color: _theme.border, width: 1.0),
        ),
        child: Row(
          children: [
            CompassSvg(svgString: svg, size: 13.0, color: iconColor),
            const SizedBox(width: 5.0),
            Text(
              label,
              style: CompassTypography.caption(color: _theme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewModeBtn(String mode, String svg, String tooltip) {
    final isActive = _docViewMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() => _docViewMode = mode);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: isActive ? _theme.bgPanel : const Color(0x00000000),
          borderRadius: BorderRadius.circular(4.0),
          border: isActive ? Border.all(color: _theme.border, width: 1.0) : null,
        ),
        child: Row(
          children: [
            CompassSvg(
              svgString: svg,
              size: 13.0,
              color: isActive ? _theme.accent : _theme.textMuted,
            ),
            const SizedBox(width: 4.0),
            Text(
              tooltip,
              style: CompassTypography.caption(
                color: isActive ? _theme.textPrimary : _theme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Documents view sub-header. Mirrors the "Documents View Sub-Header" in
  /// src/App.tsx: the document view-mode switcher (Tree / JSON / Table) sits on
  /// the left, and the result range with the Prev/Next page navigator sits on
  /// the right. The page controls adjust the `skip` value on the shared
  /// [QueryFilterOptions]; `limit` acts as the page size.
  Widget _buildDocumentsPagination(QueryResult result) {
    final total = result.totalCount;
    final pageSize = _queryOptions.limit < 1 ? 1 : _queryOptions.limit;
    final skip = _queryOptions.skip < 0 ? 0 : _queryOptions.skip;
    final pageCount = result.documents.length;

    String rangeLabel;
    if (pageCount == 0 || total == 0) {
      rangeLabel = '0 documents';
    } else {
      final start = skip + 1;
      final end = (skip + pageSize) < total ? (skip + pageSize) : total;
      rangeLabel = '$start – $end of $total';
    }

    final canGoPrev = skip > 0 && total > 0;
    final canGoNext = (skip + pageSize) < total;

    final viewModeSwitcher = Container(
      padding: const EdgeInsets.all(2.0),
      decoration: BoxDecoration(
        color: _theme.bgSubtle,
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: _theme.border, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildViewModeBtn('tree', CompassSvgIcons.layers, 'Tree'),
          const SizedBox(width: 2.0),
          _buildViewModeBtn('json', CompassSvgIcons.code, 'JSON'),
          const SizedBox(width: 2.0),
          _buildViewModeBtn('table', CompassSvgIcons.table, 'Table'),
        ],
      ),
    );

    final pager = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(rangeLabel, style: CompassTypography.monoSmall(color: _theme.textMuted)),
        const SizedBox(width: 12.0),
        _buildPageButton(
          svg: CompassSvgIcons.chevronLeft,
          tooltip: 'Previous page',
          enabled: canGoPrev,
          onTap: () {
            setState(() {
              final next = skip - pageSize;
              _queryOptions = _queryOptions.copyWith(skip: next < 0 ? 0 : next);
            });
          },
        ),
        const SizedBox(width: 4.0),
        _buildPageButton(
          svg: CompassSvgIcons.chevronRight,
          tooltip: 'Next page',
          enabled: canGoNext,
          onTap: () {
            setState(() => _queryOptions = _queryOptions.copyWith(skip: skip + pageSize));
          },
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: _theme.bgPanel,
        border: Border(bottom: BorderSide(color: _theme.border, width: 1.0)),
      ),
      // On a phone the switcher, the range label and the pager do not fit on
      // one line, so they scroll sideways instead of being clipped.
      child: _isTouchLayout
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  viewModeSwitcher,
                  const SizedBox(width: 16.0),
                  pager,
                ],
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                viewModeSwitcher,
                pager,
              ],
            ),
    );
  }

  Widget _buildPageButton({
    required String svg,
    required String tooltip,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return CompassIconButton(
      svgString: svg,
      onTap: enabled ? onTap : null,
      size: 16.0,
      padding: 4.0,
      color: enabled ? _theme.textSecondary : _theme.border,
      semanticLabel: tooltip,
    );
  }

  /// Empty state for the documents view (mirrors the React viewport fallback).
  Widget _buildDocumentsEmptyState(MongoCollection activeColl) {
    final hasFilter = _queryOptions.filter.trim().isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 64.0, horizontal: 24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48.0,
            height: 48.0,
            decoration: BoxDecoration(
              color: _theme.bgPanel,
              shape: BoxShape.circle,
              border: Border.all(color: _theme.border, width: 1.0),
            ),
            alignment: Alignment.center,
            child: CompassSvg(
              svgString: CompassSvgIcons.code,
              size: 22.0,
              color: _theme.textMuted,
            ),
          ),
          const SizedBox(height: 12.0),
          Text('No Documents Found', style: CompassTypography.header(color: _theme.textPrimary)),
          const SizedBox(height: 6.0),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360.0),
            child: Text(
              hasFilter
                  ? 'No documents in this collection matched your filter expression.'
                  : 'This collection is empty. You can add documents or import datasets.',
              textAlign: TextAlign.center,
              style: CompassTypography.bodyMedium(color: _theme.textMuted),
            ),
          ),
          if (!activeColl.isView) ...[
            const SizedBox(height: 16.0),
            CompassPrimaryButton(
              label: 'Insert First Document',
              iconSvg: CompassSvgIcons.plus,
              onTap: _openInsertDocument,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveTabView(
    MongoCollection? activeColl,
    List<MongoDocument> docs,
  ) {
    if (activeColl == null) {
      return Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(48.0),
        child: Text(
          'Select a collection to view data',
          style: CompassTypography.bodyMedium(color: _theme.textMuted),
        ),
      );
    }

    switch (_activeTab) {
      case 'documents':
        if (docs.isEmpty) {
          return _buildDocumentsEmptyState(activeColl);
        }
        if (_docViewMode == 'tree') {
          return DocumentTreeView(
            documents: docs,
            onEditDocument: _openEditDocument,
            onCloneDocument: _handleCloneDocument,
            onDeleteDocument: _requestDeleteDocument,
          );
        } else if (_docViewMode == 'json') {
          return DocumentJsonView(
            documents: docs,
            onUpdateDocument: _handleUpdateDocument,
            onCloneDocument: _handleCloneDocument,
            onDeleteDocument: _requestDeleteDocument,
          );
        } else {
          return DocumentTableView(
            documents: docs,
            onEditDocument: _openEditDocument,
            onDeleteDocument: _requestDeleteDocument,
          );
        }
      case 'aggregations':
        return AggregationsView(
          dbName: _selectedDbName,
          collName: _selectedCollName,
          onSaveAsView: _openSaveView,
          onExportCode: _openExportLanguage,
        );
      case 'schema':
        // SchemaView owns its analysis state: it re-runs `analyzeSchema` on
        // open, on collection change, and when its Analyze button is pressed.
        return SchemaView(
          dbName: _selectedDbName,
          collName: _selectedCollName,
        );
      case 'indexes':
        return IndexesView(
          dbName: _selectedDbName,
          collName: _selectedCollName,
          indexes: activeColl.indexes,
          onCreateIndex: () => setState(() => _isCreateIndexModalOpen = true),
          onDropIndex: (idxName) => setState(() {
            _dropIndexName = idxName;
            _isDropIndexModalOpen = true;
          }),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
