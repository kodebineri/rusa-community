import React, { useState, useEffect } from 'react';
import { Eye, X, AlertCircle, CheckCircle2, Copy, Check, Layers, Database } from 'lucide-react';
import { mongoEngine } from '../services/mongoEngine';

interface SaveViewModalProps {
  isOpen: boolean;
  onClose: () => void;
  dbName: string;
  sourceCollName: string;
  pipeline: any[];
  pipelineJsonString: string;
  onViewSaved: (newViewName: string) => void;
}

export const SaveViewModal: React.FC<SaveViewModalProps> = ({
  isOpen,
  onClose,
  dbName,
  sourceCollName,
  pipeline,
  pipelineJsonString,
  onViewSaved
}) => {
  const [viewName, setViewName] = useState('');
  const [copied, setCopied] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  useEffect(() => {
    if (isOpen) {
      // Suggest a nice default name e.g. `${sourceCollName}_view`
      let candidate = `${sourceCollName}_view`;
      const db = mongoEngine.getDatabase(dbName);
      if (db?.collections[candidate]) {
        candidate = `${sourceCollName}_view_${Date.now().toString().slice(-4)}`;
      }
      setViewName(candidate);
      setError(null);
      setIsSubmitting(false);
    }
  }, [isOpen, dbName, sourceCollName]);

  if (!isOpen) return null;

  const handleCopy = () => {
    navigator.clipboard.writeText(pipelineJsonString);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const validateName = (name: string): string | null => {
    const trimmed = name.trim();
    if (!trimmed) return 'View name is required.';
    if (trimmed.includes('$') || trimmed.startsWith('.')) {
      return 'View name cannot contain "$" or begin with a dot.';
    }
    const db = mongoEngine.getDatabase(dbName);
    if (db && db.collections[trimmed]) {
      const isExistingView = db.collections[trimmed].isView;
      return `A ${isExistingView ? 'view' : 'collection'} named "${trimmed}" already exists in ${dbName}.`;
    }
    return null;
  };

  const handleNameChange = (val: string) => {
    setViewName(val);
    setError(validateName(val));
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const validationErr = validateName(viewName);
    if (validationErr) {
      setError(validationErr);
      return;
    }

    setIsSubmitting(true);
    try {
      mongoEngine.createView(dbName, viewName.trim(), sourceCollName, pipeline);
      onViewSaved(viewName.trim());
      onClose();
    } catch (err: any) {
      setError(err.message || 'Failed to create view.');
      setIsSubmitting(false);
    }
  };

  const currentError = error || validateName(viewName);
  const isValid = !currentError && viewName.trim().length > 0;

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-labelledby="save-view-title"
      className="fixed inset-0 bg-black/60 backdrop-blur-xs flex items-center justify-center p-3 sm:p-4 z-50 animate-in fade-in select-none"
      onClick={e => {
        if (e.target === e.currentTarget) onClose();
      }}
    >
      <div className="bg-compass-panel border border-compass rounded-xl max-w-lg w-full p-4 sm:p-5 shadow-2xl space-y-4 max-h-[92vh] flex flex-col">
        {/* Header */}
        <div className="flex items-start justify-between pb-3 border-b border-compass shrink-0">
          <div className="flex items-center gap-2.5">
            <div className="p-2 rounded-lg bg-amber-500/10 text-amber-500 border border-amber-500/20">
              <Eye className="w-5 h-5" />
            </div>
            <div>
              <h3 id="save-view-title" className="text-sm font-semibold text-compass-primary flex items-center gap-2">
                <span>Save Pipeline as View</span>
                <span className="text-[10px] font-mono font-bold uppercase tracking-wider px-1.5 py-0.5 rounded bg-amber-500/15 text-amber-500 border border-amber-500/30">
                  VIEW
                </span>
              </h3>
              <p className="text-[11px] text-compass-muted">
                Create a read-only MongoDB view in database{' '}
                <span className="font-mono text-compass-secondary font-semibold">{dbName}</span>
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

        {/* Modal Form Body */}
        <form onSubmit={handleSubmit} className="space-y-4 overflow-y-auto pr-0.5 custom-scrollbar">
          {/* Source collection badge */}
          <div className="p-2.5 rounded-lg bg-compass-subtle border border-compass flex items-center justify-between text-xs">
            <div className="flex items-center gap-1.5 text-compass-muted">
              <Database className="w-3.5 h-3.5 text-compass-accent shrink-0" />
              <span>Source Collection:</span>
            </div>
            <span className="font-mono font-semibold text-compass-primary bg-compass-panel px-2 py-0.5 rounded border border-compass">
              {dbName}.{sourceCollName}
            </span>
          </div>

          {/* View Name Input */}
          <div className="space-y-1.5">
            <label htmlFor="view-name-input" className="block text-xs font-semibold text-compass-secondary">
              View Name <span className="text-rose-500">*</span>
            </label>
            <div className="relative">
              <input
                id="view-name-input"
                type="text"
                autoFocus
                value={viewName}
                onChange={e => handleNameChange(e.target.value)}
                placeholder="e.g. active_movies_view"
                className={`w-full bg-compass-input text-xs font-mono text-compass-primary px-3 py-2 rounded-lg border focus:outline-none transition-colors ${
                  currentError
                    ? 'border-rose-500/60 focus:border-rose-500'
                    : 'border-compass focus:border-emerald-500'
                }`}
              />
            </div>
            {currentError ? (
              <p className="text-[11px] text-rose-500 flex items-center gap-1 pt-0.5 animate-in fade-in">
                <AlertCircle className="w-3.5 h-3.5 shrink-0" />
                <span>{currentError}</span>
              </p>
            ) : (
              <p className="text-[11px] text-compass-muted">
                Will be listed alongside collections in the database tree view with a{' '}
                <span className="text-amber-500 font-semibold font-mono">VIEW</span> badge.
              </p>
            )}
          </div>

          {/* Pipeline Preview */}
          <div className="space-y-1.5">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-1.5 text-xs font-medium text-compass-secondary">
                <Layers className="w-3.5 h-3.5 text-compass-accent" />
                <span>Underlying Pipeline Definition</span>
                <span className="text-[10px] px-1.5 py-0.2 rounded-full bg-compass-subtle border border-compass text-compass-muted font-mono">
                  {Array.isArray(pipeline) ? pipeline.length : 0} stage{Array.isArray(pipeline) && pipeline.length === 1 ? '' : 's'}
                </span>
              </div>
              <button
                type="button"
                onClick={handleCopy}
                className="flex items-center gap-1 text-[11px] text-compass-muted hover:text-compass-primary px-1.5 py-0.5 rounded hover:bg-compass-subtle transition-colors"
                title="Copy pipeline JSON"
              >
                {copied ? <Check className="w-3 h-3 text-emerald-500" /> : <Copy className="w-3 h-3" />}
                <span>{copied ? 'Copied' : 'Copy'}</span>
              </button>
            </div>

            <div className="bg-compass-input border border-compass rounded-lg p-2.5 max-h-40 overflow-y-auto custom-scrollbar font-mono text-[11px] text-compass-secondary leading-relaxed">
              <pre className="whitespace-pre-wrap break-all">{pipelineJsonString || '[]'}</pre>
            </div>
          </div>

          {/* Info callout */}
          <div className="p-3 rounded-lg bg-compass-subtle border border-compass text-[11px] text-compass-muted space-y-1">
            <div className="flex items-center gap-1.5 font-semibold text-compass-secondary">
              <Eye className="w-3.5 h-3.5 text-amber-500" />
              <span>MongoDB View Characteristics</span>
            </div>
            <p className="leading-relaxed">
              Views behave like read-only collections. When queried with filters or projections, operations are executed on top of this aggregation pipeline. Underlying data remains authoritatively in{' '}
              <strong className="text-compass-primary font-mono">{sourceCollName}</strong>.
            </p>
          </div>

          {/* Footer Actions */}
          <div className="flex items-center justify-end gap-2 pt-2 border-t border-compass">
            <button
              type="button"
              onClick={onClose}
              className="px-3.5 py-2 text-xs font-medium text-compass-secondary hover:text-compass-primary hover:bg-compass-subtle rounded-lg transition-colors border border-compass"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={!isValid || isSubmitting}
              className="flex items-center gap-1.5 px-4 py-2 text-xs font-semibold bg-emerald-600 hover:bg-emerald-500 dark:bg-[#00ED64] dark:hover:bg-[#00d659] text-white dark:text-[#001E2B] rounded-lg transition-all shadow-sm disabled:opacity-50 disabled:cursor-not-allowed cursor-pointer"
            >
              <Eye className="w-3.5 h-3.5" />
              <span>{isSubmitting ? 'Saving View...' : 'Save View'}</span>
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
