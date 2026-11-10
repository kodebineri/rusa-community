import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'theme/compass_colors.dart';
import 'theme/compass_density.dart';
import 'theme/compass_theme.dart';
import 'theme/compass_theme_presets.dart';
import 'theme/compass_typography.dart';
import 'icons/compass_svg_icons.dart';
import 'models/mongo_models.dart';
import 'models/collection_tab.dart';
import 'services/local_mongo_engine.dart';
import 'services/mongo_engine.dart';
import 'services/mongosh_interpreter.dart';
import 'services/real_mongo_service.dart';
import 'services/app_preferences.dart';
import 'widgets/compass_header.dart';
import 'widgets/compass_hover.dart';
import 'widgets/compass_icon_button.dart';
import 'widgets/collection_tab_bar.dart';
import 'widgets/compass_sidebar.dart';
import 'widgets/compass_spinner.dart';
import 'widgets/compass_query_bar.dart';
import 'widgets/compass_terminal.dart';
import 'widgets/views/document_tree_view.dart';
import 'widgets/views/document_json_view.dart';
import 'widgets/views/document_table_view.dart';
import 'widgets/views/aggregations_view.dart';
import 'widgets/views/schema_view.dart';
import 'widgets/views/indexes_view.dart';
import 'widgets/views/show_ddl_view.dart';
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
import 'widgets/modals/save_view_modal.dart';
import 'widgets/modals/mongosh_confirmation_modal.dart';
import 'widgets/modals/eula_modal.dart';
import 'widgets/modals/onboarding_modal.dart';
import 'widgets/modals/privacy_policy_modal.dart';
import 'widgets/modals/about_modal.dart';
import 'widgets/modals/compass_modal.dart';
import 'widgets/modals/compass_action_sheet.dart';

void main() {
  // The app intentionally avoids MaterialApp/WidgetsApp, which normally install
  // the default text-editing shortcuts (Backspace, arrow keys, Home/End,
  // Ctrl+C/V...). Without this, bare EditableText fields accept typed
  // characters but ignore those editing keys.
  runApp(const DefaultTextEditingShortcuts(child: CompassApp()));
}

