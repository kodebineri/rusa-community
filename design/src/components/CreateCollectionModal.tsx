import React, { useState, useEffect } from 'react';
import { Table2, Database, AlertCircle, ChevronDown, ChevronUp, Sliders } from 'lucide-react';
import { MongoDatabase } from '../types/mongo';
import { mongoEngine } from '../services/mongoEngine';

interface CreateCollectionModalProps {
  isOpen: boolean;
  onClose: () => void;
  databases: MongoDatabase[];
  targetDbName: string;
  onCreated: (dbName: string, collName: string) => void;
}

export const CreateCollectionModal: React.FC<CreateCollectionModalProps> = ({
  isOpen,
  onClose,
  databases,
  targetDbName,
  onCreated
}) => {
  const [selectedDb, setSelectedDb] = useState(targetDbName || databases[0]?.name || '');
  const [collName, setCollName] = useState('');
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  // Advanced Compass Collection Options
  const [showAdvanced, setShowAdvanced] = useState(false);
  const [isCapped, setIsCapped] = useState(false);
  const [maxSizeBytes, setMaxSizeBytes] = useState<number>(1048576); // 1MB default
  const [maxDocs, setMaxDocs] = useState<number>(1000);
  const [useCustomCollation, setUseCustomCollation] = useState(false);
  const [collationLocale, setCollationLocale] = useState('en');

  useEffect(() => {
    if (isOpen) {
      setSelectedDb(targetDbName || databases[0]?.name || '');
      setCollName('');
      setErrorMsg(null);
      setIsCapped(false);
      setShowAdvanced(false);
      setUseCustomCollation(false);
    }
  }, [isOpen, targetDbName, databases]);

  if (!isOpen) return null;

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const trimmed = collName.trim();
    if (!trimmed) {
      setErrorMsg('Collection name is required');
      return;
    }

    if (!selectedDb) {
      setErrorMsg('Please select a target database');
      return;
    }

    // Name validation
    if (trimmed.includes('$')) {
      setErrorMsg('Collection names cannot contain the "$" character');
      return;
    }
    if (trimmed.startsWith('system.')) {
      setErrorMsg('Collection names cannot start with the "system." prefix');
      return;
    }

    const db = mongoEngine.getDatabase(selectedDb);
    if (db && db.collections[trimmed]) {
      setErrorMsg(`A collection named "${trimmed}" already exists in database "${selectedDb}"`);
      return;
    }

    const success = mongoEngine.createCollection(selectedDb, trimmed);
    if (!success) {
      setErrorMsg(`Failed to create collection "${trimmed}" in "${selectedDb}"`);
      return;
    }

    onCreated(selectedDb, trimmed);
    onClose();
  };

  return (
    <div className="fixed inset-0 bg-black/60 flex items-center justify-center p-3 sm:p-4 z-50 animate-in fade-in select-none">
      <div className="bg-compass-panel border border-compass rounded-xl max-w-md w-full p-4 sm:p-5 space-y-4 shadow-2xl max-h-[92vh] overflow-y-auto custom-scrollbar">
        {/* Header */}
        <div className="flex items-center justify-between pb-3 border-b border-compass">
          <div className="flex items-center gap-2">
            <div className="p-1 rounded bg-emerald-500/10 text-compass-accent">
              <Table2 className="w-4 h-4" />
            </div>
            <div>
              <h3 className="text-sm font-semibold text-compass-primary">
                Create Collection
              </h3>
              <p className="text-[11px] text-compass-muted">
                Add a new collection to your database
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="text-compass-muted hover:text-compass-primary text-xs p-1 rounded hover:bg-compass-hover"
          >
            ✕
          </button>
        </div>

        {/* Form */}
        <form onSubmit={handleSubmit} className="space-y-4 text-xs">
          {/* Database Selector */}
          <div>
            <label className="block text-compass-secondary font-medium mb-1.5 flex items-center justify-between">
              <span>Target Database</span>
              <span className="text-[10px] text-compass-muted font-normal">Database where collection will be created</span>
            </label>
            <div className="relative">
              <select
                value={selectedDb}
                onChange={e => {
                  setSelectedDb(e.target.value);
                  setErrorMsg(null);
                }}
                className="w-full bg-compass-input text-compass-primary px-3 py-2 rounded-lg border border-compass font-mono focus:outline-none focus:border-emerald-500 appearance-none cursor-pointer"
              >
                {databases.map(db => (
                  <option key={db.name} value={db.name}>
                    {db.name} ({Object.keys(db.collections).length} collections)
                  </option>
                ))}
              </select>
              <div className="absolute right-3 top-3 pointer-events-none text-compass-muted">
                <ChevronDown className="w-3.5 h-3.5" />
              </div>
            </div>
          </div>

          {/* Collection Name */}
          <div>
            <label className="block text-compass-secondary font-medium mb-1.5 flex items-center justify-between">
              <span>Collection Name</span>
              <span className="text-[10px] text-compass-muted font-mono font-normal">e.g. orders, logs, analytics</span>
            </label>
            <input
              type="text"
              placeholder="Enter collection name"
              value={collName}
              autoFocus
              onChange={e => {
                setCollName(e.target.value);
                setErrorMsg(null);
              }}
              className="w-full bg-compass-input text-compass-primary px-3 py-2 rounded-lg border border-compass font-mono focus:outline-none focus:border-emerald-500 placeholder:text-compass-muted"
            />
          </div>

          {/* Advanced Compass Options */}
          <div className="pt-1">
            <button
              type="button"
              onClick={() => setShowAdvanced(!showAdvanced)}
              className="text-compass-accent hover:underline flex items-center gap-1.5 font-medium text-xs"
            >
              <Sliders className="w-3.5 h-3.5" />
              <span>Advanced Options (Capped, Collation)</span>
              {showAdvanced ? <ChevronUp className="w-3 h-3" /> : <ChevronDown className="w-3 h-3" />}
            </button>

            {showAdvanced && (
              <div className="mt-3 p-3 bg-compass-subtle rounded-lg border border-compass space-y-3 animate-in fade-in">
                {/* Capped Collection */}
                <div>
                  <label className="flex items-center gap-2 text-compass-primary cursor-pointer">
                    <input
                      type="checkbox"
                      checked={isCapped}
                      onChange={e => setIsCapped(e.target.checked)}
                      className="accent-emerald-600 dark:accent-[#00ED64]"
                    />
                    <span className="font-semibold">Capped Collection</span>
                  </label>
                  <p className="text-[10px] text-compass-muted ml-5 mt-0.5">
                    Fixed-size collection that automatically overwrites oldest entries when full
                  </p>

                  {isCapped && (
                    <div className="mt-2.5 ml-5 grid grid-cols-2 gap-2">
                      <div>
                        <label className="block text-[10px] text-compass-muted mb-1 font-mono">Max Size (bytes)</label>
                        <input
                          type="number"
                          value={maxSizeBytes}
                          onChange={e => setMaxSizeBytes(parseInt(e.target.value) || 0)}
                          className="w-full bg-compass-input text-compass-primary p-1.5 rounded border border-compass font-mono text-xs"
                        />
                      </div>
                      <div>
                        <label className="block text-[10px] text-compass-muted mb-1 font-mono">Max Documents</label>
                        <input
                          type="number"
                          value={maxDocs}
                          onChange={e => setMaxDocs(parseInt(e.target.value) || 0)}
                          className="w-full bg-compass-input text-compass-primary p-1.5 rounded border border-compass font-mono text-xs"
                        />
                      </div>
                    </div>
                  )}
                </div>

                {/* Collation */}
                <div className="pt-1 border-t border-compass/60">
                  <label className="flex items-center gap-2 text-compass-primary cursor-pointer">
                    <input
                      type="checkbox"
                      checked={useCustomCollation}
                      onChange={e => setUseCustomCollation(e.target.checked)}
                      className="accent-emerald-600 dark:accent-[#00ED64]"
                    />
                    <span className="font-semibold">Custom Collation</span>
                  </label>

                  {useCustomCollation && (
                    <div className="mt-2 ml-5">
                      <label className="block text-[10px] text-compass-muted mb-1">Locale</label>
                      <select
                        value={collationLocale}
                        onChange={e => setCollationLocale(e.target.value)}
                        className="w-full bg-compass-input text-compass-primary p-1.5 rounded border border-compass text-xs"
                      >
                        <option value="en">English (en)</option>
                        <option value="es">Spanish (es)</option>
                        <option value="fr">French (fr)</option>
                        <option value="de">German (de)</option>
                        <option value="ja">Japanese (ja)</option>
                      </select>
                    </div>
                  )}
                </div>
              </div>
            )}
          </div>

          {/* Error Message */}
          {errorMsg && (
            <div className="text-rose-500 text-xs flex items-center gap-1.5 p-2 rounded bg-rose-500/10 border border-rose-500/30">
              <AlertCircle className="w-3.5 h-3.5 shrink-0" />
              <span>{errorMsg}</span>
            </div>
          )}

          {/* Footer Actions */}
          <div className="flex items-center justify-end gap-2 pt-3 border-t border-compass">
            <button
              type="button"
              onClick={onClose}
              className="px-3.5 py-1.5 bg-compass-subtle hover:bg-compass-hover text-compass-secondary rounded-lg transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              className="px-4 py-1.5 bg-compass-accent font-semibold rounded-lg transition-colors shadow-sm flex items-center gap-1.5"
            >
              <Table2 className="w-3.5 h-3.5" />
              <span>Create Collection</span>
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
