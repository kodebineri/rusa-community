import React, { useState, useEffect, useMemo } from 'react';
import {
  Database,
  Table2,
  FileCode2,
  Layers,
  BarChart2,
  Key,
  ShieldCheck,
  Activity,
  Plus,
  Download,
  Upload,
  List,
  Code2,
  Grid3X3,
  ChevronLeft,
  ChevronRight,
  Server,
  RotateCcw,
  ArrowRight,
  Trash2,
  FolderOpen,
  Eye,
  Pencil,
  ChevronDown,
  ChevronUp,
  Terminal
} from 'lucide-react';
import {
  ConnectionProfile,
  MongoDatabase,
  MongoDocument,
  QueryFilterOptions
} from './types/mongo';
import { mongoEngine } from './services/mongoEngine';
import { Header } from './components/Header';
import { Sidebar } from './components/Sidebar';
import { QueryBar } from './components/QueryBar';
import { DocumentTreeView } from './components/DocumentTreeView';
import { DocumentJsonView } from './components/DocumentJsonView';
import { DocumentTableView } from './components/DocumentTableView';
import { AggregationsView } from './components/AggregationsView';
import { SchemaView } from './components/SchemaView';
import { IndexesView } from './components/IndexesView';
import { ExplainPlanView } from './components/ExplainPlanView';
import { ValidationView } from './components/ValidationView';
import { MongoshTerminal } from './components/MongoshTerminal';
import { ConnectionModal } from './components/ConnectionModal';
import { InsertDocModal } from './components/InsertDocModal';
import { ExportLanguageModal } from './components/ExportLanguageModal';
import { CreateDbModal } from './components/CreateDbModal';
import { CreateCollectionModal } from './components/CreateCollectionModal';
import { ImportExportModal } from './components/ImportExportModal';
import { DeleteDocumentModal } from './components/DeleteDocumentModal';
import { DropCollectionModal } from './components/DropCollectionModal';
import { DropDatabaseModal } from './components/DropDatabaseModal';
import { RenameModal } from './components/RenameModal';
import { FlutterMigrationHub } from './components/FlutterMigrationHub';

type ActiveTab = 'documents' | 'aggregations' | 'schema' | 'indexes' | 'validation' | 'explain';
type DocViewMode = 'tree' | 'json' | 'table';

