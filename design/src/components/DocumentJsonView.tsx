import React, { useState } from 'react';
import { Copy, Check, Save, Edit3, Trash2, Files } from 'lucide-react';
import { MongoDocument } from '../types/mongo';

interface DocumentJsonViewProps {
  documents: MongoDocument[];
  onUpdateDocument: (docId: string, updatedFields: Record<string, any>) => void;
  onCloneDocument: (doc: MongoDocument) => void;
  onDeleteDocument: (docId: string, doc?: MongoDocument) => void;
}

export const DocumentJsonView: React.FC<DocumentJsonViewProps> = ({
  documents,
  onUpdateDocument,
  onCloneDocument,
  onDeleteDocument
}) => {
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editText, setEditText] = useState('');
  const [parseError, setParseError] = useState<string | null>(null);
  const [copiedId, setCopiedId] = useState<string | null>(null);

  const startEdit = (doc: MongoDocument) => {
    setEditingId(doc._id);
    setEditText(JSON.stringify(doc, null, 2));
    setParseError(null);
  };

  const handleSave = (docId: string) => {
    try {
      const parsed = JSON.parse(editText);
      onUpdateDocument(docId, parsed);
      setEditingId(null);
      setParseError(null);
    } catch (err: any) {
      setParseError(err.message);
    }
  };

  const handleCopy = (doc: MongoDocument) => {
    navigator.clipboard.writeText(JSON.stringify(doc, null, 2));
    setCopiedId(doc._id);
    setTimeout(() => setCopiedId(null), 2000);
  };

  return (
    <div className="space-y-3 font-mono text-xs">
      {documents.map((doc, idx) => {
        const isEditing = editingId === doc._id;

        return (
          <div
            key={doc._id || idx}
            className="bg-compass-panel border border-compass rounded-lg overflow-hidden group/json shadow-sm"
          >
            {/* Header bar */}
            <div className="bg-compass-subtle px-3 py-1.5 border-b border-compass flex flex-wrap items-center justify-between gap-1.5 text-[11px] font-sans">
              <div className="flex items-center gap-1.5 truncate">
                <span className="text-compass-muted font-mono shrink-0">#{idx + 1}</span>
                <span className="text-compass-accent font-mono font-semibold truncate max-w-[190px] xs:max-w-[240px] sm:max-w-none">_id: "{doc._id}"</span>
              </div>

              <div className="flex items-center gap-1.5">
                {isEditing ? (
                  <>
                    <button
                      onClick={() => handleSave(doc._id)}
                      className="flex items-center gap-1 px-2.5 py-1 bg-compass-accent text-white font-semibold rounded"
                    >
                      <Save className="w-3 h-3" />
                      Save
                    </button>
                    <button
                      onClick={() => setEditingId(null)}
                      className="px-2.5 py-1 bg-compass-hover text-compass-secondary rounded"
                    >
                      Cancel
                    </button>
                  </>
                ) : (
                  <>
                    <button
                      onClick={() => handleCopy(doc)}
                      title="Copy JSON"
                      className="p-1 hover:text-compass-accent text-compass-muted hover:bg-compass-hover rounded transition-colors"
                    >
                      {copiedId === doc._id ? <Check className="w-3.5 h-3.5 text-compass-accent" /> : <Copy className="w-3.5 h-3.5" />}
                    </button>
                    <button
                      onClick={() => onCloneDocument(doc)}
                      title="Clone Document"
                      className="p-1 hover:text-compass-accent text-compass-muted hover:bg-compass-hover rounded transition-colors"
                    >
                      <Files className="w-3.5 h-3.5" />
                    </button>
                    <button
                      onClick={() => startEdit(doc)}
                      title="Edit JSON in place"
                      className="p-1 hover:text-amber-500 text-compass-muted hover:bg-compass-hover rounded transition-colors"
                    >
                      <Edit3 className="w-3.5 h-3.5" />
                    </button>
                    <button
                      onClick={() => onDeleteDocument(doc._id, doc)}
                      title="Delete Document"
                      className="p-1 hover:text-rose-500 text-compass-muted hover:bg-compass-hover rounded transition-colors"
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  </>
                )}
              </div>
            </div>

            {/* Content editor or formatted display */}
            <div className="p-3">
              {isEditing ? (
                <div>
                  <textarea
                    value={editText}
                    onChange={e => setEditText(e.target.value)}
                    rows={12}
                    className="w-full bg-compass-input text-compass-primary font-mono text-xs p-2.5 rounded border border-emerald-500 focus:outline-none custom-scrollbar"
                  />
                  {parseError && (
                    <div className="text-rose-500 text-[11px] mt-1 font-sans">
                      JSON Error: {parseError}
                    </div>
                  )}
                </div>
              ) : (
                <pre className="text-compass-secondary whitespace-pre-wrap break-all leading-relaxed select-text font-mono">
                  {JSON.stringify(doc, null, 2)}
                </pre>
              )}
            </div>
          </div>
        );
      })}
    </div>
  );
};
