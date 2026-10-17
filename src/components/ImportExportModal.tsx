import React, { useState } from 'react';
import { Download, Upload, FileText, Check, AlertCircle } from 'lucide-react';
import { MongoDocument } from '../types/mongo';
import { mongoEngine } from '../services/mongoEngine';

interface ImportExportModalProps {
  isOpen: boolean;
  onClose: () => void;
  mode: 'export' | 'import';
  dbName: string;
  collName: string;
  documents: MongoDocument[];
  onImportComplete: () => void;
}

export const ImportExportModal: React.FC<ImportExportModalProps> = ({
  isOpen,
  onClose,
  mode,
  dbName,
  collName,
  documents,
  onImportComplete
}) => {
  const [format, setFormat] = useState<'json' | 'csv'>('json');
  const [importText, setImportText] = useState('');
  const [statusMsg, setStatusMsg] = useState<{ text: string; isError: boolean } | null>(null);

  if (!isOpen) return null;

  const handleExport = () => {
    let content = '';
    let filename = `${dbName}_${collName}`;
    let mimeType = 'text/plain';

    if (format === 'json') {
      content = JSON.stringify(documents, null, 2);
      filename += '.json';
      mimeType = 'application/json';
    } else {
      if (documents.length === 0) {
        content = '';
      } else {
        const keys = Array.from(new Set(documents.flatMap(d => Object.keys(d))));
        const header = keys.join(',');
        const rows = documents.map(d =>
          keys
            .map(k => {
              const val = d[k];
              if (val === undefined || val === null) return '';
              const str = typeof val === 'object' ? JSON.stringify(val) : String(val);
              return `"${str.replace(/"/g, '""')}"`;
            })
            .join(',')
        );
        content = [header, ...rows].join('\n');
      }
      filename += '.csv';
      mimeType = 'text/csv';
    }

    const blob = new Blob([content], { type: mimeType });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    a.click();
    URL.revokeObjectURL(url);
    onClose();
  };

  const handleImport = () => {
    if (!importText.trim()) {
      setStatusMsg({ text: 'Please paste JSON documents or select a file', isError: true });
      return;
    }

    try {
      const parsed = JSON.parse(importText);
      const docsToInsert = Array.isArray(parsed) ? parsed : [parsed];

      for (const d of docsToInsert) {
        mongoEngine.insertDocument(dbName, collName, d);
      }

      setStatusMsg({
        text: `Successfully imported ${docsToInsert.length} documents!`,
        isError: false
      });
      setTimeout(() => {
        onImportComplete();
        onClose();
      }, 1000);
    } catch (err: any) {
      setStatusMsg({ text: `Import parsing error: ${err.message}`, isError: true });
    }
  };

  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = event => {
      const result = event.target?.result as string;
      setImportText(result);
    };
    reader.readAsText(file);
  };

  return (
    <div className="fixed inset-0 bg-black/60 flex items-center justify-center p-3 sm:p-4 z-50 animate-in fade-in select-none">
      <div className="bg-compass-panel border border-compass rounded-xl max-w-lg w-full p-4 sm:p-5 space-y-4 shadow-2xl max-h-[92vh] overflow-y-auto custom-scrollbar">
        <div className="flex items-center justify-between pb-3 border-b border-compass">
          <div className="flex items-center gap-2">
            {mode === 'export' ? (
              <Download className="w-4 h-4 text-compass-accent" />
            ) : (
              <Upload className="w-4 h-4 text-compass-accent" />
            )}
            <h3 className="text-sm font-semibold text-compass-primary">
              {mode === 'export' ? `Export Collection "${collName}"` : `Import into "${collName}"`}
            </h3>
          </div>
          <button onClick={onClose} className="text-compass-muted hover:text-compass-primary text-xs">
            ✕
          </button>
        </div>

        {mode === 'export' ? (
          <div className="space-y-4 text-xs">
            <div>
              <label className="block text-compass-secondary mb-2 font-medium">Select Export Format</label>
              <div className="grid grid-cols-2 gap-3">
                <button
                  type="button"
                  onClick={() => setFormat('json')}
                  className={`p-3 rounded-lg border text-left flex items-center gap-2 transition-colors ${
                    format === 'json'
                      ? 'border-emerald-500 bg-emerald-500/10 text-compass-primary'
                      : 'border-compass bg-compass-input text-compass-muted'
                  }`}
                >
                  <FileText className="w-4 h-4 text-compass-accent" />
                  <div>
                    <div className="font-semibold text-compass-primary">JSON</div>
                    <div className="text-[10px] text-compass-muted">Full BSON / nested structures</div>
                  </div>
                </button>

                <button
                  type="button"
                  onClick={() => setFormat('csv')}
                  className={`p-3 rounded-lg border text-left flex items-center gap-2 transition-colors ${
                    format === 'csv'
                      ? 'border-emerald-500 bg-emerald-500/10 text-compass-primary'
                      : 'border-compass bg-compass-input text-compass-muted'
                  }`}
                >
                  <FileText className="w-4 h-4 text-compass-accent" />
                  <div>
                    <div className="font-semibold text-compass-primary">CSV</div>
                    <div className="text-[10px] text-compass-muted">Spreadsheet comma-separated</div>
                  </div>
                </button>
              </div>
            </div>

            <p className="text-[11px] text-compass-muted">
              Will export currently matched <strong className="text-compass-primary">{documents.length}</strong> documents.
            </p>

            <div className="flex items-center justify-end gap-2 pt-3 border-t border-compass">
              <button
                type="button"
                onClick={onClose}
                className="px-3.5 py-1.5 bg-compass-subtle text-compass-secondary rounded hover:bg-compass-hover"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleExport}
                className="px-4 py-1.5 bg-compass-accent font-bold rounded shadow-sm"
              >
                Export File
              </button>
            </div>
          </div>
        ) : (
          <div className="space-y-3.5 text-xs">
            <div>
              <label className="block text-compass-secondary mb-1 font-medium">Upload File</label>
              <input
                type="file"
                accept=".json,.csv"
                onChange={handleFileUpload}
                className="w-full text-xs text-compass-muted file:mr-3 file:py-1.5 file:px-3 file:rounded file:border-0 file:text-xs file:font-semibold file:bg-compass-subtle file:text-compass-primary hover:file:bg-compass-hover"
              />
            </div>

            <div>
              <label className="block text-compass-secondary mb-1 font-medium">Or Paste JSON Data</label>
              <textarea
                value={importText}
                onChange={e => setImportText(e.target.value)}
                rows={8}
                placeholder="[ { title: 'Document 1' }, { title: 'Document 2' } ]"
                className="w-full bg-compass-input text-compass-primary font-mono text-xs p-2.5 rounded border border-compass focus:outline-none focus:border-emerald-500 custom-scrollbar"
              />
            </div>

            {statusMsg && (
              <div
                className={`p-2 rounded text-xs flex items-center gap-1.5 ${
                  statusMsg.isError
                    ? 'bg-rose-500/10 text-rose-500 border border-rose-500/30'
                    : 'bg-emerald-500/10 text-emerald-700 dark:text-emerald-300 border border-emerald-500/30'
                }`}
              >
                {statusMsg.isError ? <AlertCircle className="w-3.5 h-3.5" /> : <Check className="w-3.5 h-3.5" />}
                <span>{statusMsg.text}</span>
              </div>
            )}

            <div className="flex items-center justify-end gap-2 pt-3 border-t border-compass">
              <button
                type="button"
                onClick={onClose}
                className="px-3.5 py-1.5 bg-compass-subtle text-compass-secondary rounded hover:bg-compass-hover"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleImport}
                className="px-4 py-1.5 bg-compass-accent font-bold rounded shadow-sm"
              >
                Import Documents
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};
