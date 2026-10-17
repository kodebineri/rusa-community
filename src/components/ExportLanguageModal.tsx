import React, { useState } from 'react';
import { Code2, Copy, Check } from 'lucide-react';
import { mongoEngine } from '../services/mongoEngine';

interface ExportLanguageModalProps {
  isOpen: boolean;
  onClose: () => void;
  dbName: string;
  collName: string;
  filterStr: string;
  projectStr: string;
  sortStr: string;
}

type SupportedLang = 'node' | 'python' | 'csharp' | 'java' | 'mongosh';

export const ExportLanguageModal: React.FC<ExportLanguageModalProps> = ({
  isOpen,
  onClose,
  dbName,
  collName,
  filterStr,
  projectStr,
  sortStr
}) => {
  const [selectedLang, setSelectedLang] = useState<SupportedLang>('node');
  const [copied, setCopied] = useState(false);

  if (!isOpen) return null;

  const code = mongoEngine.generateCode(
    selectedLang,
    dbName,
    collName,
    filterStr,
    projectStr,
    sortStr
  );

  const handleCopy = () => {
    navigator.clipboard.writeText(code);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const tabs: { id: SupportedLang; label: string }[] = [
    { id: 'node', label: 'Node.js' },
    { id: 'python', label: 'Python (PyMongo)' },
    { id: 'csharp', label: 'C# (.NET)' },
    { id: 'java', label: 'Java' },
    { id: 'mongosh', label: 'Mongo Shell (mongosh)' }
  ];

  return (
    <div className="fixed inset-0 bg-black/60 flex items-center justify-center p-3 sm:p-4 z-50 animate-in fade-in select-none">
      <div className="bg-compass-panel border border-compass rounded-xl max-w-2xl w-full p-4 sm:p-5 space-y-4 shadow-2xl flex flex-col max-h-[90vh]">
        {/* Header */}
        <div className="flex items-center justify-between pb-3 border-b border-compass">
          <div className="flex items-center gap-2">
            <Code2 className="w-4 h-4 text-compass-accent shrink-0" />
            <h3 className="text-sm font-semibold text-compass-primary">
              Export Query to Programming Language
            </h3>
          </div>
          <button onClick={onClose} className="text-compass-muted hover:text-compass-primary text-xs p-1">
            ✕
          </button>
        </div>

        {/* Language Tabs */}
        <div className="flex items-center gap-1 bg-compass-subtle p-1 rounded-lg border border-compass overflow-x-auto no-scrollbar">
          {tabs.map(tab => (
            <button
              key={tab.id}
              onClick={() => setSelectedLang(tab.id)}
              className={`px-3 py-1.5 text-xs font-medium rounded transition-colors whitespace-nowrap ${
                selectedLang === tab.id
                  ? 'bg-compass-panel text-compass-accent shadow-sm font-semibold'
                  : 'text-compass-muted hover:text-compass-primary'
              }`}
            >
              {tab.label}
            </button>
          ))}
        </div>

        {/* Code Content Container */}
        <div className="relative flex-1 bg-compass-input border border-compass rounded-lg p-3.5 overflow-hidden flex flex-col">
          <div className="flex items-center justify-between pb-2 mb-2 border-b border-compass text-[11px] font-mono text-compass-muted">
            <span>{selectedLang}.snippet</span>
            <button
              onClick={handleCopy}
              className="flex items-center gap-1.5 px-2.5 py-1 bg-compass-subtle hover:bg-compass-hover text-compass-primary rounded text-xs transition-colors border border-compass"
            >
              {copied ? <Check className="w-3.5 h-3.5 text-compass-accent" /> : <Copy className="w-3.5 h-3.5" />}
              <span>{copied ? 'Copied!' : 'Copy Code'}</span>
            </button>
          </div>

          <pre className="flex-1 overflow-y-auto font-mono text-xs text-compass-primary leading-relaxed custom-scrollbar select-text whitespace-pre-wrap">
            {code}
          </pre>
        </div>

        {/* Footer */}
        <div className="flex items-center justify-between pt-2 border-t border-compass text-xs">
          <span className="text-compass-muted">
            Generates standard official MongoDB driver query syntax
          </span>
          <button
            onClick={onClose}
            className="px-4 py-1.5 bg-compass-subtle hover:bg-compass-hover text-compass-secondary rounded transition-colors"
          >
            Close
          </button>
        </div>
      </div>
    </div>
  );
};
