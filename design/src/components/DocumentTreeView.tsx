import React, { useState } from 'react';
import {
  ChevronRight,
  ChevronDown,
  Copy,
  Check,
  Edit2,
  Trash2,
  Files
} from 'lucide-react';
import { MongoDocument } from '../types/mongo';
import { mongoEngine } from '../services/mongoEngine';

interface DocumentTreeViewProps {
  documents: MongoDocument[];
  onEditDocument: (doc: MongoDocument) => void;
  onCloneDocument: (doc: MongoDocument) => void;
  onDeleteDocument: (docId: string, doc?: MongoDocument) => void;
}

export const DocumentTreeView: React.FC<DocumentTreeViewProps> = ({
  documents,
  onEditDocument,
  onCloneDocument,
  onDeleteDocument
}) => {
  const [copiedId, setCopiedId] = useState<string | null>(null);

  const handleCopy = (doc: MongoDocument) => {
    navigator.clipboard.writeText(JSON.stringify(doc, null, 2));
    setCopiedId(doc._id);
    setTimeout(() => setCopiedId(null), 2000);
  };

  return (
    <div className="space-y-3 font-mono text-xs select-text">
      {documents.map((doc, index) => (
        <div
          key={doc._id || index}
          className="bg-compass-panel border border-compass rounded-lg p-3 hover:border-compass-hover transition-colors group/card shadow-sm"
        >
          {/* Document Card Header */}
          <div className="flex flex-wrap items-center justify-between gap-1.5 pb-2 mb-2 border-b border-compass text-xs font-sans">
            <div className="flex items-center gap-1.5 truncate">
              <span className="text-[11px] text-compass-muted font-mono shrink-0">#{index + 1}</span>
              <span className="text-[11px] font-mono badge-compass-accent px-1.5 py-0.5 rounded border max-w-[190px] xs:max-w-[240px] sm:max-w-none truncate">
                ObjectId("{doc._id}")
              </span>
            </div>

            {/* Actions */}
            <div className="flex items-center gap-1.5 opacity-80 group-hover/card:opacity-100 transition-opacity">
              <button
                onClick={() => handleCopy(doc)}
                title="Copy JSON"
                className="p-1 hover:text-compass-accent text-compass-muted hover:bg-compass-subtle rounded transition-colors"
              >
                {copiedId === doc._id ? <Check className="w-3.5 h-3.5 text-compass-accent" /> : <Copy className="w-3.5 h-3.5" />}
              </button>
              <button
                onClick={() => onCloneDocument(doc)}
                title="Clone Document"
                className="p-1 hover:text-compass-accent text-compass-muted hover:bg-compass-subtle rounded transition-colors"
              >
                <Files className="w-3.5 h-3.5" />
              </button>
              <button
                onClick={() => onEditDocument(doc)}
                title="Edit Document"
                className="p-1 hover:text-amber-500 text-compass-muted hover:bg-compass-subtle rounded transition-colors"
              >
                <Edit2 className="w-3.5 h-3.5" />
              </button>
              <button
                onClick={() => onDeleteDocument(doc._id, doc)}
                title="Delete Document"
                className="p-1 hover:text-rose-500 text-compass-muted hover:bg-compass-subtle rounded transition-colors"
              >
                <Trash2 className="w-3.5 h-3.5" />
              </button>
            </div>
          </div>

          {/* Tree Node recursive structure */}
          <div className="pl-1 space-y-1">
            {Object.entries(doc).map(([key, val]) => (
              <TreeNode key={key} propKey={key} value={val} depth={0} />
            ))}
          </div>
        </div>
      ))}
    </div>
  );
};

interface TreeNodeProps {
  propKey: string;
  value: any;
  depth: number;
}

const TreeNode: React.FC<TreeNodeProps> = ({ propKey, value, depth }) => {
  const [isExpanded, setIsExpanded] = useState(depth < 2);
  const type = mongoEngine.detectBsonType(value);
  const isExpandable = (type === 'Object' || type === 'Array') && value !== null;

  const getTypeColor = (t: string) => {
    switch (t) {
      case 'ObjectId':
        return 'text-[#00684A] dark:text-[#00ED64]';
      case 'String':
        return 'text-[#166534] dark:text-[#6ee7b7]';
      case 'Int32':
      case 'Double':
      case 'number':
        return 'text-[#b45309] dark:text-[#fde047]';
      case 'Boolean':
        return 'text-[#1d4ed8] dark:text-[#93c5fd]';
      case 'Date':
        return 'text-[#7e22ce] dark:text-[#c084fc]';
      case 'Array':
      case 'Object':
        return 'text-compass-muted';
      case 'null':
        return 'text-rose-600 dark:text-rose-400';
      default:
        return 'text-compass-primary';
    }
  };

  return (
    <div className="leading-relaxed">
      <div className="flex items-start gap-1 py-0.5 hover:bg-compass-subtle rounded px-1 group/row transition-colors">
        {/* Toggle arrow */}
        {isExpandable ? (
          <button
            type="button"
            onClick={() => setIsExpanded(!isExpanded)}
            className="p-0.5 mt-0.5 text-compass-muted hover:text-compass-primary"
          >
            {isExpanded ? <ChevronDown className="w-3 h-3" /> : <ChevronRight className="w-3 h-3" />}
          </button>
        ) : (
          <div className="w-4" />
        )}

        {/* Key name */}
        <span className="text-compass-primary font-semibold select-text">{propKey}:</span>

        {/* Type indicator */}
        <span className="text-[10px] text-compass-muted font-sans px-1">
          {type === 'Array' ? `Array (${value?.length || 0})` : type}
        </span>

        {/* Value preview */}
        {!isExpandable ? (
          <span className={`select-text break-all font-mono ${getTypeColor(type)}`}>
            {type === 'String' ? `"${value}"` : type === 'null' ? 'null' : String(value)}
          </span>
        ) : !isExpanded ? (
          <span className="text-compass-muted italic select-none">
            {type === 'Array' ? `[ ... ${value.length} items ]` : '{ ... }'}
          </span>
        ) : null}
      </div>

      {/* Children if expanded */}
      {isExpandable && isExpanded && (
        <div className="ml-4 pl-2 border-l border-compass space-y-0.5 mt-0.5">
          {type === 'Array'
            ? value.map((item: any, idx: number) => (
                <TreeNode key={idx} propKey={String(idx)} value={item} depth={depth + 1} />
              ))
            : Object.entries(value).map(([childKey, childVal]) => (
                <TreeNode key={childKey} propKey={childKey} value={childVal} depth={depth + 1} />
              ))}
        </div>
      )}
    </div>
  );
};