/// Root Rusa application — an independent MongoDB database client.
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
  /// The app-level [Overlay] created in [build]. Transient dialogs must be
  /// inserted through this key: [State.context] sits *above* that overlay, so
  /// `Overlay.of(context)` finds no overlay and throws.
  final GlobalKey<OverlayState> _overlayKey = GlobalKey<OverlayState>();

  /// Whether the user has accepted the EULA. `null` while the stored flags are
  /// being read; the first-run cover blocks the app while it is `null`.
  bool? _eulaAccepted;

  /// Whether the welcome tour has been dismissed for good (`onboarding_done`).
  bool _onboardingDone = false;

  /// True while the welcome tour covers the app. Decided at startup and
  /// re-armed by the header's "Show Welcome Screen" entry.
  bool _isOnboardingOpen = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  /// Reads every persisted flag once (consent, tour, theme) and decides what
  /// covers the app: the welcome tour, or the connection popup as before.
  Future<void> _loadPreferences() async {
    StoredPreferences stored;
    try {
      stored = await appPreferences.load();
    } catch (_) {
      // Never leave the user locked out if the store is unavailable.
      stored = const StoredPreferences(
        eulaAccepted: false,
        onboardingDone: false,
      );
    }
    if (!mounted) return;
    // A first-time user reads the tour (which ends in licence acceptance)
    // instead of being dropped straight into the connect popup — the tour's
    // second slide is about exploring the bundled sample data first.
    final showTour = stored.shouldShowOnboarding;
    setState(() {
      _eulaAccepted = stored.eulaAccepted;
      _onboardingDone = stored.onboardingDone;
      _themeVariant = CompassThemeVariant.fromName(stored.themeVariantName);
      // Null means the device has no stored list yet: keep the built-in
      // sample profiles. An empty list is a real user choice (all deleted).
      if (stored.savedConnections != null) {
        _savedConnections = stored.savedConnections!;
      }
      _isOnboardingOpen = showTour;
      _isConnectModalOpen = !showTour;
    });
  }

  /// Called by the welcome tour's last slide. Persists consent (first run only)
  /// and the "don't show this again" choice, then reveals the app shell.
  void _finishOnboarding({required bool dontShowAgain}) {
    final needsConsent = _eulaAccepted != true;
    setState(() {
      _eulaAccepted = true;
      _onboardingDone = dontShowAgain;
      _isOnboardingOpen = false;
      // Finishing the tour lands on the sample data, not the connect popup.
      _isConnectModalOpen = false;
    });
    if (needsConsent) unawaited(appPreferences.setEulaAccepted(true));
    unawaited(appPreferences.setOnboardingDone(dontShowAgain));
  }

  /// Re-opens the welcome tour from the header / action sheet.
  void _showOnboarding() {
    setState(() => _isOnboardingOpen = true);
  }

  /// Applies a theme and remembers it for the next launch.
  void _selectTheme(CompassThemeVariant variant) {
    setState(() => _themeVariant = variant);
    unawaited(appPreferences.setThemeVariant(variant.name));
  }

  /// Shows a transient message dialog above the app shell.
  ///
  /// [copyValue] adds a "Copy link" button for messages that contain a URL.
  void _showInfoDialog(String title, String message, {String? copyValue}) {
    final overlay = _overlayKey.currentState;
    if (overlay == null) return;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) {
        final theme = CompassTheme.of(context);
        var copied = false;
        return CompassDensity.forWidth(
          width: MediaQuery.sizeOf(context).width,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => entry.remove(),
                  child: Container(color: const Color(0x80000000)),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.bgPanel,
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(color: theme.border, width: 1.0),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 12.0,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(title,
                              style: CompassTypography.header(
                                  color: theme.textPrimary)),
                          const SizedBox(height: 8.0),
                          Text(message,
                              style: CompassTypography.bodyRegular(
                                  color: theme.textSecondary)),
                          const SizedBox(height: 16.0),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (copyValue != null) ...[
                                StatefulBuilder(
                                  builder: (context, setLocalState) =>
                                      CompassSecondaryButton(
                                    label: copied ? 'Copied' : 'Copy link',
                                    onTap: () {
                                      Clipboard.setData(
                                        ClipboardData(text: copyValue),
                                      );
                                      setLocalState(() => copied = true);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8.0),
                              ],
                              CompassHover(
                                onTap: () => entry.remove(),
                                semanticLabel: 'OK',
                                builder: (hovered) => Container(
                                  constraints: BoxConstraints(
                                    minHeight:
                                        CompassDensity.of(context).minTapTarget,
                                  ),
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14.0, vertical: 6.0),
                                  decoration: BoxDecoration(
                                    color: hovered
                                        ? theme.accentHover
                                        : theme.accent,
                                    borderRadius: BorderRadius.circular(6.0),
                                  ),
                                  child: Text('OK',
                                      style: CompassTypography.header(
                                          color: theme.onAccent)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    overlay.insert(entry);
  }

  /// Bug reports open the upstream GitHub issue tracker in the system browser.
  static final Uri _bugReportUri =
      Uri.parse('https://github.com/kodebineri/rusa-community/issues');

  /// Opens [_bugReportUri] in the system browser.
  ///
  /// [LaunchMode.externalApplication] is the intended mode; platforms (and
  /// older plugin builds) that only implement the default mode get a second
  /// attempt. When neither works — for example when the desktop plugin was
  /// added after the running binary was compiled — the caller shows the URL
  /// instead of failing silently.
  Future<bool> _openBugReportInBrowser() async {
    for (final mode in <LaunchMode>[
      LaunchMode.externalApplication,
      LaunchMode.platformDefault,
    ]) {
      try {
        if (await launchUrl(_bugReportUri, mode: mode)) return true;
      } catch (_) {
        // MissingPluginException on a stale build, PlatformException when no
        // browser handler exists: try the next mode.
      }
    }
    return false;
  }

  /// Report Bug entry point for both the header menu and the touch sheet.
  Future<void> _handleReportBug() async {
    final opened = await _openBugReportInBrowser();
    if (opened || !mounted) return;
    _showInfoDialog(
      'Report Bug',
      'Could not open a browser. Please open an issue at $_bugReportUri',
      copyValue: _bugReportUri.toString(),
    );
  }

  /// Selected colour theme. Defaults to Dracula (dark); changed from the
  /// header options menu or the touch action sheet.
  CompassThemeVariant _themeVariant = CompassThemeVariant.defaultVariant;
  ConnectionProfile? _connection;

  /// Non-null while the UI is backed by an actual MongoDB server (rather than
  /// the bundled sample data).
  RealMongoService? _realService;

  /// Whether the connection popup is open. Started **false**: `_loadPreferences`
  /// decides between the welcome tour and the popup, so the popup can no longer
  /// flash before the stored flags are read.
  bool _isConnectModalOpen = false;
  bool _isTerminalOpen = false;
  bool _isMobileSidebarOpen = false;

  /// True while the touch-only header overflow sheet is open.
  bool _isHeaderActionsOpen = false;
  bool _isEulaModalOpen = false;
  bool _isAboutModalOpen = false;
  bool _isPrivacyPolicyModalOpen = false;

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

  bool _isSaveViewModalOpen = false;
  List<dynamic> _saveViewPipeline = const [];
  String _saveViewPipelineJson = '[]';

  RiskyOperationDetails? _pendingTerminalOperation;
  VoidCallback? _pendingTerminalConfirm;

  String _selectedDbName = 'library';
  String _selectedCollName = 'books';
  String _activeTab =
      'documents'; // documents, aggregations, schema, indexes, ddl
  String _docViewMode = 'tree'; // tree, json, table

  /// Pipeline handed to the Aggregations tab by a view's "Copy to Aggregations"
  /// action. The aggregations view consumes it when (re)built.
  List<dynamic>? _pendingAggregationPipeline;

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
    // "Show DDL" only exists for views: fall back to Documents when the saved
    // section no longer applies (e.g. the view was replaced by a collection).
    final coll = mongoEngine.getCollection(tab.dbName, tab.collName);
    _activeTab = (tab.activeSection == 'ddl' && coll?.isView != true)
        ? 'documents'
        : tab.activeSection;
    _docViewMode = tab.docViewMode;
    _queryOptions = tab.queryOptions;
  }

  /// Opens `dbName`.`collName` in a new tab — or focuses the existing tab when
  /// that collection is already open (like a browser's "open link" behavior).
  void _openCollectionTab(String dbName, String collName) {
    final existing =
        _openTabs.indexWhere((t) => t.isSameTarget(dbName, collName));
    if (existing >= 0) {
      _activateTabIndex(existing);
      // Try to load data if it's a real service
      final service = mongoEngine;
      if (service is RealMongoService) {
        unawaited(service.loadCollectionData(dbName, collName).then((_) {
          if (mounted) setState(() {});
        }));
      }
      return;
    }
    _saveActiveTabState();
    _openTabs.add(CollectionTab(dbName: dbName, collName: collName));
    _activateTabIndex(_openTabs.length - 1);
    final service = mongoEngine;
    if (service is RealMongoService) {
      unawaited(service.loadCollectionData(dbName, collName).then((_) {
        if (mounted) setState(() {});
      }));
    }
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
      _activateTabIndex(
          index >= _openTabs.length ? _openTabs.length - 1 : index);
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
      connected = await RealMongoService.connect(profile.uri)
          .timeout(const Duration(seconds: 45));
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
        text.contains('Connection timed out') ||
        text.contains('TimeoutException')) {
      return 'Could not reach the MongoDB server. Check network, DNS (SRV), IP allowlist, and credentials.';
    }
    if (text.contains('Authentication failed') ||
        text.contains('auth') ||
        text.contains('bad auth')) {
      return 'Authentication failed. Check the username, password and auth source.';
    }
    return text
        .replaceFirst('MongoDartError: ', '')
        .replaceFirst('Exception: ', '');
  }

  void _handleSaveConnection(ConnectionProfile profile) {
    setState(() {
      // Update an existing entry in place: prefer the id (editing a saved
      // connection), otherwise match the URI so re-saving the same server
      // doesn't create a duplicate.
      final byId = _savedConnections.indexWhere((c) => c.id == profile.id);
      final byUri = _savedConnections.indexWhere((c) => c.uri == profile.uri);
      final existingIndex = byId >= 0 ? byId : byUri;
      if (existingIndex >= 0) {
        _savedConnections[existingIndex] = profile;
      } else {
        _savedConnections = [..._savedConnections, profile];
      }
    });
    // Snapshot the list: the async write must not observe a later edit/delete.
    unawaited(appPreferences.setSavedConnections(List.of(_savedConnections)));
  }

  void _handleDeleteConnection(String id) {
    setState(() {
      _savedConnections = _savedConnections.where((c) => c.id != id).toList();
    });
    unawaited(appPreferences.setSavedConnections(List.of(_savedConnections)));
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
        (_selectedDbName.isNotEmpty
            ? _selectedDbName
            : (mongoEngine.getDatabases().firstOrNull?.name ?? ''));
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
    setState(
        () {}); // re-read `activeColl.indexes` so the dropped row disappears
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
        ..['_id'] = MongoObjectId(mongoEngine.generateObjectId());
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
    mongoEngine.deleteDocument(
        _selectedDbName, _selectedCollName, _deleteDocId);
    setState(() {
      _deleteDocTarget = null;
      _deleteDocId = '';
    });
  }

  void _handleUpdateDocument(String docId, Map<String, dynamic> updatedFields) {
    if (_selectedDbName.isEmpty || _selectedCollName.isEmpty) return;
    try {
      mongoEngine.updateDocument(
          _selectedDbName, _selectedCollName, docId, updatedFields);
    } catch (_) {}
    setState(() {});
  }

  void _openImportExport(ImportExportMode mode) {
    setState(() {
      _importExportMode = mode;
      _isImportExportModalOpen = true;
    });
  }

  void _openSaveView(List<dynamic> pipeline, String pipelineJson) {
    setState(() {
      _saveViewPipeline = pipeline;
      _saveViewPipelineJson = pipelineJson;
      _isSaveViewModalOpen = true;
    });
  }

  /// Re-applies an edited DDL to the active view. Returns `null` on success or
  /// a message for the view's error banner.
  String? _handleUpdateView(
      MongoCollection activeColl, List<dynamic> pipeline) {
    if (!activeColl.isView) return 'The selected item is not a view.';
    final source = activeColl.viewOn;
    if (source == null || source.isEmpty) {
      return 'Cannot update a view without a known source collection.';
    }
    try {
      mongoEngine.updateView(
          _selectedDbName, _selectedCollName, source, pipeline);
    } catch (err) {
      return err.toString().replaceFirst('Exception: ', '');
    }
    setState(() {});
    return null;
  }

  /// Loads a view's pipeline into the Aggregations tab.
  ///
  /// The DDL describes how to build the view **from its source collection**, so
  /// the pipeline is run against the source (re-applying it to the view itself
  /// would produce nothing/garbage). The source tab is opened/loaded and its
  /// Aggregations section is shown with the view's pipeline pre-filled.
  void _copyViewToAggregations(List<dynamic> pipeline) {
    final view = mongoEngine.getCollection(_selectedDbName, _selectedCollName);
    final source = view?.viewOn;
    final targetColl =
        (source != null && source.isNotEmpty) ? source : _selectedCollName;
    setState(() {
      _pendingAggregationPipeline = List<dynamic>.from(pipeline);
      if (targetColl != _selectedCollName) {
        _openCollectionTab(_selectedDbName, targetColl);
      }
      _activeTab = 'aggregations';
    });
  }

  /// Ensures the collection the Aggregations tab will run against is mirrored.
  ///
  /// For a view the pipeline runs against the view's **source** collection, which
  /// may not have been opened yet on a live server — without this it would
  /// aggregate an empty mirror and show 0 documents.
  void _ensureAggregationTargetLoaded() {
    final service = mongoEngine;
    if (service is! RealMongoService) return;
    if (_selectedDbName.isEmpty) return;
    final coll = service.getCollection(_selectedDbName, _selectedCollName);
    if (coll == null) return;
    final target = coll.isView ? (coll.viewOn ?? coll.name) : coll.name;
    unawaited(service.loadCollectionData(_selectedDbName, target));
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

  void _requestTerminalConfirmation(
      RiskyOperationDetails operation, VoidCallback onConfirm) {
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

  /// Applies the UI side effects of a mongosh command.
  ///
  /// The command itself has already run inside [MongoshInterpreter] (the single
  /// executor); this only switches the selected database, closes tabs for
  /// dropped targets, and refreshes the tree.
  void _handleTerminalResult(MongoshResult result) {
    final effect = result.sideEffect;
    if (effect != null) {
      switch (effect.kind) {
        case MongoshSideEffectKind.switchDatabase:
          setState(() {
            _selectedDbName = effect.database;
            final db = mongoEngine.getDatabase(effect.database);
            final coll = db?.collections.keys.firstOrNull;
            if (coll != null) _openCollectionTab(effect.database, coll);
          });
          return;
        case MongoshSideEffectKind.dropDatabase:
          final droppedDb = effect.database;
          setState(() {
            _closeTabsMatching((tab) => tab.dbName == droppedDb);
            if (_openTabs.isEmpty) {
              final first = mongoEngine.getDatabases().firstOrNull;
              final firstColl = first?.collections.keys.firstOrNull;
              if (first != null && firstColl != null) {
                _openCollectionTab(first.name, firstColl);
              }
            }
          });
          return;
        case MongoshSideEffectKind.dropCollection:
          setState(() {
            _closeTabsMatching(
                (tab) => tab.isSameTarget(effect.database, effect.collection!));
          });
          return;
      }
    }
    // Reads (show dbs / show collections) and mutations (insert / update /
    // delete) both need a rebuild so the sidebar and the open tab refresh.
    setState(() {});
  }

  /// Resolved theme palette for the selected [CompassThemeVariant].
  ///
  /// NOTE: this state's own `context` sits *above* the root [CompassTheme]
  /// created in `build`, so `CompassTheme.of(context)` here would not find it
  /// and silently fall back to Dracula. Use the palette-only instance instead.
  CompassTheme get _theme => CompassTheme.palette(_themeVariant);

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
        // Touch platforms need more width before the docked desktop layout:
        // an 8-inch tablet in portrait (~800 dp) keeps the touch layout.
        final isTouchPlatform = CompassDensity.isTouchPrimaryPlatform;
        final isDesktop = constraints.maxWidth >=
            CompassDensity.desktopBreakpointFor(isTouchPlatform);
        _isTouchLayout = !isDesktop;
        _windowWidth = constraints.maxWidth;

        final service = mongoEngine;
        final dbs = service.getDatabases();
        final activeDb = service.getDatabase(_selectedDbName);
        final activeColl = activeDb?.collections[_selectedCollName];
        final docs = activeColl?.documents ?? [];
        // A live collection that is still streaming documents down.
        final isCollLoading = activeColl != null &&
            activeColl.isLoading &&
            activeColl.documents.isEmpty;
        final queryResult = service.findDocuments(
            _selectedDbName, _selectedCollName, _queryOptions);
        // When the user has not asked for a sort, order the page by `_id` so
        // the document list reads alphabetically.
        final pageDocs = _queryOptions.sort.trim().isEmpty
            ? (List<MongoDocument>.from(queryResult.documents)
              ..sort(
                  (a, b) => a.id.toLowerCase().compareTo(b.id.toLowerCase())))
            : queryResult.documents;

        final appShell = Container(
          color: _theme.bgApp,
          child: Stack(
            children: [
              // Keep the shell clear of the bottom system inset (Android
              // navigation bar / iOS home indicator). The header handles the
              // top inset itself.
              SafeArea(
                top: false,
                child: Column(
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
                      themeVariant: _themeVariant,
                      onSelectTheme: _selectTheme,
                      onToggleMobileSidebar: () {
                        setState(
                            () => _isMobileSidebarOpen = !_isMobileSidebarOpen);
                      },
                      isMobile: !isDesktop,
                      onOpenActions: () {
                        setState(() => _isHeaderActionsOpen = true);
                      },
                      onReportBug: () {
                        unawaited(_handleReportBug());
                      },
                      onShowEula: () {
                        setState(() => _isEulaModalOpen = true);
                      },
                      onShowPrivacyPolicy: () {
                        setState(() => _isPrivacyPolicyModalOpen = true);
                      },
                      onShowAbout: () {
                        setState(() => _isAboutModalOpen = true);
                      },
                      onShowWelcome: _showOnboarding,
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
                                  final collName =
                                      db?.collections.keys.firstOrNull ?? '';
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
                              onOpenCreateColl: (dbName) =>
                                  _openCreateCollection(dbName),
                              onRenameDb: _openRenameDb,
                              onRenameColl: (dbName, collName, isView) =>
                                  _openRenameColl(dbName, collName, isView),
                              onDropDb: _openDropDb,
                              onDropColl: _openDropColl,
                              onRefresh: () {
                                setState(() {});
                              },
                              onExpandDb: (dbName) {
                                final service = mongoEngine;
                                if (service is RealMongoService) {
                                  unawaited(
                                      service.loadCollectionCounts(dbName));
                                }
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
                                if (_activeTabIndex >= 0 &&
                                    _activeTab == 'documents')
                                  CompassQueryBar(
                                    options: _queryOptions,
                                    onChangeOptions: (updated) {
                                      setState(() => _queryOptions = updated);
                                    },
                                    onExecuteQuery: () {
                                      setState(() {});
                                    },
                                    onResetQuery: () {
                                      setState(() =>
                                          _queryOptions = QueryFilterOptions());
                                      // The circular-arrow button doubles as a
                                      // refresh: reload the collection from the
                                      // server (no-op for the sample engine).
                                      final service = mongoEngine;
                                      if (service is RealMongoService &&
                                          _selectedDbName.isNotEmpty &&
                                          _selectedCollName.isNotEmpty) {
                                        final coll = service.getCollection(
                                            _selectedDbName, _selectedCollName);
                                        coll?.loadError = null;
                                        unawaited(service.loadCollectionData(
                                            _selectedDbName, _selectedCollName,
                                            force: true));
                                      }
                                    },
                                    optionsExpanded: _isQueryOptionsExpanded,
                                    onToggleOptions: () {
                                      setState(() => _isQueryOptionsExpanded =
                                          !_isQueryOptionsExpanded);
                                    },
                                    onOpenOverflow: () {
                                      setState(
                                          () => _isQueryActionsOpen = true);
                                    },
                                    executionTimeMs:
                                        queryResult.executionTimeMs,
                                    totalResultsCount: queryResult.totalCount,
                                    isLoading: isCollLoading,
                                  ),

                                // Documents View Sub-Header: Pagination
                                if (_activeTabIndex >= 0 &&
                                    _activeTab == 'documents')
                                  _buildDocumentsPagination(queryResult,
                                      isLoading: isCollLoading),

                                // Active Tab Content View
                                Expanded(
                                  child: Container(
                                    color: _theme.bgApp,
                                    child: _activeTab == 'documents'
                                        ? _buildActiveTabView(
                                            activeColl, pageDocs)
                                        : SingleChildScrollView(
                                            padding: const EdgeInsets.all(16.0),
                                            child: _buildActiveTabView(
                                                activeColl, pageDocs),
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
                      activeDbName: _selectedDbName.isEmpty
                          ? (mongoEngine.getDatabases().firstOrNull?.name ?? '')
                          : _selectedDbName,
                      onCommandExecuted: _handleTerminalResult,
                      onRequestConfirmation: _requestTerminalConfirmation,
                    ),
                  ],
                ),
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
                onTestConnection: (profile) async {
                  try {
                    await RealMongoService.test(profile.uri);
                    return null;
                  } catch (err) {
                    return _formatConnectError(err);
                  }
                },
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
                collectionsCount:
                    service.getDatabase(_dropDbName)?.collections.length ?? 0,
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
              EulaModal(
                isOpen: _isEulaModalOpen,
                onClose: () => setState(() => _isEulaModalOpen = false),
              ),
              PrivacyPolicyModal(
                isOpen: _isPrivacyPolicyModalOpen,
                onClose: () =>
                    setState(() => _isPrivacyPolicyModalOpen = false),
              ),
              AboutModal(
                isOpen: _isAboutModalOpen,
                onClose: () => setState(() => _isAboutModalOpen = false),
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
                    label: _isTerminalOpen ? 'Close Shell' : 'Open Shell',
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

                  // Theme picker: one row per variant, above Report Bug.
                  for (final variant in CompassThemeVariant.values)
                    CompassActionSheetItem(
                      label:
                          '${variant.label} (${variant.isDark ? 'dark' : 'light'})',
                      svg: _themeVariant == variant
                          ? CompassSvgIcons.check
                          : (variant.isDark
                              ? CompassSvgIcons.moon
                              : CompassSvgIcons.sun),
                      color: _themeVariant == variant ? _theme.accent : null,
                      onTap: () => _selectTheme(variant),
                    ),

                  CompassActionSheetItem(
                    label: 'Report Bug',
                    svg: CompassSvgIcons.activity,
                    onTap: () {
                      setState(() => _isHeaderActionsOpen = false);
                      unawaited(_handleReportBug());
                    },
                  ),
                  CompassActionSheetItem(
                    label: 'EULA',
                    svg: CompassSvgIcons.file,
                    onTap: () {
                      setState(() => _isHeaderActionsOpen = false);
                      setState(() => _isEulaModalOpen = true);
                    },
                  ),
                  CompassActionSheetItem(
                    label: 'Privacy Policy',
                    svg: CompassSvgIcons.shieldCheck,
                    onTap: () {
                      setState(() => _isHeaderActionsOpen = false);
                      setState(() => _isPrivacyPolicyModalOpen = true);
                    },
                  ),
                  CompassActionSheetItem(
                    label: 'Show Welcome Screen',
                    svg: CompassSvgIcons.rusa,
                    onTap: () {
                      setState(() => _isHeaderActionsOpen = false);
                      _showOnboarding();
                    },
                  ),
                  CompassActionSheetItem(
                    label: 'About',
                    svg: CompassSvgIcons.key,
                    onTap: () {
                      setState(() => _isHeaderActionsOpen = false);
                      setState(() => _isAboutModalOpen = true);
                    },
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
                ],
              ),

              // First-run welcome tour / EULA gate: the last child so it paints
              // above every other overlay and blocks all interaction. It owns
              // licence acceptance (its final slide). While the stored flags
              // are still being read (`null`) a blank cover prevents a flash of
              // the app, the tour or the licence for returning users.
              if (_eulaAccepted == null)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    child: ColoredBox(color: _theme.bgApp),
                  ),
                )
              else
                OnboardingModal(
                  isOpen: _isOnboardingOpen,
                  needsEulaConsent: _eulaAccepted != true,
                  initialDontShowAgain: _onboardingDone,
                  onSelectTheme: _selectTheme,
                  onFinish: _finishOnboarding,
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
          key: _overlayKey,
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

    // Clamp the OS text scale (Android/iOS accessibility "font size"). The
    // shell is dense and pixel-precise, so honouring an unbounded scale would
    // overflow controls; 0.8–1.3 keeps accessibility useful without breaking
    // the layout. Desktop reports a 1.0 scale, so this is a no-op there.
    final unscaledContent = content;
    content = Builder(
      builder: (context) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(
              minScaleFactor: 0.8,
              maxScaleFactor: 1.3,
            ),
          ),
          child: unscaledContent,
        );
      },
    );

    // Propagate the selected theme to the whole tree so widgets can read it
    // via `CompassTheme.of(context)` instead of taking a variant parameter.
    // (See theme/compass_theme.dart.)
    content = CompassTheme(variant: _themeVariant, child: content);

    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: const Color(0x00000000),
      statusBarIconBrightness:
          _themeVariant.isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness:
          _themeVariant.isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: _theme.bgApp,
      systemNavigationBarIconBrightness:
          _themeVariant.isDark ? Brightness.light : Brightness.dark,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: content,
    );
  }

  Widget _buildCollectionHeader(
      MongoDatabase? activeDb, MongoCollection? activeColl) {
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
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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
                          style: CompassTypography.header(
                              color: _theme.textPrimary),
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Text('>',
                          style: CompassTypography.caption(
                              color: _theme.textMuted)),
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
                          style: CompassTypography.title(
                              color: _theme.textPrimary),
                        ),
                      ),
                      if (!_isTouchLayout) ...[
                        const SizedBox(width: 8.0),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6.0, vertical: 2.0),
                          decoration: BoxDecoration(
                            color: _theme.bgSubtle,
                            borderRadius: BorderRadius.circular(4.0),
                            border:
                                Border.all(color: _theme.border, width: 1.0),
                          ),
                          child: Text(
                            '${activeColl?.documents.length ?? 0} docs',
                            style: CompassTypography.caption(
                                color: _theme.textMuted),
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
                        svg: activeColl.isView
                            ? CompassSvgIcons.eye
                            : CompassSvgIcons.pencil,
                        label:
                            activeColl.isView ? 'Rename View' : 'Rename Coll',
                        iconColor: _theme.accent,
                        onTap: () => _openRenameColl(_selectedDbName,
                            _selectedCollName, activeColl.isView),
                      ),
                      _buildHeaderAction(
                        svg: CompassSvgIcons.trash,
                        label: activeColl.isView ? 'Drop View' : 'Drop Coll',
                        iconColor: _theme.textMuted,
                        onTap: () =>
                            _openDropColl(_selectedDbName, _selectedCollName),
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
                      _buildTab(
                          'documents', 'Documents', CompassSvgIcons.table),
                      _buildTab('aggregations', 'Aggregations',
                          CompassSvgIcons.layers),
                      _buildTab('schema', 'Schema', CompassSvgIcons.barChart),
                      _buildTab('indexes', 'Indexes', CompassSvgIcons.key),
                      if (activeColl?.isView == true)
                        _buildTab('ddl', 'Show DDL', CompassSvgIcons.code),
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
          border:
              Border.all(color: CompassColors.warningAmberBorder, width: 1.0),
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
              style: CompassTypography.bodyMedium(
                  color: CompassColors.warningAmber),
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
        if (tabKey == 'aggregations') _ensureAggregationTargetLoaded();
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
          border:
              isActive ? Border.all(color: _theme.border, width: 1.0) : null,
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
  Widget _buildDocumentsPagination(QueryResult result,
      {bool isLoading = false}) {
    final total = result.totalCount;
    final pageSize = _queryOptions.limit < 1 ? 1 : _queryOptions.limit;
    final skip = _queryOptions.skip < 0 ? 0 : _queryOptions.skip;
    final pageCount = result.documents.length;

    String rangeLabel;
    if (isLoading) {
      rangeLabel = 'Loading documents…';
    } else if (pageCount == 0 || total == 0) {
      rangeLabel = '0 documents';
    } else {
      final start = skip + 1;
      final end = (skip + pageSize) < total ? (skip + pageSize) : total;
      rangeLabel = '$start – $end of $total';
    }

    final canGoPrev = !isLoading && skip > 0 && total > 0;
    final canGoNext = !isLoading && (skip + pageSize) < total;

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
        Text(rangeLabel,
            style: CompassTypography.monoSmall(color: _theme.textMuted)),
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
            setState(() =>
                _queryOptions = _queryOptions.copyWith(skip: skip + pageSize));
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
          Text('No Documents Found',
              style: CompassTypography.header(color: _theme.textPrimary)),
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

  /// Loading state shown while a live server is still streaming a collection's
  /// documents into the mirror (avoids a scary "0 documents" / "empty" view).
  Widget _buildCollectionLoadingState(MongoCollection activeColl) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 64.0, horizontal: 24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CompassSpinner(
            size: 28.0,
            color: _theme.accent,
            strokeWidth: 2.4,
          ),
          const SizedBox(height: 16.0),
          Text(
            'Loading documents…',
            style: CompassTypography.header(color: _theme.textPrimary),
          ),
          const SizedBox(height: 6.0),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360.0),
            child: Text(
              'Fetching "${activeColl.name}" from the server. Large collections can take a moment.',
              textAlign: TextAlign.center,
              style: CompassTypography.bodyMedium(color: _theme.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  /// Error state shown when an on-demand load failed and nothing is loaded, so
  /// the user can retry instead of seeing a misleading "no documents".
  Widget _buildCollectionErrorState(MongoCollection activeColl) {
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
              border: Border.all(color: CompassColors.errorRed, width: 1.0),
            ),
            alignment: Alignment.center,
            child: const CompassSvg(
              svgString: CompassSvgIcons.activity,
              size: 22.0,
              color: CompassColors.errorRed,
            ),
          ),
          const SizedBox(height: 12.0),
          Text('Could not load "${activeColl.name}"',
              style: CompassTypography.header(color: _theme.textPrimary)),
          const SizedBox(height: 6.0),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420.0),
            child: Text(
              activeColl.loadError ??
                  'The server did not return the documents.',
              textAlign: TextAlign.center,
              style: CompassTypography.bodyMedium(color: _theme.textMuted),
            ),
          ),
          const SizedBox(height: 16.0),
          CompassPrimaryButton(
            label: 'Retry',
            iconSvg: CompassSvgIcons.rotateCcw,
            onTap: _retryLoadCollection,
          ),
        ],
      ),
    );
  }

  /// Reloads the active collection from the server.
  void _retryLoadCollection() {
    final service = mongoEngine;
    if (service is RealMongoService &&
        _selectedDbName.isNotEmpty &&
        _selectedCollName.isNotEmpty) {
      final coll = service.getCollection(_selectedDbName, _selectedCollName);
      if (coll != null) {
        coll.loadError = null;
      }
      unawaited(service.loadCollectionData(_selectedDbName, _selectedCollName,
          force: true));
    }
    setState(() {});
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

    // A failed load with nothing loaded: offer a retry rather than an empty
    // state that looks like "this collection has no documents".
    if (activeColl.loadError != null && activeColl.documents.isEmpty) {
      return _buildCollectionErrorState(activeColl);
    }

    // A live collection whose documents are still inbound: show progress rather
    // than the "no documents" empty state.
    if (activeColl.isLoading && activeColl.documents.isEmpty) {
      return _buildCollectionLoadingState(activeColl);
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
        // A view's pipeline describes how to build it **from its source
        // collection**, so aggregate the source and pre-fill the view's DDL.
        // That makes "Aggregations" on a view show the view's current data
        // (instead of re-applying the pipeline to the view's own output).
        final aggColl = activeColl.isView
            ? (activeColl.viewOn ?? activeColl.name)
            : activeColl.name;
        final aggInitial = activeColl.isView
            ? (_pendingAggregationPipeline ??
                (activeColl.pipeline?.isNotEmpty == true
                    ? activeColl.pipeline
                    : null))
            : _pendingAggregationPipeline;
        return AggregationsView(
          dbName: _selectedDbName,
          collName: aggColl,
          onSaveAsView: _openSaveView,
          initialPipeline: aggInitial,
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
      case 'ddl':
        if (!activeColl.isView) return const SizedBox.shrink();
        return ShowDdlView(
          dbName: _selectedDbName,
          collName: _selectedCollName,
          viewOn: activeColl.viewOn ?? '',
          pipeline: activeColl.pipeline ?? const [],
          onUpdateView: (pipeline) => _handleUpdateView(activeColl, pipeline),
          onCopyToAggregations: _copyViewToAggregations,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
