import React, { useState } from 'react';
import {
  ChevronRight,
  ChevronDown,
  Database,
  Table2,
  Plus,
  Trash2,
  Search,
  Layers,
  RefreshCw,
  X,
  Eye,
  Pencil
} from 'lucide-react';
import { MongoDatabase } from '../types/mongo';

interface SidebarProps {
  databases: MongoDatabase[];
  selectedDb: string | null;
  selectedColl: string | null;
  onSelectCollection: (dbName: string, collName: string) => void;
  onSelectDatabase: (dbName: string) => void;
  onOpenCreateDb: () => void;
  onOpenCreateColl: (dbName: string) => void;
  onRenameDb: (dbName: string) => void;
  onRenameColl: (dbName: string, collName: string, isView?: boolean) => void;
  onDropDb: (dbName: string) => void;
  onDropColl: (dbName: string, collName: string) => void;
  onRefresh: () => void;
  isMobileOpen?: boolean;
  onCloseMobile?: () => void;
}

export const Sidebar: React.FC<SidebarProps> = ({
  databases,
  selectedDb,
  selectedColl,
  onSelectCollection,
  onSelectDatabase,
  onOpenCreateDb,
  onOpenCreateColl,
  onRenameDb,
  onRenameColl,
  onDropDb,
  onDropColl,
  onRefresh,
  isMobileOpen = false,
  onCloseMobile
}) => {
  const [expandedDbs, setExpandedDbs] = useState<Record<string, boolean>>({
    sample_mflix: true,
    sample_analytics: true,
    sample_supplies: true
  });
  const [searchQuery, setSearchQuery] = useState('');

  const toggleDb = (dbName: string) => {
    setExpandedDbs(prev => ({
      ...prev,
      [dbName]: !prev[dbName]
    }));
  };

  const handleDbClick = (dbName: string) => {
    onSelectDatabase(dbName);
    if (!expandedDbs[dbName]) {
      setExpandedDbs(prev => ({ ...prev, [dbName]: true }));
    }
    if (onCloseMobile) {
      onCloseMobile();
    }
  };

  const handleCollectionClick = (dbName: string, collName: string) => {
    onSelectCollection(dbName, collName);
    if (onCloseMobile) {
      onCloseMobile();
    }
  };

  const filteredDatabases = databases.filter(db => {
    if (!searchQuery.trim()) return true;
    const q = searchQuery.toLowerCase();
    if (db.name.toLowerCase().includes(q)) return true;
    return Object.keys(db.collections).some(c => c.toLowerCase().includes(q));
  });

  return (
    <>
      {/* Mobile Backdrop */}
      {isMobileOpen && (
        <div
          className="fixed inset-0 bg-black/60 z-40 md:hidden backdrop-blur-xs animate-in fade-in duration-200"
          onClick={onCloseMobile}
          aria-hidden="true"
        />
      )}

      {/* Sidebar Panel (Off-canvas on mobile, static docked on tablet/desktop) */}
      <aside
        className={`fixed md:static inset-y-0 left-0 z-50 w-72 md:w-64 bg-compass-sidebar border-r border-compass flex flex-col h-full select-none shrink-0 overflow-hidden transition-transform duration-200 ease-in-out md:translate-x-0 shadow-xl md:shadow-none ${
          isMobileOpen ? 'translate-x-0' : '-translate-x-full'
        }`}
      >
        {/* Sidebar Header & Cluster Stats */}
        <div className="p-3 border-b border-compass">
          <div className="flex items-center justify-between mb-2">
            <div className="flex items-center gap-1.5 text-xs font-semibold text-compass-secondary">
              <Layers className="w-3.5 h-3.5 text-compass-accent" />
              <span>DATABASES</span>
            </div>
            <div className="flex items-center gap-1">
              <button
                onClick={onRefresh}
                title="Refresh Databases"
                className="p-1.5 text-compass-muted hover:text-compass-primary hover:bg-compass-subtle rounded-md transition-colors"
              >
                <RefreshCw className="w-3.5 h-3.5" />
              </button>
              <button
                onClick={() => {
                  onOpenCreateDb();
                  if (onCloseMobile) onCloseMobile();
                }}
                title="Create Database"
                className="p-1.5 text-compass-muted hover:text-compass-accent hover:bg-compass-subtle rounded-md transition-colors"
              >
                <Plus className="w-4 h-4" />
              </button>
              {/* Close Drawer Button on mobile */}
              <button
                onClick={onCloseMobile}
                className="md:hidden p-1.5 text-compass-muted hover:text-compass-primary hover:bg-compass-subtle rounded-md transition-colors ml-1"
                aria-label="Close menu"
              >
                <X className="w-4 h-4" />
              </button>
            </div>
          </div>

          {/* Search input */}
          <div className="relative">
            <Search className="w-3.5 h-3.5 absolute left-2.5 top-2.5 text-compass-muted" />
            <input
              type="text"
              placeholder="Filter databases..."
              value={searchQuery}
              onChange={e => setSearchQuery(e.target.value)}
              className="w-full bg-compass-input text-xs text-compass-primary pl-8 pr-2.5 py-1.5 rounded border border-compass focus:outline-none focus:border-emerald-500 transition-colors placeholder:text-compass-muted"
            />
          </div>
        </div>

        {/* Database Tree List */}
        <div className="flex-1 overflow-y-auto px-1.5 py-2 space-y-0.5 custom-scrollbar">
          {filteredDatabases.length === 0 ? (
            <div className="text-center py-6 px-3 text-xs text-compass-muted">
              No matching databases found
            </div>
          ) : (
            filteredDatabases.map(db => {
              const isExpanded = expandedDbs[db.name] ?? false;
              const collections = Object.values(db.collections);

              return (
                <div key={db.name} className="group/db">
                  {/* Database Row */}
                  <div
                    className={`flex items-center justify-between px-2 py-2 md:py-1.5 rounded-lg text-xs cursor-pointer transition-colors ${
                      selectedDb === db.name && !selectedColl
                        ? 'bg-compass-subtle text-compass-primary font-semibold'
                        : 'text-compass-secondary hover:bg-compass-subtle hover:text-compass-primary'
                    }`}
                    onClick={() => handleDbClick(db.name)}
                  >
                    <div className="flex items-center gap-1.5 truncate">
                      <button
                        type="button"
                        onClick={e => {
                          e.stopPropagation();
                          toggleDb(db.name);
                        }}
                        className="p-1 hover:text-compass-primary text-compass-muted"
                      >
                        {isExpanded ? (
                          <ChevronDown className="w-3.5 h-3.5" />
                        ) : (
                          <ChevronRight className="w-3.5 h-3.5" />
                        )}
                      </button>
                      <Database className="w-3.5 h-3.5 text-compass-accent shrink-0" />
                      <span className="truncate font-sans font-medium">{db.name}</span>
                    </div>

                    {/* Db Actions */}
                    <div className="flex items-center gap-0.5 opacity-80 md:opacity-0 group-hover/db:opacity-100 transition-opacity">
                      <button
                        onClick={e => {
                          e.stopPropagation();
                          onOpenCreateColl(db.name);
                          if (onCloseMobile) onCloseMobile();
                        }}
                        title={`Create Collection in ${db.name}`}
                        className="p-1 hover:text-compass-accent text-compass-muted hover:bg-compass-hover rounded"
                      >
                        <Plus className="w-3.5 h-3.5" />
                      </button>
                      <button
                        onClick={e => {
                          e.stopPropagation();
                          onRenameDb(db.name);
                        }}
                        title={`Rename Database "${db.name}"`}
                        className="p-1 hover:text-compass-accent text-compass-muted hover:bg-compass-hover rounded"
                      >
                        <Pencil className="w-3 h-3" />
                      </button>
                      <button
                        onClick={e => {
                          e.stopPropagation();
                          onDropDb(db.name);
                        }}
                        title="Drop Database"
                        className="p-1 hover:text-rose-500 text-compass-muted hover:bg-compass-hover rounded"
                      >
                        <Trash2 className="w-3.5 h-3.5" />
                      </button>
                    </div>
                  </div>

                  {/* Collections List */}
                  {isExpanded && (
                    <div className="ml-4 pl-2 border-l border-compass mt-0.5 space-y-0.5">
                      {collections.length === 0 ? (
                        <div className="py-1 px-2 text-[11px] text-compass-muted italic">
                          No collections
                        </div>
                      ) : (
                        collections.map(coll => {
                          const isSelected = selectedDb === db.name && selectedColl === coll.name;
                          const isView = Boolean(coll.isView);
                          return (
                            <div
                              key={coll.name}
                              onClick={() => handleCollectionClick(db.name, coll.name)}
                              title={isView ? `View on ${coll.viewOn || 'collection'}` : `Collection: ${coll.name}`}
                              className={`group/coll flex items-center justify-between px-2 py-1.5 rounded-md text-xs cursor-pointer transition-colors ${
                                isSelected
                                  ? 'badge-compass-accent font-semibold border'
                                  : 'text-compass-muted hover:bg-compass-subtle hover:text-compass-primary'
                              }`}
                            >
                              <div className="flex items-center gap-1.5 truncate">
                                {isView ? (
                                  <Eye className="w-3.5 h-3.5 text-amber-500 shrink-0" />
                                ) : (
                                  <Table2 className="w-3.5 h-3.5 opacity-80 shrink-0" />
                                )}
                                <span className="truncate">{coll.name}</span>
                              </div>

                              <div className="flex items-center gap-1 shrink-0">
                                <span className="text-[10px] opacity-75 font-mono tabular-nums mr-0.5">
                                  {coll.documents.length}
                                </span>
                                <button
                                  onClick={e => {
                                    e.stopPropagation();
                                    onRenameColl(db.name, coll.name, isView);
                                  }}
                                  title={isView ? `Rename View "${coll.name}"` : `Rename Collection "${coll.name}"`}
                                  className="opacity-60 md:opacity-0 group-hover/coll:opacity-100 p-1 hover:text-compass-accent text-compass-muted"
                                >
                                  <Pencil className="w-3 h-3" />
                                </button>
                                <button
                                  onClick={e => {
                                    e.stopPropagation();
                                    onDropColl(db.name, coll.name);
                                  }}
                                  title={isView ? "Drop View" : "Drop Collection"}
                                  className="opacity-60 md:opacity-0 group-hover/coll:opacity-100 p-1 hover:text-rose-500 text-compass-muted"
                                >
                                  <Trash2 className="w-3 h-3" />
                                </button>
                              </div>
                            </div>
                          );
                        })
                      )}

                      {/* Inline "+ Create Collection" link directly under the database tree */}
                      <div className="pt-1 pb-0.5">
                        <button
                          onClick={() => {
                            onOpenCreateColl(db.name);
                            if (onCloseMobile) onCloseMobile();
                          }}
                          className="w-full flex items-center gap-1.5 px-2 py-1.5 text-[11px] text-compass-muted hover:text-compass-accent hover:bg-compass-subtle rounded transition-colors group/btn"
                          title={`Create Collection in ${db.name}`}
                        >
                          <Plus className="w-3 h-3 group-hover/btn:scale-110 transition-transform" />
                          <span>Create Collection</span>
                        </button>
                      </div>
                    </div>
                  )}
                </div>
              );
            })
          )}
        </div>

        {/* Sidebar Footer button */}
        <div className="p-3 border-t border-compass bg-compass-panel">
          <button
            onClick={() => {
              onOpenCreateDb();
              if (onCloseMobile) onCloseMobile();
            }}
            className="w-full flex items-center justify-center gap-2 py-2 px-3 text-xs font-semibold text-compass-primary bg-compass-subtle hover:bg-compass-hover border border-compass rounded-lg transition-colors"
          >
            <Plus className="w-3.5 h-3.5 text-compass-accent" />
            Create Database
          </button>
        </div>
      </aside>
    </>
  );
};
