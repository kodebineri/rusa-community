import React, { useState, useEffect } from 'react';
import { AlertTriangle, Table2, Trash2, X, Eye } from 'lucide-react';

interface DropCollectionModalProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirm: () => void;
  dbName: string;
  collName: string;
  documentCount?: number;
  indexesCount?: number;
  isView?: boolean;
}

export const DropCollectionModal: React.FC<DropCollectionModalProps> = ({
  isOpen,
  onClose,
  onConfirm,
  dbName,
  collName,
  documentCount = 0,
  indexesCount = 1,
  isView = false
}) => {
  const [typedName, setTypedName] = useState('');

  useEffect(() => {
    if (isOpen) {
      setTypedName('');
    }
  }, [isOpen]);

  if (!isOpen) return null;

  const isConfirmed = typedName.trim() === collName;

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (isConfirmed) {
      onConfirm();
      onClose();
    }
  };

  const handleQuickFill = () => {
    setTypedName(collName);
  };

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-labelledby="drop-coll-title"
      className="fixed inset-0 bg-black/60 backdrop-blur-xs flex items-center justify-center p-3 sm:p-4 z-50 animate-in fade-in select-none"
      onClick={e => {
        if (e.target === e.currentTarget) onClose();
      }}
    >
      <div className="bg-compass-panel border border-compass rounded-xl max-w-md w-full p-4 sm:p-5 shadow-2xl space-y-4 max-h-[92vh] flex flex-col">
        {/* Header */}
        <div className="flex items-start justify-between pb-3 border-b border-compass">
          <div className="flex items-center gap-2.5">
            <div className={`p-2 rounded-lg border ${isView ? 'bg-amber-500/10 text-amber-500 border-amber-500/20' : 'bg-rose-500/10 text-rose-500 border-rose-500/20'}`}>
              {isView ? <Eye className="w-4 h-4" /> : <Table2 className="w-4 h-4" />}
            </div>
            <div>
              <h3 id="drop-coll-title" className="text-sm font-semibold text-compass-primary flex items-center gap-2">
                <span>{isView ? 'Drop View' : 'Drop Collection'}</span>
                {isView && (
                  <span className="text-[10px] font-mono font-bold uppercase tracking-wider px-1.5 py-0.5 rounded bg-amber-500/15 text-amber-500 border border-amber-500/30">
                    VIEW
                  </span>
                )}
              </h3>
              <p className="text-[11px] text-compass-muted">
                {isView ? 'Remove saved view from' : 'Permanent deletion from'}{' '}
                <span className="font-mono text-compass-secondary font-medium">{dbName}</span>
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
        <div className={`p-3 rounded-lg border flex items-start gap-2.5 text-xs ${isView ? 'bg-amber-500/10 border-amber-500/20 text-amber-700 dark:text-amber-300' : 'bg-rose-500/10 border-rose-500/20 text-rose-700 dark:text-rose-300'}`}>
          <AlertTriangle className={`w-4 h-4 shrink-0 mt-0.5 ${isView ? 'text-amber-500' : 'text-rose-500'}`} />
          <div className="space-y-1">
            <p className="font-semibold">
              You are about to drop {isView ? 'view' : 'collection'}{' '}
              <span className="font-mono underline font-bold">{collName}</span>
            </p>
            <p className="text-[11px] opacity-90 leading-relaxed">
              {isView
                ? 'Dropping this view will remove the view definition. The underlying source collection and its documents will remain intact and unaffected.'
                : 'Dropping this collection will permanently remove all documents, indexes, and custom schema configurations. This action cannot be undone.'}
            </p>
          </div>
        </div>

        {/* Target Collection/View Metadata Card */}
        <div className="p-3 rounded-lg bg-compass-subtle border border-compass text-xs space-y-2">
          <div className="flex items-center justify-between text-[11px]">
            <span className="text-compass-muted">Database:</span>
            <span className="font-mono text-compass-primary font-medium">{dbName}</span>
          </div>
          <div className="flex items-center justify-between text-[11px]">
            <span className="text-compass-muted">{isView ? 'View Name:' : 'Collection Name:'}</span>
            <span className={`font-mono font-semibold ${isView ? 'text-amber-500' : 'text-rose-500'}`}>{collName}</span>
          </div>
          <div className="flex items-center justify-between text-[11px]">
            <span className="text-compass-muted">Documents Affected:</span>
            <span className="font-mono text-compass-primary">{documentCount.toLocaleString()}</span>
          </div>
          {!isView && (
            <div className="flex items-center justify-between text-[11px]">
              <span className="text-compass-muted">Indexes Affected:</span>
              <span className="font-mono text-compass-primary">{indexesCount}</span>
            </div>
          )}
        </div>

        {/* Type Name to Confirm Form */}
        <form onSubmit={handleSubmit} className="space-y-4 text-xs">
          <div>
            <div className="flex items-center justify-between mb-1.5">
              <label htmlFor="confirm-coll-input" className="text-[11px] font-medium text-compass-secondary">
                Type <span className="font-mono font-bold text-compass-primary">{collName}</span> to confirm:
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
              id="confirm-coll-input"
              type="text"
              value={typedName}
              onChange={e => setTypedName(e.target.value)}
              placeholder={`Type "${collName}"`}
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
              {isView ? 'Drop View' : 'Drop Collection'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
