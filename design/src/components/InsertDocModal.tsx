import React, { useState } from 'react';
import { AlertCircle, FileCode } from 'lucide-react';
import { mongoEngine } from '../services/mongoEngine';

interface InsertDocModalProps {
  isOpen: boolean;
  onClose: () => void;
  onInsert: (doc: any) => void;
  initialDoc?: any;
}

export const InsertDocModal: React.FC<InsertDocModalProps> = ({
  isOpen,
  onClose,
  onInsert,
  initialDoc
}) => {
  const [docText, setDocText] = useState(() => {
    if (initialDoc) {
      return JSON.stringify(initialDoc, null, 2);
    }
    return JSON.stringify(
      {
        _id: mongoEngine.generateObjectId(),
        title: 'New Entry',
        createdAt: new Date().toISOString(),
        status: 'active',
        tags: ['sample']
      },
      null,
      2
    );
  });
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  if (!isOpen) return null;

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const parsed = JSON.parse(docText);
      onInsert(parsed);
      onClose();
    } catch (err: any) {
      setErrorMsg(`JSON Parse Error: ${err.message}`);
    }
  };

  const generateNewId = () => {
    try {
      const parsed = JSON.parse(docText);
      parsed._id = mongoEngine.generateObjectId();
      setDocText(JSON.stringify(parsed, null, 2));
      setErrorMsg(null);
    } catch {
      // ignore
    }
  };

  return (
    <div className="fixed inset-0 bg-black/60 flex items-center justify-center p-3 sm:p-4 z-50 animate-in fade-in select-none">
      <div className="bg-compass-panel border border-compass rounded-xl max-w-xl w-full p-4 sm:p-5 space-y-4 shadow-2xl max-h-[92vh] overflow-y-auto custom-scrollbar">
        <div className="flex items-center justify-between pb-3 border-b border-compass">
          <div className="flex items-center gap-2">
            <FileCode className="w-4 h-4 text-compass-accent" />
            <h3 className="text-sm font-semibold text-compass-primary">
              {initialDoc ? 'Edit Document' : 'Insert Document'}
            </h3>
          </div>
          <button onClick={onClose} className="text-compass-muted hover:text-compass-primary text-xs">
            ✕
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-3 text-xs">
          <div className="flex items-center justify-between text-[11px] font-mono text-compass-muted">
            <span>JSON DOCUMENT</span>
            <button
              type="button"
              onClick={generateNewId}
              className="text-compass-accent hover:underline font-semibold"
            >
              Generate New _id
            </button>
          </div>

          <textarea
            value={docText}
            onChange={e => {
              setDocText(e.target.value);
              setErrorMsg(null);
            }}
            rows={12}
            className="w-full bg-compass-input text-compass-primary font-mono text-xs p-3 rounded-lg border border-compass focus:outline-none focus:border-emerald-500 custom-scrollbar"
          />

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
              {initialDoc ? 'Save Changes' : 'Insert'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
