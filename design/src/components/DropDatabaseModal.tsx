import React, { useState, useEffect } from 'react';
import { AlertTriangle, Database, Trash2, X } from 'lucide-react';

interface DropDatabaseModalProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirm: () => void;
  dbName: string;
  collectionsCount?: number;
}

export const DropDatabaseModal: React.FC<DropDatabaseModalProps> = ({
  isOpen,
  onClose,
  onConfirm,
  dbName,
  collectionsCount = 0
}) => {
  const [typedName, setTypedName] = useState('');

  useEffect(() => {
    if (isOpen) {
      setTypedName('');
    }
  }, [isOpen]);

  if (!isOpen) return null;

  const isConfirmed = typedName.trim() === dbName;

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (isConfirmed) {
      onConfirm();
      onClose();
    }
  };

  const handleQuickFill = () => {
    setTypedName(dbName);
  };

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-labelledby="drop-db-title"
      className="fixed inset-0 bg-black/60 backdrop-blur-xs flex items-center justify-center p-3 sm:p-4 z-50 animate-in fade-in select-none"
      onClick={e => {
        if (e.target === e.currentTarget) onClose();
      }}
    >
      <div className="bg-compass-panel border border-compass rounded-xl max-w-md w-full p-4 sm:p-5 shadow-2xl space-y-4 max-h-[92vh] flex flex-col">
        {/* Header */}
        <div className="flex items-start justify-between pb-3 border-b border-compass">
          <div className="flex items-center gap-2.5">
            <div className="p-2 rounded-lg bg-rose-500/10 text-rose-500 border border-rose-500/20">
              <Database className="w-4 h-4" />
            </div>
            <div>
              <h3 id="drop-db-title" className="text-sm font-semibold text-compass-primary">
                Drop Database
              </h3>
              <p className="text-[11px] text-compass-muted">
                Permanent deletion of database and all its collections
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            aria-label="Close dialog"
            className="text-compass-muted hover:text-compass-primary p-1 rounded-md hover:bg-compass-hover transition-colors"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Warning Alert Banner */}
        <div className="p-3 rounded-lg bg-rose-500/10 border border-rose-500/20 text-rose-700 dark:text-rose-300 flex items-start gap-2.5 text-xs">
          <AlertTriangle className="w-4 h-4 shrink-0 text-rose-500 mt-0.5" />
          <div className="space-y-1">
            <p className="font-semibold">
              You are about to drop database{' '}
              <span className="font-mono underline font-bold">{dbName}</span>
            </p>
            <p className="text-[11px] opacity-90 leading-relaxed">
              Dropping this database will permanently destroy all its {collectionsCount} collections and all documents within them.
            </p>
          </div>
        </div>

        {/* Form */}
        <form onSubmit={handleSubmit} className="space-y-4 text-xs">
          <div>
            <div className="flex items-center justify-between mb-1.5">
              <label htmlFor="confirm-db-input" className="text-[11px] font-medium text-compass-secondary">
                Type <span className="font-mono font-bold text-compass-primary">{dbName}</span> to confirm:
              </label>
              <button
                type="button"
                onClick={handleQuickFill}
                className="text-[10px] text-compass-accent hover:underline cursor-pointer"
              >
                Auto-fill
              </button>
            </div>
            <input
              id="confirm-db-input"
              type="text"
              value={typedName}
              onChange={e => setTypedName(e.target.value)}
              placeholder={`Type "${dbName}"`}
              autoFocus
              className="w-full px-3 py-2 bg-compass-panel border border-compass rounded-lg text-compass-primary font-mono text-xs focus:outline-none focus:border-rose-500 transition-colors"
            />
          </div>

          {/* Footer Actions */}
          <div className="flex items-center justify-end gap-2 pt-2 border-t border-compass">
            <button
              type="button"
              onClick={onClose}
              className="px-3.5 py-2 text-xs font-medium text-compass-secondary hover:text-compass-primary bg-compass-subtle hover:bg-compass-hover rounded-lg border border-compass transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={!isConfirmed}
              className={`px-4 py-2 text-xs font-semibold rounded-lg flex items-center gap-1.5 shadow-sm transition-all ${
                isConfirmed
                  ? 'bg-rose-600 hover:bg-rose-700 active:bg-rose-800 text-white cursor-pointer'
                  : 'bg-rose-600/30 text-white/50 cursor-not-allowed'
              }`}
            >
              <Trash2 className="w-3.5 h-3.5" />
              Drop Database
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
