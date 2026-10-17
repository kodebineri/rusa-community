import React, { useState } from 'react';
import { Trash2, AlertTriangle, Copy, Check, FileJson, X } from 'lucide-react';
import { MongoDocument } from '../types/mongo';

interface DeleteDocumentModalProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirm: () => void;
  dbName: string;
  collName: string;
  documentId: string;
  document?: MongoDocument | null;
}

export const DeleteDocumentModal: React.FC<DeleteDocumentModalProps> = ({
  isOpen,
  onClose,
  onConfirm,
  dbName,
  collName,
  documentId,
  document
}) => {
  const [copied, setCopied] = useState(false);

  if (!isOpen) return null;

  const handleCopyId = () => {
    navigator.clipboard.writeText(documentId);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  // Prepare a formatted preview of the document fields
  let docPreview = '';
  if (document) {
    try {
      docPreview = JSON.stringify(document, null, 2);
    } catch {
      docPreview = String(document);
    }
  }

  return (
    <div
      role="dialog"
      aria-modal="true"
      aria-labelledby="delete-doc-title"
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
              <Trash2 className="w-4 h-4" />
            </div>
            <div>
              <h3 id="delete-doc-title" className="text-sm font-semibold text-compass-primary">
                Delete Document
              </h3>
              <p className="text-[11px] text-compass-muted">
                From{' '}
                <span className="font-mono text-compass-secondary font-medium">
                  {dbName}.{collName}
                </span>
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

        {/* Warning content */}
        <div className="space-y-3 text-xs overflow-y-auto custom-scrollbar pr-0.5">
          <div className="p-3 rounded-lg bg-rose-500/10 border border-rose-500/20 text-rose-700 dark:text-rose-300 flex items-start gap-2.5">
            <AlertTriangle className="w-4 h-4 shrink-0 text-rose-500 mt-0.5" />
            <div className="space-y-1">
              <p className="font-medium">Are you sure you want to delete this document?</p>
              <p className="text-[11px] opacity-90">
                This operation is immediate and permanent. The document cannot be recovered.
              </p>
            </div>
          </div>

          {/* Document ID Pill */}
          <div className="space-y-1.5">
            <label className="text-[11px] font-medium text-compass-secondary uppercase tracking-wider">
              Document Target ID
            </label>
            <div className="flex items-center justify-between p-2 rounded-lg bg-compass-subtle border border-compass font-mono text-xs">
              <span className="text-compass-accent truncate select-all">
                ObjectId("{documentId}")
              </span>
              <button
                onClick={handleCopyId}
                title="Copy ObjectId"
                className="p-1 text-compass-muted hover:text-compass-primary hover:bg-compass-hover rounded transition-colors shrink-0 ml-2"
              >
                {copied ? <Check className="w-3.5 h-3.5 text-compass-accent" /> : <Copy className="w-3.5 h-3.5" />}
              </button>
            </div>
          </div>

          {/* Document Preview Snippet (if available) */}
          {docPreview && (
            <div className="space-y-1.5">
              <div className="flex items-center justify-between text-[11px]">
                <span className="font-medium text-compass-secondary flex items-center gap-1.5">
                  <FileJson className="w-3 h-3 text-compass-muted" /> Document Preview
                </span>
              </div>
              <pre className="p-2.5 rounded-lg bg-[#0C1014] text-[#E8EDEB] text-[11px] font-mono max-h-36 overflow-y-auto custom-scrollbar border border-compass whitespace-pre-wrap select-text">
                {docPreview}
              </pre>
            </div>
          )}
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
            type="button"
            onClick={() => {
              onConfirm();
              onClose();
            }}
            className="px-4 py-2 text-xs font-semibold text-white bg-rose-600 hover:bg-rose-700 active:bg-rose-800 rounded-lg flex items-center gap-1.5 shadow-sm transition-colors"
          >
            <Trash2 className="w-3.5 h-3.5" />
            Delete Document
          </button>
        </div>
      </div>
    </div>
  );
};