export default function App() {
  // Theme state with localStorage persistence
  const [isDarkMode, setIsDarkMode] = useState<boolean>(() => {
    try {
      const saved = localStorage.getItem('compass_theme');
      if (saved !== null) {
        return saved === 'dark';
      }
    } catch {
      // fallback
    }
    return true; // Default to MongoDB Compass signature dark mode
  });

  // Keep <html> element in sync with theme
  useEffect(() => {
    try {
      if (isDarkMode) {
        document.documentElement.classList.add('dark');
        localStorage.setItem('compass_theme', 'dark');
      } else {
        document.documentElement.classList.remove('dark');
        localStorage.setItem('compass_theme', 'light');
      }
    } catch {
      // fallback
    }
  }, [isDarkMode]);

  // Connection state
  const [connection, setConnection] = useState<ConnectionProfile | null>({
    id: 'default',
    name: 'Local Standalone',
    uri: 'mongodb://localhost:27017',
    lastConnected: 'Just now'
  });
  const [isConnectModalOpen, setIsConnectModalOpen] = useState(false);
  const [savedConnections, setSavedConnections] = useState<ConnectionProfile[]>([
    {
      id: '1',
      name: 'Local Standalone (27017)',
      uri: 'mongodb://localhost:27017',
      favorite: true,
      lastConnected: 'Today 10:14'
    },
    {
      id: '2',
      name: 'Atlas Production ReplicaSet',
      uri: 'mongodb+srv://admin:securePass@prod-cluster.mongodb.net/test',
      favorite: true,
      lastConnected: 'Yesterday'
    },
    {
      id: '3',
      name: 'Staging Server',
      uri: 'mongodb://staging.internal:27017',
      favorite: false,
      lastConnected: '3 days ago'
    }
  ]);

  // Selected Database & Collection
  const [selectedDbName, setSelectedDbName] = useState<string | null>('sample_mflix');
  const [selectedCollName, setSelectedCollName] = useState<string | null>('movies');
  const [activeTab, setActiveTab] = useState<ActiveTab>('documents');
  const [docViewMode, setDocViewMode] = useState<DocViewMode>('tree');

  // Query state
  const [queryOptions, setQueryOptions] = useState<QueryFilterOptions>({
    filter: '',
    project: '',
    sort: '',
    skip: 0,
    limit: 20
  });
  const [queryExecutionStats, setQueryExecutionStats] = useState<{
    timeMs: number;
    totalCount: number;
  }>({ timeMs: 0.8, totalCount: 0 });

  // Databases list from engine
  const [databases, setDatabases] = useState<MongoDatabase[]>([]);
  const [refreshTrigger, setRefreshTrigger] = useState(0);

  // Modals state
  const [isInsertModalOpen, setIsInsertModalOpen] = useState(false);
  const [editingDoc, setEditingDoc] = useState<MongoDocument | null>(null);
  const [isExportLangModalOpen, setIsExportLangModalOpen] = useState(false);
  const [isCreateDbModalOpen, setIsCreateDbModalOpen] = useState(false);
  const [isCreateCollModalOpen, setIsCreateCollModalOpen] = useState(false);
  const [createCollTargetDb, setCreateCollTargetDb] = useState<string>('');
  const [importExportModalState, setImportExportModalState] = useState<{
    isOpen: boolean;
    mode: 'export' | 'import';
  }>({ isOpen: false, mode: 'export' });

  // Confirmation dialogs state
  const [docToDelete, setDocToDelete] = useState<{ id: string; doc?: MongoDocument | null } | null>(null);
  const [collToDrop, setCollToDrop] = useState<{
    dbName: string;
    collName: string;
    docCount?: number;
    indexesCount?: number;
    isView?: boolean;
  } | null>(null);
  const [dbToDrop, setDbToDrop] = useState<{ dbName: string; collectionsCount?: number } | null>(null);
  const [renameTarget, setRenameTarget] = useState<{
    type: 'database' | 'collection';
    dbName: string;
    collName?: string;
    isView?: boolean;
  } | null>(null);

  // Terminal state
  const [isTerminalOpen, setIsTerminalOpen] = useState(false);

  // Mobile drawer state
  const [isMobileSidebarOpen, setIsMobileSidebarOpen] = useState(false);

  // Flutter Migration Hub state
  const [showFlutterMigration, setShowFlutterMigration] = useState(false);

  // Load databases on mount or trigger
  useEffect(() => {
    setDatabases(mongoEngine.getDatabases());
  }, [refreshTrigger]);

  const refreshAll = () => {
    setDatabases(mongoEngine.getDatabases());
    setRefreshTrigger(prev => prev + 1);
  };

  // Active database object
  const activeDatabase = useMemo(() => {
    if (!selectedDbName) return null;
    return mongoEngine.getDatabase(selectedDbName) || null;
  }, [selectedDbName, refreshTrigger]);

  // Active collection object
  const activeCollection = useMemo(() => {
    if (!selectedDbName || !selectedCollName) return null;
    return mongoEngine.getCollection(selectedDbName, selectedCollName) || null;
  }, [selectedDbName, selectedCollName, refreshTrigger]);

  // Query execution results
  const queryResult = useMemo(() => {
    if (!selectedDbName || !selectedCollName || !activeCollection) {
      return { documents: [], totalCount: 0, executionTimeMs: 0 };
    }
    try {
      const res = mongoEngine.findDocuments(selectedDbName, selectedCollName, queryOptions);
      setQueryExecutionStats({ timeMs: res.executionTimeMs, totalCount: res.totalCount });
      return res;
    } catch {
      return {
        documents: activeCollection.documents.slice(queryOptions.skip, queryOptions.skip + queryOptions.limit),
        totalCount: activeCollection.documents.length,
        executionTimeMs: 0.9
      };
    }
  }, [selectedDbName, selectedCollName, queryOptions, activeCollection, refreshTrigger]);

  // Handlers
  const handleSelectCollection = (dbName: string, collName: string) => {
    setSelectedDbName(dbName);
    setSelectedCollName(collName);
    setQueryOptions(prev => ({ ...prev, filter: '', skip: 0 }));
    setIsMobileSidebarOpen(false);
  };

  const handleSelectDatabase = (dbName: string) => {
    setSelectedDbName(dbName);
    setSelectedCollName(null);
    setIsMobileSidebarOpen(false);
  };

  const handleOpenCreateCollection = (targetDb?: string) => {
    const dbToUse = targetDb || selectedDbName || databases[0]?.name || '';
    setCreateCollTargetDb(dbToUse);
    setIsCreateCollModalOpen(true);
  };

  const handleExecuteQuery = () => {
    setRefreshTrigger(prev => prev + 1);
  };

  const handleResetQuery = () => {
    setQueryOptions({
      filter: '',
      project: '',
      sort: '',
      skip: 0,
      limit: 20
    });
    setRefreshTrigger(prev => prev + 1);
  };

  const handleInsertDocument = (doc: any) => {
    if (!selectedDbName || !selectedCollName) return;
    if (editingDoc) {
      mongoEngine.updateDocument(selectedDbName, selectedCollName, editingDoc._id, doc);
      setEditingDoc(null);
    } else {
      mongoEngine.insertDocument(selectedDbName, selectedCollName, doc);
    }
    refreshAll();
  };

  const handleCloneDocument = (doc: MongoDocument) => {
    if (!selectedDbName || !selectedCollName) return;
    const clone = { ...doc, _id: mongoEngine.generateObjectId() };
    mongoEngine.insertDocument(selectedDbName, selectedCollName, clone);
    refreshAll();
  };

  const handleRequestDeleteDocument = (docId: string, doc?: MongoDocument) => {
    const targetDoc = doc || activeCollection?.documents.find(d => d._id === docId) || null;
    setDocToDelete({ id: docId, doc: targetDoc });
  };

  const handleConfirmDeleteDocument = () => {
    if (!docToDelete || !selectedDbName || !selectedCollName) return;
    mongoEngine.deleteDocument(selectedDbName, selectedCollName, docToDelete.id);
    setDocToDelete(null);
    refreshAll();
  };

  const handleRequestDropCollection = (dbName: string, collName: string) => {
    const db = mongoEngine.getDatabase(dbName);
    const coll = db?.collections[collName];
    setCollToDrop({
      dbName,
      collName,
      docCount: coll?.documents.length ?? 0,
      indexesCount: coll?.indexes?.length ?? 1,
      isView: Boolean(coll?.isView)
    });
  };

  const handleConfirmDropCollection = () => {
    if (!collToDrop) return;
    mongoEngine.dropCollection(collToDrop.dbName, collToDrop.collName);
    if (selectedDbName === collToDrop.dbName && selectedCollName === collToDrop.collName) {
      setSelectedCollName(null);
    }
    setCollToDrop(null);
    refreshAll();
  };

  const handleRequestDropDatabase = (dbName: string) => {
    const db = mongoEngine.getDatabase(dbName);
    const collectionsCount = db ? Object.keys(db.collections).length : 0;
    setDbToDrop({ dbName, collectionsCount });
  };

  const handleConfirmDropDatabase = () => {
    if (!dbToDrop) return;
    mongoEngine.dropDatabase(dbToDrop.dbName);
    if (selectedDbName === dbToDrop.dbName) {
      setSelectedDbName(null);
      setSelectedCollName(null);
    }
    setDbToDrop(null);
    refreshAll();
  };

  const handleRequestRenameDatabase = (dbName: string) => {
    setRenameTarget({
      type: 'database',
      dbName
    });
  };

  const handleRequestRenameCollection = (dbName: string, collName: string, isView?: boolean) => {
    setRenameTarget({
      type: 'collection',
      dbName,
      collName,
      isView: Boolean(isView)
    });
  };

  const handleSuccessRename = (oldName: string, newName: string, type: 'database' | 'collection') => {
    refreshAll();
    if (type === 'database') {
      if (selectedDbName === oldName) {
        setSelectedDbName(newName);
      }
    } else {
      if (selectedCollName === oldName) {
        setSelectedCollName(newName);
      }
    }
  };

  const handleUpdateDocument = (docId: string, updatedFields: Record<string, any>) => {
    if (!selectedDbName || !selectedCollName) return;
    mongoEngine.updateDocument(selectedDbName, selectedCollName, docId, updatedFields);
    refreshAll();
  };

  const handleResetData = () => {
    mongoEngine.resetToDefaults();
    setSelectedDbName('sample_mflix');
    setSelectedCollName('movies');
    refreshAll();
  };

  return (
    <div className="h-screen flex flex-col overflow-hidden bg-compass-app text-compass-primary transition-colors duration-150">
      {/* Top Bar (MongoDB Compass Header) */}
      <Header
        connection={connection}
        onOpenConnectModal={() => setIsConnectModalOpen(true)}
        onDisconnect={() => setConnection(null)}
        onResetData={handleResetData}
        isTerminalOpen={isTerminalOpen}
        onToggleTerminal={() => setIsTerminalOpen(!isTerminalOpen)}
        isDarkMode={isDarkMode}
        onToggleDarkMode={() => setIsDarkMode(prev => !prev)}
        onToggleMobileSidebar={() => setIsMobileSidebarOpen(prev => !prev)}
        showFlutterMigration={showFlutterMigration}
        onToggleFlutterMigration={() => setShowFlutterMigration(prev => !prev)}
      />

      {showFlutterMigration ? (
        <FlutterMigrationHub />
      ) : (
        /* Main Workspace Canvas */
        <div className="flex-1 flex overflow-hidden relative">
        {/* Left Navigation Sidebar */}
        <Sidebar
          databases={databases}
          selectedDb={selectedDbName}
          selectedColl={selectedCollName}
          onSelectCollection={handleSelectCollection}
          onSelectDatabase={handleSelectDatabase}
          onOpenCreateDb={() => setIsCreateDbModalOpen(true)}
          onOpenCreateColl={handleOpenCreateCollection}
          onRenameDb={handleRequestRenameDatabase}
          onRenameColl={handleRequestRenameCollection}
          onDropDb={handleRequestDropDatabase}
          onDropColl={handleRequestDropCollection}
          onRefresh={refreshAll}
          isMobileOpen={isMobileSidebarOpen}
          onCloseMobile={() => setIsMobileSidebarOpen(false)}
        />

        {/* Content Viewport */}
        <main className="flex-1 flex flex-col overflow-hidden bg-compass-app transition-colors duration-150">
          {selectedDbName && selectedCollName && activeCollection ? (
            /* Collection View (Documents, Aggregations, Schema, Indexes, Validation, Explain Plan) */
            <>
              {/* Collection Context Banner & Breadcrumb */}
              <div className="bg-compass-panel px-3 sm:px-4 py-2 sm:py-2.5 border-b border-compass flex flex-col sm:flex-row sm:items-center justify-between gap-2 shrink-0 select-none shadow-xs">
                <div className="flex items-center gap-2 truncate">
                  <button
                    onClick={() => handleSelectDatabase(selectedDbName)}
                    className="text-xs font-semibold text-compass-muted hover:text-compass-accent font-mono transition-colors flex items-center gap-1.5 shrink-0"
                    title={`View ${selectedDbName} database overview`}
                  >
                    <Database className="w-3.5 h-3.5" />
                    <span>{selectedDbName}</span>
                  </button>
                  <span className="text-xs text-compass-muted shrink-0">/</span>
                  <div className="flex items-center gap-1.5 truncate">
                    {activeCollection.isView ? (
                      <Eye className="w-4 h-4 text-amber-500 shrink-0" />
                    ) : (
                      <Table2 className="w-4 h-4 text-compass-accent shrink-0" />
                    )}
                    <span className="text-sm font-bold text-compass-primary font-mono truncate">{selectedCollName}</span>
                    {activeCollection.isView && (
                      <span className="text-[10px] font-mono font-bold uppercase tracking-wider px-1.5 py-0.5 rounded bg-amber-500/15 text-amber-600 dark:text-amber-400 border border-amber-500/30 shrink-0">
                        VIEW
                      </span>
                    )}
                  </div>
                </div>

                {/* Right Header Strip: Collection Metrics & Quick Add Collection */}
                <div className="flex items-center justify-between sm:justify-end gap-2.5 sm:gap-3 flex-wrap">
                  <div className="flex items-center gap-2.5 sm:gap-3 text-xs font-mono text-compass-muted">
                    {activeCollection.isView && activeCollection.viewOn && (
                      <>
                        <div className="flex items-center gap-1 text-amber-600 dark:text-amber-400">
                          <span>View on:</span>
                          <strong className="font-mono font-bold">{activeCollection.viewOn}</strong>
                        </div>
                        <span>·</span>
                      </>
                    )}
                    <div className="flex items-center gap-1">
                      <span>Docs:</span>
                      <strong className="text-compass-primary tabular-nums font-semibold">{activeCollection.documents.length}</strong>
                    </div>
                    <span>·</span>
                    <div className="flex items-center gap-1">
                      <span>Indexes:</span>
                      <strong className="text-compass-primary tabular-nums font-semibold">
                        {activeCollection.isView ? 'Inherited' : activeCollection.indexes.length}
                      </strong>
                    </div>
                    <span>·</span>
                    <div className="flex items-center gap-1">
                      <span>Size:</span>
                      <strong className="text-compass-primary tabular-nums font-semibold">
                        {activeCollection.isView ? 'Virtual' : `${Math.max(16, activeCollection.documents.length * 2)} KB`}
                      </strong>
                    </div>
                  </div>

                  <div className="h-4 w-[1px] bg-compass hidden sm:block" />

                  {/* Create another collection in this database */}
                  <button
                    onClick={() => handleOpenCreateCollection(selectedDbName)}
                    className="flex items-center gap-1 px-2 py-1 text-xs text-compass-secondary hover:text-compass-primary hover:bg-compass-subtle rounded border border-compass transition-colors shrink-0"
                    title={`Create another collection in ${selectedDbName}`}
                  >
                    <Plus className="w-3 h-3 text-compass-accent" />
                    <span className="text-[11px] sm:text-xs">New Coll</span>
                  </button>

                  {/* Rename this collection / view */}
                  <button
                    onClick={() => handleRequestRenameCollection(selectedDbName, selectedCollName, activeCollection.isView)}
                    className="flex items-center gap-1 px-2 py-1 text-xs text-compass-secondary hover:text-compass-primary hover:bg-compass-subtle rounded border border-compass transition-colors shrink-0"
                    title={activeCollection.isView ? `Rename view "${selectedCollName}"` : `Rename collection "${selectedCollName}"`}
                  >
                    <Pencil className="w-3 h-3 text-compass-accent" />
                    <span className="text-[11px] sm:text-xs">{activeCollection.isView ? 'Rename View' : 'Rename Coll'}</span>
                  </button>

                  {/* Drop this collection / view */}
                  <button
                    onClick={() => handleRequestDropCollection(selectedDbName, selectedCollName)}
                    className="flex items-center gap-1 px-2 py-1 text-xs text-compass-muted hover:text-rose-500 hover:bg-rose-500/10 rounded border border-compass hover:border-rose-500/30 transition-colors shrink-0"
                    title={activeCollection.isView ? `Drop view "${selectedCollName}"` : `Drop collection "${selectedCollName}"`}
                  >
                    <Trash2 className="w-3 h-3" />
                    <span className="text-[11px] sm:text-xs">{activeCollection.isView ? 'Drop View' : 'Drop Coll'}</span>
                  </button>
                </div>
              </div>

              {/* The 6 Signature MongoDB Compass Tabs */}
              <div className="bg-compass-panel border-b border-compass px-2 sm:px-4 flex items-center justify-between select-none shrink-0 overflow-x-auto no-scrollbar gap-2">
                <div className="flex items-center gap-0.5 sm:gap-1 shrink-0">
                  {[
                    { id: 'documents', label: 'Documents', icon: FileCode2 },
                    { id: 'aggregations', label: 'Aggregations', icon: Layers },
                    { id: 'schema', label: 'Schema', icon: BarChart2 },
                    { id: 'indexes', label: 'Indexes', icon: Key },
                    { id: 'validation', label: 'Validation', icon: ShieldCheck },
                    { id: 'explain', label: 'Explain Plan', icon: Activity }
                  ].map(tab => {
                    const Icon = tab.icon;
                    const isActive = activeTab === tab.id;
                    return (
                      <button
                        key={tab.id}
                        onClick={() => setActiveTab(tab.id as ActiveTab)}
                        className={`flex items-center gap-1.5 px-2.5 sm:px-3 py-2 sm:py-2.5 text-xs font-medium border-b-2 transition-colors whitespace-nowrap shrink-0 ${
                          isActive
                            ? 'border-emerald-600 dark:border-[#00ED64] text-compass-accent font-semibold'
                            : 'border-transparent text-compass-muted hover:text-compass-primary'
                        }`}
                      >
                        <Icon className="w-3.5 h-3.5" />
                        <span>{tab.label}</span>
                      </button>
                    );
                  })}
                </div>

                {/* Actions on Documents Tab */}
                {activeTab === 'documents' && (
                  <div className="flex items-center gap-1.5 py-1 shrink-0">
                    {/* Add Data Action or View Read-only Indicator */}
                    {activeCollection.isView ? (
                      <div
                        title="Views are read-only and dynamically computed from aggregation pipelines."
                        className="flex items-center gap-1.5 px-2.5 py-1 text-xs font-semibold text-amber-600 dark:text-amber-400 bg-amber-500/10 border border-amber-500/30 rounded whitespace-nowrap"
                      >
                        <Eye className="w-3.5 h-3.5" />
                        <span>Read-Only View</span>
                      </div>
                    ) : (
                      <button
                        onClick={() => {
                          setEditingDoc(null);
                          setIsInsertModalOpen(true);
                        }}
                        className="flex items-center gap-1 px-2.5 py-1 text-xs font-semibold bg-compass-accent rounded transition-colors whitespace-nowrap shadow-sm"
                      >
                        <Plus className="w-3.5 h-3.5" />
                        <span className="hidden sm:inline">Insert Document</span>
                        <span className="sm:hidden">Insert</span>
                      </button>
                    )}

                    {/* Import / Export Buttons */}
                    <button
                      onClick={() => setImportExportModalState({ isOpen: true, mode: 'import' })}
                      title="Import JSON or CSV data"
                      className="p-1 sm:p-1.5 text-compass-muted hover:text-compass-primary hover:bg-compass-subtle rounded border border-compass shrink-0"
                    >
                      <Upload className="w-3.5 h-3.5" />
                    </button>

                    <button
                      onClick={() => setImportExportModalState({ isOpen: true, mode: 'export' })}
                      title="Export collection to file"
                      className="p-1 sm:p-1.5 text-compass-muted hover:text-compass-primary hover:bg-compass-subtle rounded border border-compass shrink-0"
                    >
                      <Download className="w-3.5 h-3.5" />
                    </button>
                  </div>
                )}
              </div>

              {/* Tab Contents */}
              {activeTab === 'documents' && (
                <div className="flex-1 flex flex-col overflow-hidden">
                  {/* MongoDB View Informational Banner */}
                  {activeCollection.isView && (
                    <div className="bg-amber-500/10 border-b border-amber-500/30 px-3 sm:px-4 py-2 text-xs flex flex-col sm:flex-row sm:items-center justify-between gap-2 text-amber-700 dark:text-amber-400 shrink-0">
                      <div className="flex items-center gap-2">
                        <Eye className="w-4 h-4 text-amber-500 shrink-0" />
                        <span>
                          <strong>MongoDB View:</strong> Showing dynamic output of pipeline on source collection <strong>{activeCollection.viewOn || 'source'}</strong>. Documents are read-only.
                        </span>
                      </div>
                      <button
                        onClick={() => setActiveTab('aggregations')}
                        className="text-[11px] font-semibold text-amber-600 dark:text-amber-400 hover:underline shrink-0"
                      >
                        View & Edit Pipeline →
                      </button>
                    </div>
                  )}

                  {/* Compass Query Bar */}
                  <QueryBar
                    options={queryOptions}
                    onChangeOptions={updated => setQueryOptions(prev => ({ ...prev, ...updated }))}
                    onExecuteQuery={handleExecuteQuery}
                    onResetQuery={handleResetQuery}
                    onExportToLanguage={() => setIsExportLangModalOpen(true)}
                    executionTimeMs={queryExecutionStats.timeMs}
                    totalResultsCount={queryExecutionStats.totalCount}
                  />

                  {/* Documents View Sub-Header: View Mode Switcher & Pagination */}
                  <div className="bg-compass-subtle px-3 sm:px-4 py-2 border-b border-compass flex flex-wrap sm:flex-nowrap items-center justify-between gap-2 text-xs select-none shrink-0">
                    {/* View mode toggle: List/Tree, JSON, Table */}
                    <div className="flex items-center gap-1 bg-compass-panel p-0.5 rounded border border-compass">
                      <button
                        onClick={() => setDocViewMode('tree')}
                        className={`flex items-center gap-1 px-2 sm:px-2.5 py-1 rounded text-xs transition-colors ${
                          docViewMode === 'tree'
                            ? 'badge-compass-accent font-semibold border'
                            : 'text-compass-muted hover:text-compass-primary'
                        }`}
                        title="Tree / Hierarchical View"
                      >
                        <List className="w-3.5 h-3.5" />
                        <span>Tree</span>
                      </button>

                      <button
                        onClick={() => setDocViewMode('json')}
                        className={`flex items-center gap-1 px-2 sm:px-2.5 py-1 rounded text-xs transition-colors ${
                          docViewMode === 'json'
                            ? 'badge-compass-accent font-semibold border'
                            : 'text-compass-muted hover:text-compass-primary'
                        }`}
                        title="Formatted Raw JSON View"
                      >
                        <Code2 className="w-3.5 h-3.5" />
                        <span>JSON</span>
                      </button>

                      <button
                        onClick={() => setDocViewMode('table')}
                        className={`flex items-center gap-1 px-2 sm:px-2.5 py-1 rounded text-xs transition-colors ${
                          docViewMode === 'table'
                            ? 'badge-compass-accent font-semibold border'
                            : 'text-compass-muted hover:text-compass-primary'
                        }`}
                        title="Tabular / Columnar View"
                      >
                        <Grid3X3 className="w-3.5 h-3.5" />
                        <span>Table</span>
                      </button>
                    </div>

                    {/* Pagination */}
                    <div className="flex items-center gap-2 sm:gap-3 font-mono text-[11px] text-compass-muted">
                      <span>
                        {queryResult.documents.length === 0
                          ? '0 documents'
                          : `${queryOptions.skip + 1} – ${Math.min(
                              queryOptions.skip + queryOptions.limit,
                              queryResult.totalCount
                            )} of ${queryResult.totalCount}`}
                      </span>

                      <div className="flex items-center gap-1">
                        <button
                          disabled={queryOptions.skip === 0}
                          onClick={() =>
                            setQueryOptions(prev => ({
                              ...prev,
                              skip: Math.max(0, prev.skip - prev.limit)
                            }))
                          }
                          className="p-1 hover:text-compass-primary disabled:opacity-30 disabled:hover:text-compass-muted"
                          title="Previous page"
                        >
                          <ChevronLeft className="w-4 h-4" />
                        </button>
                        <button
                          disabled={queryOptions.skip + queryOptions.limit >= queryResult.totalCount}
                          onClick={() =>
                            setQueryOptions(prev => ({
                              ...prev,
                              skip: prev.skip + prev.limit
                            }))
                          }
                          className="p-1 hover:text-compass-primary disabled:opacity-30 disabled:hover:text-compass-muted"
                          title="Next page"
                        >
                          <ChevronRight className="w-4 h-4" />
                        </button>
                      </div>
                    </div>
                  </div>

                  {/* Document Records Viewport */}
                  <div className="flex-1 overflow-y-auto p-4 custom-scrollbar">
                    {queryResult.documents.length === 0 ? (
                      <div className="text-center py-16 space-y-3">
                        <div className="w-12 h-12 rounded-full bg-compass-panel border border-compass flex items-center justify-center mx-auto text-compass-muted shadow-sm">
                          <FileCode2 className="w-6 h-6" />
                        </div>
                        <h3 className="text-sm font-semibold text-compass-primary">No Documents Found</h3>
                        <p className="text-xs text-compass-muted max-w-sm mx-auto">
                          {queryOptions.filter
                            ? 'No documents in this collection matched your filter expression.'
                            : 'This collection is empty. You can add documents or import datasets.'}
                        </p>
                        <button
                          onClick={() => {
                            setEditingDoc(null);
                            setIsInsertModalOpen(true);
                          }}
                          className="px-3.5 py-1.5 bg-compass-accent font-semibold rounded text-xs transition-colors shadow-sm"
                        >
                          Insert First Document
                        </button>
                      </div>
                    ) : docViewMode === 'tree' ? (
                      <DocumentTreeView
                        documents={queryResult.documents}
                        onEditDocument={doc => {
                          setEditingDoc(doc);
                          setIsInsertModalOpen(true);
                        }}
                        onCloneDocument={handleCloneDocument}
                        onDeleteDocument={handleRequestDeleteDocument}
                      />
                    ) : docViewMode === 'json' ? (
                      <DocumentJsonView
                        documents={queryResult.documents}
                        onUpdateDocument={handleUpdateDocument}
                        onCloneDocument={handleCloneDocument}
                        onDeleteDocument={handleRequestDeleteDocument}
                      />
                    ) : (
                      <DocumentTableView
                        documents={queryResult.documents}
                        onEditDocument={doc => {
                          setEditingDoc(doc);
                          setIsInsertModalOpen(true);
                        }}
                        onDeleteDocument={handleRequestDeleteDocument}
                      />
                    )}
                  </div>
                </div>
              )}

              {activeTab === 'aggregations' && (
                <div className="flex-1 overflow-y-auto p-4 custom-scrollbar">
                  <AggregationsView
                    dbName={selectedDbName}
                    collName={selectedCollName}
                    onExportPipeline={() => setIsExportLangModalOpen(true)}
                    onViewCreated={newViewName => {
                      refreshAll();
                      setSelectedCollName(newViewName);
                    }}
                  />
                </div>
              )}

              {activeTab === 'schema' && (
                <div className="flex-1 overflow-y-auto p-4 custom-scrollbar">
                  <SchemaView dbName={selectedDbName} collName={selectedCollName} />
                </div>
              )}

              {activeTab === 'indexes' && (
                <div className="flex-1 overflow-y-auto p-4 custom-scrollbar">
                  <IndexesView
                    dbName={selectedDbName}
                    collName={selectedCollName}
                    indexes={activeCollection.indexes}
                    onRefresh={refreshAll}
                  />
                </div>
              )}

              {activeTab === 'validation' && (
                <div className="flex-1 overflow-y-auto p-4 custom-scrollbar">
                  <ValidationView
                    collection={activeCollection}
                    onSaveValidator={(validator, level, action) => {
                      activeCollection.validator = validator;
                      activeCollection.validationLevel = level as any;
                      activeCollection.validationAction = action as any;
                      mongoEngine.saveToStorage();
                      refreshAll();
                    }}
                  />
                </div>
              )}

              {activeTab === 'explain' && (
                <div className="flex-1 overflow-y-auto p-4 custom-scrollbar">
                  <ExplainPlanView
                    dbName={selectedDbName}
                    collName={selectedCollName}
                    filterStr={queryOptions.filter}
                    sortStr={queryOptions.sort}
                  />
                </div>
              )}
            </>
          ) : selectedDbName && activeDatabase ? (
            /* Database Overview Page (When a Database is clicked, showing all its collections + Create Collection) */
            <div className="flex-1 overflow-y-auto p-3 sm:p-6 custom-scrollbar space-y-4 sm:space-y-6">
              {/* Database Overview Banner */}
              <div className="bg-compass-panel border border-compass rounded-xl p-4 sm:p-6 flex flex-col md:flex-row items-start md:items-center justify-between gap-4 shadow-sm">
                <div>
                  <div className="flex items-center gap-2 mb-1">
                    <Database className="w-5 h-5 text-compass-accent shrink-0" />
                    <h2 className="text-base sm:text-lg font-bold text-compass-primary font-mono truncate">
                      {selectedDbName}
                    </h2>
                  </div>
                  <p className="text-xs text-compass-muted">
                    Database containing {Object.keys(activeDatabase.collections).length} collections
                  </p>
                </div>

                <div className="flex flex-wrap items-center gap-2 w-full md:w-auto">
                  <button
                    onClick={() => handleOpenCreateCollection(selectedDbName)}
                    className="flex items-center gap-1.5 px-3 sm:px-3.5 py-2 text-xs font-semibold bg-compass-accent rounded-lg transition-colors shadow-sm"
                  >
                    <Plus className="w-4 h-4" />
                    <span>Create Collection</span>
                  </button>

                  <button
                    onClick={() => handleRequestRenameDatabase(selectedDbName)}
                    className="flex items-center gap-1.5 px-3 sm:px-3.5 py-2 text-xs font-medium text-compass-primary bg-compass-subtle hover:bg-compass-hover border border-compass rounded-lg transition-colors"
                    title={`Rename database "${selectedDbName}"`}
                  >
                    <Pencil className="w-3.5 h-3.5 text-compass-accent" />
                    <span>Rename Database</span>
                  </button>

                  <button
                    onClick={() => handleRequestDropDatabase(selectedDbName)}
                    className="flex items-center gap-1.5 px-3 sm:px-3.5 py-2 text-xs font-medium text-rose-500 hover:text-rose-600 bg-rose-500/10 hover:bg-rose-500/20 border border-rose-500/30 rounded-lg transition-colors"
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                    <span>Drop Database</span>
                  </button>
                </div>
              </div>

              {/* Collections in this Database */}
              <div>
                <div className="flex items-center justify-between mb-3">
                  <h3 className="text-xs font-semibold text-compass-muted uppercase tracking-wider">
                    Collections in "{selectedDbName}" ({Object.keys(activeDatabase.collections).length})
                  </h3>
                  <button
                    onClick={() => handleOpenCreateCollection(selectedDbName)}
                    className="text-xs text-compass-accent hover:underline flex items-center gap-1 font-semibold"
                  >
                    <Plus className="w-3.5 h-3.5" />
                    <span>Add Collection</span>
                  </button>
                </div>

                {Object.keys(activeDatabase.collections).length === 0 ? (
                  <div className="bg-compass-panel border border-compass rounded-xl p-8 sm:p-12 text-center space-y-3 shadow-sm">
                    <div className="w-12 h-12 rounded-full bg-compass-subtle border border-compass flex items-center justify-center mx-auto text-compass-muted">
                      <Table2 className="w-6 h-6" />
                    </div>
                    <h4 className="text-sm font-semibold text-compass-primary">No Collections in this Database</h4>
                    <p className="text-xs text-compass-muted max-w-sm mx-auto">
                      Create your first collection to start storing JSON documents in database "{selectedDbName}".
                    </p>
                    <button
                      onClick={() => handleOpenCreateCollection(selectedDbName)}
                      className="px-4 py-2 bg-compass-accent font-semibold rounded-lg text-xs transition-colors shadow-sm inline-flex items-center gap-1.5"
                    >
                      <Plus className="w-3.5 h-3.5" />
                      <span>Create Collection</span>
                    </button>
                  </div>
                ) : (
                  <div className="bg-compass-panel border border-compass rounded-xl overflow-x-auto custom-scrollbar shadow-sm">
                    <table className="w-full min-w-[560px] text-left text-xs border-collapse">
                      <thead>
                        <tr className="bg-compass-subtle border-b border-compass text-[11px] font-mono text-compass-muted uppercase">
                          <th className="py-3 px-4 font-semibold">Collection Name</th>
                          <th className="py-3 px-4 font-semibold">Documents</th>
                          <th className="py-3 px-4 font-semibold">Avg Doc Size</th>
                          <th className="py-3 px-4 font-semibold">Total Size</th>
                          <th className="py-3 px-4 font-semibold">Indexes</th>
                          <th className="py-3 px-4 text-right">Actions</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-compass font-sans">
                        {Object.values(activeDatabase.collections).map(coll => {
                          const isView = Boolean(coll.isView);
                          return (
                            <tr
                              key={coll.name}
                              onClick={() => handleSelectCollection(selectedDbName, coll.name)}
                              className="hover:bg-compass-subtle transition-colors cursor-pointer group/row"
                            >
                              <td className="py-3 px-4 font-mono font-medium text-compass-primary">
                                <div className="flex items-center gap-2 flex-wrap">
                                  {isView ? (
                                    <Eye className="w-4 h-4 text-amber-500 shrink-0" />
                                  ) : (
                                    <Table2 className="w-4 h-4 text-compass-accent shrink-0" />
                                  )}
                                  <span className="group-hover/row:text-compass-accent transition-colors">{coll.name}</span>
                                  {isView && (
                                    <span className="text-[9px] font-mono font-bold uppercase tracking-wider px-1.5 py-0.5 rounded bg-amber-500/15 text-amber-600 dark:text-amber-400 border border-amber-500/30">
                                      VIEW {coll.viewOn ? `· on ${coll.viewOn}` : ''}
                                    </span>
                                  )}
                                </div>
                              </td>
                              <td className="py-3 px-4 font-mono tabular-nums text-compass-secondary">
                                {coll.documents.length.toLocaleString()}
                              </td>
                              <td className="py-3 px-4 font-mono tabular-nums text-compass-muted">
                                {coll.documents.length ? '1.8 KB' : '0 B'}
                              </td>
                              <td className="py-3 px-4 font-mono tabular-nums text-compass-muted">
                                {isView ? 'Virtual' : `${Math.max(16, coll.documents.length * 2)} KB`}
                              </td>
                              <td className="py-3 px-4 font-mono tabular-nums text-compass-muted">
                                {isView ? 'Inherited' : coll.indexes.length}
                              </td>
                              <td className="py-3 px-4 text-right">
                                <div className="flex items-center justify-end gap-1.5" onClick={e => e.stopPropagation()}>
                                  <button
                                    onClick={() => handleSelectCollection(selectedDbName, coll.name)}
                                    className="px-2.5 py-1 bg-compass-subtle hover:bg-compass-hover text-compass-primary rounded text-xs border border-compass transition-colors"
                                  >
                                    Open
                                  </button>
                                  <button
                                    onClick={() => handleRequestRenameCollection(selectedDbName, coll.name, isView)}
                                    title={isView ? "Rename View" : "Rename Collection"}
                                    className="p-1 hover:text-compass-accent text-compass-muted hover:bg-compass-hover rounded"
                                  >
                                    <Pencil className="w-3.5 h-3.5" />
                                  </button>
                                  <button
                                    onClick={() => handleRequestDropCollection(selectedDbName, coll.name)}
                                    title={isView ? "Drop View" : "Drop Collection"}
                                    className="p-1 hover:text-rose-500 text-compass-muted hover:bg-compass-hover rounded"
                                  >
                                    <Trash2 className="w-3.5 h-3.5" />
                                  </button>
                                </div>
                              </td>
                            </tr>
                          );
                        })}
                      </tbody>
                    </table>
                  </div>
                )}
              </div>
            </div>
          ) : (
            /* Cluster Dashboard / Empty State */
            <div className="flex-1 overflow-y-auto p-3 sm:p-6 custom-scrollbar space-y-4 sm:space-y-6">
              {/* Cluster Overview Hero */}
              <div className="bg-compass-panel border border-compass rounded-xl p-4 sm:p-6 flex flex-col md:flex-row items-start md:items-center justify-between gap-4 shadow-sm">
                <div>
                  <div className="flex items-center gap-2 mb-1">
                    <Server className="w-5 h-5 text-compass-accent shrink-0" />
                    <h2 className="text-base sm:text-lg font-bold text-compass-primary font-sans">
                      Cluster Overview · MongoDB Standalone
                    </h2>
                  </div>
                  <p className="text-xs text-compass-muted">
                    MongoDB v7.0.8 Community Edition · In-memory engine active · URI: <span className="font-mono text-compass-primary font-medium break-all">mongodb://localhost:27017</span>
                  </p>
                </div>

                <div className="flex flex-wrap items-center gap-2 w-full md:w-auto">
                  <button
                    onClick={() => setIsCreateDbModalOpen(true)}
                    className="flex items-center gap-1.5 px-3.5 py-2 text-xs font-semibold bg-compass-accent rounded-lg transition-colors shadow-sm"
                  >
                    <Plus className="w-4 h-4" />
                    <span>Create Database</span>
                  </button>
                  <button
                    onClick={() => handleOpenCreateCollection()}
                    className="flex items-center gap-1.5 px-3 sm:px-3.5 py-2 text-xs font-medium text-compass-primary bg-compass-subtle hover:bg-compass-hover border border-compass rounded-lg transition-colors"
                  >
                    <Table2 className="w-3.5 h-3.5 text-compass-accent" />
                    <span>Create Collection</span>
                  </button>
                  <button
                    onClick={handleResetData}
                    className="flex items-center gap-1.5 px-3 sm:px-3.5 py-2 text-xs font-medium text-compass-primary bg-compass-subtle hover:bg-compass-hover border border-compass rounded-lg transition-colors"
                  >
                    <RotateCcw className="w-3.5 h-3.5" />
                    <span>Reload Samples</span>
                  </button>
                </div>
              </div>

              {/* Sample Database Cards */}
              <div>
                <h3 className="text-xs font-semibold text-compass-muted uppercase tracking-wider mb-3">
                  Available Databases ({databases.length})
                </h3>

                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3 sm:gap-4">
                  {databases.map(db => {
                    const colls = Object.values(db.collections);

                    return (
                      <div
                        key={db.name}
                        className="bg-compass-panel border border-compass hover:border-compass-hover rounded-xl p-4 transition-colors group flex flex-col justify-between shadow-sm"
                      >
                        <div>
                          <div className="flex items-center justify-between mb-2">
                            <div
                              className="flex items-center gap-2 cursor-pointer"
                              onClick={() => handleSelectDatabase(db.name)}
                            >
                              <Database className="w-4 h-4 text-compass-accent" />
                              <span className="font-bold text-compass-primary text-sm font-mono group-hover:text-compass-accent transition-colors">
                                {db.name}
                              </span>
                            </div>
                            <div className="flex items-center gap-1">
                              <button
                                onClick={e => {
                                  e.stopPropagation();
                                  handleRequestRenameDatabase(db.name);
                                }}
                                className="text-[11px] font-mono text-compass-muted hover:text-compass-accent flex items-center p-1 rounded hover:bg-compass-subtle"
                                title={`Rename database "${db.name}"`}
                              >
                                <Pencil className="w-3 h-3" />
                              </button>
                              <button
                                onClick={() => handleOpenCreateCollection(db.name)}
                                className="text-[11px] font-mono text-compass-muted hover:text-compass-accent flex items-center gap-1 px-1.5 py-0.5 rounded hover:bg-compass-subtle"
                                title={`Create Collection in ${db.name}`}
                              >
                                <Plus className="w-3 h-3" />
                                <span>{colls.length} colls</span>
                              </button>
                            </div>
                          </div>

                          <div className="space-y-1 my-3">
                            {colls.map(c => (
                              <div
                                key={c.name}
                                onClick={() => handleSelectCollection(db.name, c.name)}
                                className="flex items-center justify-between px-2.5 py-1.5 rounded bg-compass-subtle hover:bg-compass-hover text-xs cursor-pointer border border-compass/60 transition-colors"
                              >
                                <span className="font-mono text-compass-primary">{c.name}</span>
                                <span className="text-[10px] text-compass-muted font-mono tabular-nums">
                                  {c.documents.length} docs
                                </span>
                              </div>
                            ))}

                            {/* Add collection button inside card */}
                            <button
                              onClick={() => handleOpenCreateCollection(db.name)}
                              className="w-full flex items-center justify-center gap-1 py-1 text-[11px] text-compass-muted hover:text-compass-accent hover:bg-compass-subtle rounded border border-dashed border-compass transition-colors"
                            >
                              <Plus className="w-3 h-3" />
                              <span>Create Collection</span>
                            </button>
                          </div>
                        </div>

                        <button
                          onClick={() => handleSelectDatabase(db.name)}
                          className="mt-2 w-full flex items-center justify-center gap-1.5 py-1.5 text-xs font-semibold text-compass-accent hover:text-white hover:bg-emerald-700 rounded transition-colors border border-emerald-500/30"
                        >
                          <span>Explore Database</span>
                          <ArrowRight className="w-3.5 h-3.5" />
                        </button>
                      </div>
                    );
                  })}
                </div>
              </div>
            </div>
          )}
        </main>
      </div>
      )}

      {/* Embedded mongosh Terminal (Bottom Docked Drawer) */}
      <MongoshTerminal
        isOpen={isTerminalOpen}
        onClose={() => setIsTerminalOpen(false)}
        activeDbName={selectedDbName || 'test'}
        onDbSwitched={db => setSelectedDbName(db)}
        onDataChanged={refreshAll}
      />

      {/* Compass Bottom Status Bar (Signature MongoDB Compass Docked Footer) */}
      <div className="h-7 bg-compass-panel border-t border-compass px-3 flex items-center justify-between text-xs font-mono select-none shrink-0 z-20">
        <button
          onClick={() => setIsTerminalOpen(!isTerminalOpen)}
          className={`flex items-center gap-1.5 px-2 py-0.5 rounded text-[11px] font-medium transition-colors hover:bg-compass-subtle ${
            isTerminalOpen
              ? 'text-compass-accent font-bold bg-emerald-500/10'
              : 'text-compass-muted hover:text-compass-primary'
          }`}
          title="Toggle mongosh Interactive Shell"
        >
          <Terminal className="w-3.5 h-3.5 text-compass-accent" />
          <span>_mongosh</span>
          {isTerminalOpen ? (
            <ChevronDown className="w-3 h-3 opacity-60" />
          ) : (
            <ChevronUp className="w-3 h-3 opacity-60" />
          )}
        </button>

        <div className="flex items-center gap-3 text-[11px] text-compass-muted">
          <span className="hidden sm:inline">mongodb://localhost:27017</span>
          <span className="text-compass-primary font-semibold">{selectedDbName || 'test'}</span>
        </div>
      </div>

      {/* Modals */}
      <ConnectionModal
        isOpen={isConnectModalOpen}
        onClose={() => setIsConnectModalOpen(false)}
        onConnect={prof => {
          setConnection(prof);
          refreshAll();
        }}
        savedConnections={savedConnections}
        onSaveConnection={prof => setSavedConnections(prev => [...prev, prof])}
        onDeleteConnection={id => setSavedConnections(prev => prev.filter(c => c.id !== id))}
        onToggleFavorite={id =>
          setSavedConnections(prev =>
            prev.map(c => (c.id === id ? { ...c, favorite: !c.favorite } : c))
          )
        }
        onLoadSamples={handleResetData}
      />

      <InsertDocModal
        isOpen={isInsertModalOpen}
        onClose={() => {
          setIsInsertModalOpen(false);
          setEditingDoc(null);
        }}
        onInsert={handleInsertDocument}
        initialDoc={editingDoc}
      />

      <ExportLanguageModal
        isOpen={isExportLangModalOpen}
        onClose={() => setIsExportLangModalOpen(false)}
        dbName={selectedDbName || 'test'}
        collName={selectedCollName || 'items'}
        filterStr={queryOptions.filter}
        projectStr={queryOptions.project}
        sortStr={queryOptions.sort}
      />

      <CreateDbModal
        isOpen={isCreateDbModalOpen}
        onClose={() => setIsCreateDbModalOpen(false)}
        onSubmit={(dbName, collName) => {
          mongoEngine.createDatabase(dbName, collName);
          setSelectedDbName(dbName);
          setSelectedCollName(collName);
          refreshAll();
        }}
      />

      <CreateCollectionModal
        isOpen={isCreateCollModalOpen}
        onClose={() => setIsCreateCollModalOpen(false)}
        databases={databases}
        targetDbName={createCollTargetDb || selectedDbName || databases[0]?.name || ''}
        onCreated={(dbName, collName) => {
          setSelectedDbName(dbName);
          setSelectedCollName(collName);
          refreshAll();
        }}
      />

      {selectedDbName && selectedCollName && (
        <ImportExportModal
          isOpen={importExportModalState.isOpen}
          onClose={() => setImportExportModalState(prev => ({ ...prev, isOpen: false }))}
          mode={importExportModalState.mode}
          dbName={selectedDbName}
          collName={selectedCollName}
          documents={activeCollection?.documents || []}
          onImportComplete={refreshAll}
        />
      )}

      {/* Confirmation Dialog: Delete Document */}
      <DeleteDocumentModal
        isOpen={!!docToDelete}
        onClose={() => setDocToDelete(null)}
        onConfirm={handleConfirmDeleteDocument}
        dbName={selectedDbName || ''}
        collName={selectedCollName || ''}
        documentId={docToDelete?.id || ''}
        document={docToDelete?.doc}
      />

      {/* Confirmation Dialog: Drop Collection or View */}
      <DropCollectionModal
        isOpen={!!collToDrop}
        onClose={() => setCollToDrop(null)}
        onConfirm={handleConfirmDropCollection}
        dbName={collToDrop?.dbName || ''}
        collName={collToDrop?.collName || ''}
        documentCount={collToDrop?.docCount}
        indexesCount={collToDrop?.indexesCount}
        isView={collToDrop?.isView}
      />

      {/* Confirmation Dialog: Drop Database */}
      <DropDatabaseModal
        isOpen={!!dbToDrop}
        onClose={() => setDbToDrop(null)}
        onConfirm={handleConfirmDropDatabase}
        dbName={dbToDrop?.dbName || ''}
        collectionsCount={dbToDrop?.collectionsCount}
      />

      {/* Rename Dialog: Database or Collection */}
      {renameTarget && (
        <RenameModal
          isOpen={!!renameTarget}
          onClose={() => setRenameTarget(null)}
          type={renameTarget.type}
          dbName={renameTarget.dbName}
          collName={renameTarget.collName}
          isView={renameTarget.isView}
          onSuccess={handleSuccessRename}
        />
      )}
    </div>
  );
}
