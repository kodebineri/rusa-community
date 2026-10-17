import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'dart:async';
import 'theme/compass_colors.dart';
import 'theme/compass_typography.dart';
import 'icons/compass_svg_icons.dart';
import 'models/mongo_models.dart';
import 'models/collection_tab.dart';
import 'services/local_mongo_engine.dart';
import 'services/mongo_engine.dart';
import 'services/real_mongo_service.dart';
import 'widgets/compass_header.dart';
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
import 'widgets/modals/rename_modal.dart';
import 'widgets/modals/drop_collection_modal.dart';
import 'widgets/modals/drop_database_modal.dart';
import 'widgets/modals/delete_document_modal.dart';
import 'widgets/modals/insert_document_modal.dart';
import 'widgets/modals/import_export_modal.dart';
import 'widgets/modals/export_language_modal.dart';
import 'widgets/modals/save_view_modal.dart';
import 'widgets/modals/mongosh_confirmation_modal.dart';
import 'widgets/modals/compass_modal.dart';

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

  bool _isDeleteDocModalOpen = false;
  String _deleteDocId = '';
  MongoDocument? _deleteDocTarget;

  bool _isInsertDocModalOpen = false;
  Map<String, dynamic>? _editingDoc;

  bool _isImportExportModalOpen = false;
  ImportExportMode _importExportMode = ImportExportMode.export;

  bool _isExportLangModalOpen = false;

  bool _isSaveViewModalOpen = false;
  List<dynamic> _saveViewPipeline = const [];
  String _saveViewPipelineJson = '[]';

  RiskyOperationDetails? _pendingTerminalOperation;
  VoidCallback? _pendingTerminalConfirm;

  String _selectedDbName = 'sample_mflix';
  String _selectedCollName = 'movies';
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
    CollectionTab(dbName: 'sample_mflix', collName: 'movies'),
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
  /// and selects `sample_mflix.movies`, mirroring React's "Load Sample
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
      _resetTabsTo('sample_mflix', 'movies');
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

  void _openInsertDocument() {
    setState(() {
      _editingDoc = null;
      _isInsertDocModalOpen = true;
    });
  }

  void _openEditDocument(MongoDocument doc) {
    setState(() {
      _editingDoc = Map<String, dynamic>.from(doc.data);
      _isInsertDocModalOpen = true;
    });
  }

  void _handleInsertDocument(Map<String, dynamic> doc) {
    if (_selectedDbName.isEmpty || _selectedCollName.isEmpty) return;
    final service = mongoEngine;
    try {
      if (_editingDoc != null) {
        final id = (_editingDoc!['_id'] ?? doc['_id'])?.toString();
        if (id != null) {
          service.updateDocument(_selectedDbName, _selectedCollName, id, doc);
        }
      } else {
        service.insertDocument(_selectedDbName, _selectedCollName, doc);
      }
    } catch (_) {
      // Ignore mutation errors in this mock client.
    }
    setState(() => _editingDoc = null);
  }

  void _handleCloneDocument(MongoDocument doc) {
    if (_selectedDbName.isEmpty || _selectedCollName.isEmpty) return;
    final service = mongoEngine;
    final clone = Map<String, dynamic>.from(doc.data)
      ..['_id'] = service.generateObjectId();
    try {
      service.insertDocument(_selectedDbName, _selectedCollName, clone);
    } catch (_) {}
    setState(() {});
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
      _resetTabsTo('sample_mflix', 'movies');
    });
  }

  void _handleDisconnect() {
    _disposeRealService();
    setState(() {
      mongoEngine = LocalMongoEngine.instance;
      _connection = null;
      _resetTabsTo('sample_mflix', 'movies');
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
      service.dropDatabase(_selectedDbName);
      setState(() {
        final first = service.getDatabases().firstOrNull;
        _selectedDbName = first?.name ?? '';
        _selectedCollName = first?.collections.keys.firstOrNull ?? '';
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
      service.dropCollection(_selectedDbName, collName);
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

  @override
  Widget build(BuildContext context) {
    Widget content = Directionality(
      textDirection: TextDirection.ltr,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 768;

          final service = mongoEngine;
          final dbs = service.getDatabases();
          final activeDb = service.getDatabase(_selectedDbName);
          final activeColl = activeDb?.collections[_selectedCollName];
          final docs = activeColl?.documents ?? [];
          final queryResult = service.findDocuments(_selectedDbName, _selectedCollName, _queryOptions);
          final pageDocs = queryResult.documents;
          final schemaFields = service.analyzeSchema(_selectedDbName, _selectedCollName);

          return Container(
            color: _isDarkMode ? CompassColors.darkBgApp : CompassColors.lightBgApp,
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
                                  // Reset paging/filter when the database changes.
                                  _queryOptions = _queryOptions.copyWith(filter: '', skip: 0);
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
                                _buildCollectionHeader(activeDb, activeColl),

                                // Query Bar (only shown in documents tab)
                                if (_activeTab == 'documents')
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
                                    executionTimeMs: queryResult.executionTimeMs,
                                    totalResultsCount: queryResult.totalCount,
                                  ),

                                // Documents View Sub-Header: Pagination
                                if (_activeTab == 'documents')
                                  _buildDocumentsPagination(queryResult),

                                // Active Tab Content View
                                Expanded(
                                  child: Container(
                                    color: _isDarkMode ? CompassColors.darkBgApp : CompassColors.lightBgApp,
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.all(16.0),
                                      child: _buildActiveTabView(activeColl, pageDocs, schemaFields),
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
                  onClose: () => setState(() => _isInsertDocModalOpen = false),
                  onInsert: _handleInsertDocument,
                  initialDoc: _editingDoc,
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
                    setState(() => _selectedCollName = newName);
                  },
                ),
                MongoshConfirmationModal(
                  isOpen: _pendingTerminalOperation != null,
                  operation: _pendingTerminalOperation,
                  onConfirm: _confirmTerminalOperation,
                  onCancel: _closeTerminalConfirmation,
                ),
              ],
            ),
          );
        },
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

    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: const Color(0x00000000),
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: _isDarkMode ? CompassColors.darkBgApp : CompassColors.lightBgApp,
      systemNavigationBarIconBrightness: _isDarkMode ? Brightness.light : Brightness.dark,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: content,
    );
  }

  Widget _buildCollectionHeader(MongoDatabase? activeDb, MongoCollection? activeColl) {
    return Container(
      decoration: const BoxDecoration(
        color: CompassColors.darkBgPanel,
        border: Border(
          bottom: BorderSide(color: CompassColors.darkBorder, width: 1.0),
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
                Row(
                  children: [
                    const CompassSvg(
                      svgString: CompassSvgIcons.database,
                      size: 15.0,
                      color: CompassColors.greenAccent,
                    ),
                    const SizedBox(width: 6.0),
                    Text(
                      _selectedDbName,
                      style: CompassTypography.header(color: CompassColors.darkTextPrimary),
                    ),
                    const SizedBox(width: 8.0),
                    Text('>', style: CompassTypography.caption(color: CompassColors.darkTextMuted)),
                    const SizedBox(width: 8.0),
                    const CompassSvg(
                      svgString: CompassSvgIcons.table,
                      size: 15.0,
                      color: CompassColors.darkTextSecondary,
                    ),
                    const SizedBox(width: 6.0),
                    Text(
                      _selectedCollName,
                      style: CompassTypography.title(color: CompassColors.darkTextPrimary),
                    ),
                    const SizedBox(width: 8.0),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                      decoration: BoxDecoration(
                        color: CompassColors.darkBgSubtle,
                        borderRadius: BorderRadius.circular(4.0),
                        border: Border.all(color: CompassColors.darkBorder, width: 1.0),
                      ),
                      child: Text(
                        '${activeColl?.documents.length ?? 0} docs',
                        style: CompassTypography.caption(color: CompassColors.darkTextMuted),
                      ),
                    ),
                  ],
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
                        iconColor: CompassColors.greenAccent,
                        onTap: () => _openCreateCollection(_selectedDbName),
                      ),
                      _buildHeaderAction(
                        svg: activeColl.isView ? CompassSvgIcons.eye : CompassSvgIcons.pencil,
                        label: activeColl.isView ? 'Rename View' : 'Rename Coll',
                        iconColor: CompassColors.greenAccent,
                        onTap: () => _openRenameColl(_selectedDbName, _selectedCollName, activeColl.isView),
                      ),
                      _buildHeaderAction(
                        svg: CompassSvgIcons.trash,
                        label: activeColl.isView ? 'Drop View' : 'Drop Coll',
                        iconColor: CompassColors.darkTextMuted,
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
                      if (activeColl.isView)
                        Container(
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
                        )
                      else
                        CompassPrimaryButton(
                          label: 'Insert Document',
                          iconSvg: CompassSvgIcons.plus,
                          onTap: _openInsertDocument,
                        ),
                      const SizedBox(width: 8.0),
                      _buildHeaderAction(
                        svg: CompassSvgIcons.upload,
                        label: 'Import',
                        iconColor: CompassColors.darkTextMuted,
                        onTap: () => _openImportExport(ImportExportMode.import),
                      ),
                      const SizedBox(width: 8.0),
                      _buildHeaderAction(
                        svg: CompassSvgIcons.download,
                        label: 'Export',
                        iconColor: CompassColors.darkTextMuted,
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
              color: isActive ? CompassColors.greenAccent : const Color(0x00000000),
              width: 2.0,
            ),
          ),
        ),
        child: Row(
          children: [
            CompassSvg(
              svgString: svgString,
              size: 14.0,
              color: isActive ? CompassColors.greenAccent : CompassColors.darkTextMuted,
            ),
            const SizedBox(width: 6.0),
            Text(
              title,
              style: isActive
                  ? CompassTypography.header(color: CompassColors.greenAccent)
                  : CompassTypography.bodyRegular(color: CompassColors.darkTextSecondary),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
        decoration: BoxDecoration(
          color: CompassColors.darkBgSubtle,
          borderRadius: BorderRadius.circular(6.0),
          border: Border.all(color: CompassColors.darkBorder, width: 1.0),
        ),
        child: Row(
          children: [
            CompassSvg(svgString: svg, size: 13.0, color: iconColor),
            const SizedBox(width: 5.0),
            Text(
              label,
              style: CompassTypography.caption(color: CompassColors.darkTextSecondary),
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
          color: isActive ? CompassColors.darkBgPanel : const Color(0x00000000),
          borderRadius: BorderRadius.circular(4.0),
          border: isActive ? Border.all(color: CompassColors.darkBorder, width: 1.0) : null,
        ),
        child: Row(
          children: [
            CompassSvg(
              svgString: svg,
              size: 13.0,
              color: isActive ? CompassColors.greenAccent : CompassColors.darkTextMuted,
            ),
            const SizedBox(width: 4.0),
            Text(
              tooltip,
              style: CompassTypography.caption(
                color: isActive ? CompassColors.darkTextPrimary : CompassColors.darkTextMuted,
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      decoration: const BoxDecoration(
        color: CompassColors.darkBgPanel,
        border: Border(bottom: BorderSide(color: CompassColors.darkBorder, width: 1.0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: document view mode switcher (Tree / JSON / Table)
          Container(
            padding: const EdgeInsets.all(2.0),
            decoration: BoxDecoration(
              color: CompassColors.darkBgSubtle,
              borderRadius: BorderRadius.circular(6.0),
              border: Border.all(color: CompassColors.darkBorder, width: 1.0),
            ),
            child: Row(
              children: [
                _buildViewModeBtn('tree', CompassSvgIcons.layers, 'Tree'),
                const SizedBox(width: 2.0),
                _buildViewModeBtn('json', CompassSvgIcons.code, 'JSON'),
                const SizedBox(width: 2.0),
                _buildViewModeBtn('table', CompassSvgIcons.table, 'Table'),
              ],
            ),
          ),
          // Right: result range + page navigator
          Row(
            children: [
              Text(rangeLabel, style: CompassTypography.monoSmall(color: CompassColors.darkTextMuted)),
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
          ),
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
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(4.0),
        child: CompassSvg(
          svgString: svg,
          size: 16.0,
          color: enabled ? CompassColors.darkTextSecondary : CompassColors.darkBorder,
        ),
      ),
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
              color: CompassColors.darkBgPanel,
              shape: BoxShape.circle,
              border: Border.all(color: CompassColors.darkBorder, width: 1.0),
            ),
            alignment: Alignment.center,
            child: const CompassSvg(
              svgString: CompassSvgIcons.code,
              size: 22.0,
              color: CompassColors.darkTextMuted,
            ),
          ),
          const SizedBox(height: 12.0),
          Text('No Documents Found', style: CompassTypography.header(color: CompassColors.darkTextPrimary)),
          const SizedBox(height: 6.0),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360.0),
            child: Text(
              hasFilter
                  ? 'No documents in this collection matched your filter expression.'
                  : 'This collection is empty. You can add documents or import datasets.',
              textAlign: TextAlign.center,
              style: CompassTypography.bodyMedium(color: CompassColors.darkTextMuted),
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
    List<SchemaFieldStat> schemaFields,
  ) {
    if (activeColl == null) {
      return Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(48.0),
        child: Text('Select a collection to view data', style: CompassTypography.bodyMedium()),
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
        return SchemaView(
          dbName: _selectedDbName,
          collName: _selectedCollName,
          fields: schemaFields,
          onAnalyze: () {
            setState(() {});
          },
        );
      case 'indexes':
        return IndexesView(
          dbName: _selectedDbName,
          collName: _selectedCollName,
          indexes: activeColl.indexes,
          onCreateIndex: () {},
          onDropIndex: (idxName) {},
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
