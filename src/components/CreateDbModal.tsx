import React, { useState } from 'react';
import { Database, Table2, AlertCircle } from 'lucide-react';

interface CreateDbModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSubmit: (dbName: string, collName: string) => void;
  defaultDbName?: string;
  isCollectionOnly?: boolean;
}

export const CreateDbModal: React.FC<CreateDbModalProps> = ({
  isOpen,
  onClose,
  onSubmit,
  defaultDbName = '',
  isCollectionOnly = false
}) => {
  const [dbName, setDbName] = useState(defaultDbName);
  const [collName, setCollName] = useState('');
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  if (!isOpen) return null;

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!isCollectionOnly && !dbName.trim()) {
      setErrorMsg('Database name is required');
      return;
    }
    if (!collName.trim()) {
      setErrorMsg('Collection name is required');
      return;
    }

    onSubmit(isCollectionOnly ? defaultDbName : dbName.trim(), collName.trim());
    onClose();
  };

  return (
    <div className="fixed inset-0 bg-black/60 flex items-center justify-center p-3 sm:p-4 z-50 animate-in fade-in select-none">
      <div className="bg-compass-panel border border-compass rounded-xl max-w-md w-full p-4 sm:p-5 space-y-4 shadow-2xl max-h-[92vh] overflow-y-auto custom-scrollbar">
        <div className="flex items-center justify-between pb-3 border-b border-compass">
          <div className="flex items-center gap-2">
            {isCollectionOnly ? (
              <Table2 className="w-4 h-4 text-compass-accent" />
            ) : (
              <Database className="w-4 h-4 text-compass-accent" />
            )}
            <h3 className="text-sm font-semibold text-compass-primary">
              {isCollectionOnly ? `Create Collection in "${defaultDbName}"` : 'Create Database'}
            </h3>
          </div>
          <button onClick={onClose} className="text-compass-muted hover:text-compass-primary text-xs">
            ✕
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-3.5 text-xs">
          {!isCollectionOnly && (
            <div>
              <label className="block text-compass-secondary font-medium mb-1">Database Name</label>
              <input
                type="text"
                placeholder="e.g. inventory, blog_production"
                value={dbName}
                onChange={e => {
                  setDbName(e.target.value);
                  setErrorMsg(null);
                }}
                className="w-full bg-compass-input text-compass-primary p-2.5 rounded border border-compass font-mono focus:outline-none focus:border-emerald-500"
              />
            </div>
          )}

          <div>
            <label className="block text-compass-secondary font-medium mb-1">Collection Name</label>
            <input
              type="text"
              placeholder="e.g. items, users, logs"
              value={collName}
              onChange={e => {
                setCollName(e.target.value);
                setErrorMsg(null);
              }}
              className="w-full bg-compass-input text-compass-primary p-2.5 rounded border border-compass font-mono focus:outline-none focus:border-emerald-500"
            />
          </div>

          {errorMsg && (
            <div className="text-rose-500 text-xs flex items-center gap-1.5">
              <AlertCircle className="w-3.5 h-3.5" />
              <span>{errorMsg}</span>
            </div>
          )}

          <div className="flex items-center justify-end gap-2 pt-3 border-t border-compass">
            <button
              type="button"
              onClick={onClose}
              className="px-3.5 py-1.5 bg-compass-subtle hover:bg-compass-hover text-compass-secondary rounded transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              className="px-4 py-1.5 bg-compass-accent font-bold rounded transition-colors shadow-sm"
            >
              {isCollectionOnly ? 'Create Collection' : 'Create Database'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
