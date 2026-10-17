import React, { useState, useEffect, useRef } from 'react';
import { Database, Table2, Eye, Pencil, AlertCircle, X, Info } from 'lucide-react';
import { mongoEngine } from '../services/mongoEngine';

export interface RenameModalProps {
  isOpen: boolean;
  onClose: () => void;
  type: 'database' | 'collection';
  dbName: string;
  collName?: string;
  isView?: boolean;
  onSuccess: (oldName: string, newName: string, type: 'database' | 'collection') => void;
}

export const RenameModal: React.FC<RenameModalProps> = ({
  isOpen,
  onClose,
  type,
  dbName,
  collName,
  isView,
  onSuccess
}) => {
  const currentName = type === 'database' ? dbName : (collName || '');
  const [newName, setNewName] = useState(currentName);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (isOpen) {
      setNewName(currentName);
      setErrorMsg(null);
      setTimeout(() => {
        if (inputRef.current) {
          inputRef.current.focus();
          inputRef.current.select();
        }
      }, 50);
    }
  }, [isOpen, currentName]);

  if (!isOpen) return null;

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const trimmed = newName.trim();

    if (!trimmed) {
      setErrorMsg(`${type === 'database' ? 'Database' : isView ? 'View' : 'Collection'} name cannot be empty.`);
      return;
    }

    if (trimmed === currentName) {
      setErrorMsg(`New name is identical to the current name.`);
      return;
    }

    try {
      if (type === 'database') {
        mongoEngine.renameDatabase(dbName, trimmed);
        onSuccess(dbName, trimmed, 'database');
      } else {
        if (!collName) throw new Error('No collection specified to rename');
        mongoEngine.renameCollection(dbName, collName, trimmed);
        onSuccess(collName, trimmed, 'collection');
      }
      onClose();
    } catch (err: any) {
      setErrorMsg(err.message || 'Failed to rename. Please check the name format.');
    }
  };

  return (
    <div className="fixed inset-0 bg-black/60 flex items-center justify-center p-3 sm:p-4 z-50 animate-in fade-in select-none">
      <div className="bg-compass-panel border border-compass rounded-xl max-w-md w-full p-4 sm:p-5 space-y-4 shadow-2xl max-h-[92vh] overflow-y-auto custom-scrollbar">
        {/* Modal Header */}
        <div className="flex items-center justify-between pb-3 border-b border-compass">
          <div className="flex items-center gap-2">
            <div className="p-1.5 rounded-lg bg-emerald-500/10 text-compass-accent">
              {type === 'database' ? (
                <Database className="w-4 h-4" />
              ) : isView ? (
                <Eye className="w-4 h-4 text-amber-500" />
              ) : (
                <Table2 className="w-4 h-4" />
              )}
            </div>
            <div>
              <h3 className="text-sm font-semibold text-compass-primary flex items-center gap-1.5">
                <span>
                  Rename {type === 'database' ? 'Database' : isView ? 'View' : 'Collection'}
                </span>
              </h3>
              <p className="text-[11px] text-compass-muted">
                {type === 'database'
                  ? `Change database name across all collections`
                  : `Change name in database "${dbName}"`}
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            type="button"
            className="p-1 text-compass-muted hover:text-compass-primary hover:bg-compass-subtle rounded transition-colors"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Form Body */}
        <form onSubmit={handleSubmit} className="space-y-4 text-xs">
          {/* Current Name Display */}
          <div>
            <label className="block text-compass-secondary font-medium mb-1.5">
              Current Name
            </label>
            <div className="p-2.5 rounded bg-compass-subtle border border-compass font-mono text-compass-muted text-xs truncate flex items-center gap-2">
              {type === 'database' ? (
                <Database className="w-3.5 h-3.5 opacity-60 shrink-0" />
              ) : isView ? (
                <Eye className="w-3.5 h-3.5 text-amber-500/70 shrink-0" />
              ) : (
                <Table2 className="w-3.5 h-3.5 opacity-60 shrink-0" />
              )}
              <span className="truncate">{currentName}</span>
            </div>
          </div>

          {/* New Name Input */}
          <div>
            <label className="block text-compass-secondary font-medium mb-1.5">
              New Name <span className="text-rose-500">*</span>
            </label>
            <input
              ref={inputRef}
              type="text"
              value={newName}
              onChange={e => {
                setNewName(e.target.value);
                setErrorMsg(null);
              }}
              placeholder={`Enter new ${type === 'database' ? 'database' : isView ? 'view' : 'collection'} name`}
              className="w-full bg-compass-input text-compass-primary p-2.5 rounded border border-compass font-mono text-xs focus:outline-none focus:border-emerald-500 transition-colors"
              required
            />
          </div>

          {/* Contextual Guidance */}
          <div className="p-2.5 rounded-lg bg-compass-subtle border border-compass/60 text-[11px] text-compass-muted space-y-1">
            <div className="flex items-center gap-1.5 font-medium text-compass-primary">
              <Info className="w-3 h-3 text-compass-accent shrink-0" />
              <span>MongoDB Naming Rules</span>
            </div>
            {type === 'database' ? (
              <p>
                Database names cannot contain spaces or any of: <code className="text-compass-accent">/ \ . " $ * &lt; &gt; : | ?</code> and must be under 64 characters.
              </p>
            ) : (
              <p>
                {isView
                  ? 'Views will retain their pipeline definition and underlying collection source under the new name.'
                  : 'Collection names cannot contain "$" or begin with "system.". Any views referencing this collection will automatically have their source updated.'}
              </p>
            )}
          </div>

          {/* Error Message */}
          {errorMsg && (
            <div className="p-2.5 rounded-lg bg-rose-500/10 border border-rose-500/30 text-rose-500 text-xs flex items-center gap-2">
              <AlertCircle className="w-4 h-4 shrink-0" />
              <span>{errorMsg}</span>
            </div>
          )}

          {/* Actions */}
          <div className="flex items-center justify-end gap-2 pt-2 border-t border-compass">
            <button
              type="button"
              onClick={onClose}
              className="px-3.5 py-1.5 rounded-lg border border-compass text-compass-secondary hover:text-compass-primary hover:bg-compass-subtle transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              className="flex items-center gap-1.5 px-4 py-1.5 rounded-lg bg-compass-accent text-white font-medium hover:bg-emerald-600 transition-colors shadow-sm"
            >
              <Pencil className="w-3.5 h-3.5" />
              <span>Rename</span>
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
