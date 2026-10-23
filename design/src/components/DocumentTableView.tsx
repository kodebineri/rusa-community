import React, { useState } from 'react';
import { ArrowUpDown, Edit2, Trash2, Copy, Check } from 'lucide-react';
import { MongoDocument } from '../types/mongo';

interface DocumentTableViewProps {
  documents: MongoDocument[];
  onEditDocument: (doc: MongoDocument) => void;
  onDeleteDocument: (docId: string, doc?: MongoDocument) => void;
}

export const DocumentTableView: React.FC<DocumentTableViewProps> = ({
  documents,
  onEditDocument,
  onDeleteDocument
}) => {
  const [copiedId, setCopiedId] = useState<string | null>(null);
  const [sortCol, setSortCol] = useState<string | null>(null);
  const [sortAsc, setSortAsc] = useState(true);

  if (documents.length === 0) {
    return (
      <div className="text-center py-12 text-compass-muted text-xs">
        No documents match the current query
      </div>
    );
  }

  // Derive unique column headers from documents
  const allKeys = Array.from(
    new Set(documents.flatMap(doc => Object.keys(doc)))
  ).sort((a, b) => {
    if (a === '_id') return -1;
    if (b === '_id') return 1;
    return a.localeCompare(b);
  });

  const handleCopy = (doc: MongoDocument) => {
    navigator.clipboard.writeText(JSON.stringify(doc, null, 2));
    setCopiedId(doc._id);
    setTimeout(() => setCopiedId(null), 2000);
  };

  const sortedDocuments = [...documents].sort((a, b) => {
    if (!sortCol) return 0;
    const v1 = a[sortCol];
    const v2 = b[sortCol];
    if (v1 === v2) return 0;
    if (v1 === undefined) return 1;
    if (v2 === undefined) return -1;
    return (v1 > v2 ? 1 : -1) * (sortAsc ? 1 : -1);
  });

  const toggleSort = (col: string) => {
    if (sortCol === col) {
      setSortAsc(!sortAsc);
    } else {
      setSortCol(col);
      setSortAsc(true);
    }
  };

  const renderCellValue = (val: any) => {
    if (val === undefined) return <span className="text-compass-muted/50 italic text-[10px]">undefined</span>;
    if (val === null) return <span className="text-rose-500 font-mono text-[11px]">null</span>;
    if (typeof val === 'boolean') {
      return (
        <span className={val ? 'text-emerald-600 dark:text-[#00ED64]' : 'text-rose-500'}>
          {String(val)}
        </span>
      );
    }
    if (typeof val === 'number') {
      return <span className="text-amber-600 dark:text-amber-300 font-mono tabular-nums">{val}</span>;
    }
    if (typeof val === 'object') {
      if (Array.isArray(val)) {
        return (
          <span className="text-compass-muted font-mono text-[11px] truncate max-w-[150px] inline-block">
            [{val.length} items]
          </span>
        );
      }
      return (
        <span className="text-compass-muted font-mono text-[11px] truncate max-w-[150px] inline-block">
          {`{ ${Object.keys(val).slice(0, 2).join(', ')}... }`}
        </span>
      );
    }
    return <span className="text-compass-primary truncate max-w-[200px] inline-block">{String(val)}</span>;
  };

  return (
    <div className="bg-compass-panel border border-compass rounded-lg overflow-x-auto custom-scrollbar shadow-sm">
      <table className="w-full min-w-[500px] text-left text-xs border-collapse">
        {/* Table Header */}
        <thead>
          <tr className="bg-compass-subtle border-b border-compass text-[11px] font-mono text-compass-muted uppercase">
            <th className="py-2.5 px-3 sticky left-0 bg-compass-subtle z-10 w-12 text-center">#</th>
            {allKeys.map(key => (
              <th
                key={key}
                onClick={() => toggleSort(key)}
                className="py-2.5 px-3 font-semibold hover:text-compass-primary cursor-pointer select-none whitespace-nowrap"
              >
                <div className="flex items-center gap-1.5">
                  <span className={key === '_id' ? 'text-compass-accent font-bold' : ''}>{key}</span>
                  <ArrowUpDown className="w-3 h-3 opacity-60" />
                </div>
              </th>
            ))}
            <th className="py-2.5 px-3 text-right sticky right-0 bg-compass-subtle z-10">Actions</th>
          </tr>
        </thead>

        {/* Table Body */}
        <tbody className="divide-y divide-compass font-sans">
          {sortedDocuments.map((doc, idx) => (
            <tr key={doc._id || idx} className="hover:bg-compass-subtle transition-colors group/row">
              <td className="py-2 px-3 sticky left-0 bg-compass-panel group-hover/row:bg-compass-subtle z-10 font-mono text-[11px] text-compass-muted text-center border-r border-compass/40">
                {idx + 1}
              </td>
              {allKeys.map(key => (
                <td key={key} className="py-2 px-3 whitespace-nowrap">
                  {key === '_id' ? (
                    <span className="font-mono text-[11px] badge-compass-accent px-1.5 py-0.5 rounded border">
                      {doc._id}
                    </span>
                  ) : (
                    renderCellValue(doc[key])
                  )}
                </td>
              ))}
              <td className="py-2 px-3 text-right sticky right-0 bg-compass-panel group-hover/row:bg-compass-subtle z-10 whitespace-nowrap border-l border-compass/40">
                <div className="flex items-center justify-end gap-1">
                  <button
                    onClick={() => handleCopy(doc)}
                    title="Copy Document JSON"
                    className="p-1 hover:text-compass-accent text-compass-muted hover:bg-compass-hover rounded transition-colors"
                  >
                    {copiedId === doc._id ? <Check className="w-3.5 h-3.5 text-compass-accent" /> : <Copy className="w-3.5 h-3.5" />}
                  </button>
                  <button
                    onClick={() => onEditDocument(doc)}
                    title="Edit Document"
                    className="p-1 hover:text-amber-500 text-compass-muted hover:bg-compass-hover rounded transition-colors"
                  >
                    <Edit2 className="w-3.5 h-3.5" />
                  </button>
                  <button
                    onClick={() => onDeleteDocument(doc._id, doc)}
                    title="Delete Document"
                    className="p-1 hover:text-rose-500 text-compass-muted hover:bg-compass-hover rounded transition-colors"
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                  </button>
                </div>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
};
