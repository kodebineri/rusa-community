import React, { useState } from 'react';
import { Key, Plus, Trash2, Shield, AlertCircle } from 'lucide-react';
import { MongoIndex } from '../types/mongo';
import { mongoEngine } from '../services/mongoEngine';

interface IndexesViewProps {
  dbName: string;
  collName: string;
  indexes: MongoIndex[];
  onRefresh: () => void;
}

export const IndexesView: React.FC<IndexesViewProps> = ({
  dbName,
  collName,
  indexes,
  onRefresh
}) => {
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [fieldName, setFieldName] = useState('');
  const [direction, setDirection] = useState<'1' | '-1' | 'text'>('1');
  const [isUnique, setIsUnique] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  const handleCreateIndex = (e: React.FormEvent) => {
    e.preventDefault();
    if (!fieldName.trim()) {
      setErrorMsg('Field name is required');
      return;
    }

    const indexName = `${fieldName.trim()}_${direction}`;
    const keysVal = direction === 'text' ? 'text' : (parseInt(direction) as 1 | -1);

    const success = mongoEngine.createIndex(dbName, collName, {
      name: indexName,
      keys: { [fieldName.trim()]: keysVal },
      unique: isUnique
    });

    if (success) {
      setIsModalOpen(false);
      setFieldName('');
      setIsUnique(false);
      setErrorMsg(null);
      onRefresh();
    } else {
      setErrorMsg('An index with this name or key pattern already exists');
    }
  };

  const handleDropIndex = (indexName: string) => {
    if (indexName === '_id_') {
      alert('Cannot drop default _id_ index');
      return;
    }
    if (confirm(`Drop index "${indexName}"?`)) {
      mongoEngine.dropIndex(dbName, collName, indexName);
      onRefresh();
    }
  };

  return (
    <div className="space-y-4">
      {/* Header bar */}
      <div className="bg-compass-panel border border-compass p-3.5 rounded-lg flex flex-col sm:flex-row sm:items-center justify-between gap-3 shadow-sm">
        <div>
          <div className="flex items-center gap-2">
            <Key className="w-4 h-4 text-compass-accent shrink-0" />
            <h3 className="text-sm font-semibold text-compass-primary">Indexes</h3>
          </div>
          <p className="text-xs text-compass-muted mt-0.5">
            Indexes support efficient execution of queries in MongoDB.
          </p>
        </div>

        <button
          onClick={() => {
            setIsModalOpen(true);
            setErrorMsg(null);
          }}
          className="flex items-center gap-1.5 px-3.5 py-1.5 text-xs font-semibold bg-compass-accent rounded transition-colors shadow-sm self-start sm:self-auto"
        >
          <Plus className="w-3.5 h-3.5" />
          <span>Create Index</span>
        </button>
      </div>

      {/* Index list table */}
      <div className="bg-compass-panel border border-compass rounded-lg overflow-x-auto custom-scrollbar shadow-sm">
        <table className="w-full min-w-[500px] text-left text-xs border-collapse">
          <thead>
            <tr className="bg-compass-subtle border-b border-compass text-[11px] font-mono text-compass-muted uppercase">
              <th className="py-2.5 px-3 font-semibold">Index Name</th>
              <th className="py-2.5 px-3 font-semibold">Fields & Order</th>
              <th className="py-2.5 px-3 font-semibold">Properties</th>
              <th className="py-2.5 px-3 font-semibold">Size</th>
              <th className="py-2.5 px-3 text-right">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-compass font-sans">
            {indexes.map(idx => (
              <tr key={idx.name} className="hover:bg-compass-subtle transition-colors">
                {/* Index Name */}
                <td className="py-2.5 px-3 font-mono font-medium text-compass-primary">
                  <div className="flex items-center gap-1.5">
                    {idx.name === '_id_' && <Shield className="w-3.5 h-3.5 text-compass-accent" />}
                    <span>{idx.name}</span>
                  </div>
                </td>

                {/* Key pattern */}
                <td className="py-2.5 px-3 font-mono text-compass-accent font-semibold">
                  {JSON.stringify(idx.keys)}
                </td>

                {/* Properties */}
                <td className="py-2.5 px-3">
                  <div className="flex items-center gap-1.5">
                    {idx.unique && (
                      <span className="text-[10px] px-1.5 py-0.5 rounded bg-blue-500/10 text-blue-600 dark:text-blue-300 border border-blue-500/30 font-semibold">
                        Unique
                      </span>
                    )}
                    {idx.sparse && (
                      <span className="text-[10px] px-1.5 py-0.5 rounded bg-amber-500/10 text-amber-600 dark:text-amber-300 border border-amber-500/30">
                        Sparse
                      </span>
                    )}
                    {!idx.unique && !idx.sparse && (
                      <span className="text-[10px] text-compass-muted">Default</span>
                    )}
                  </div>
                </td>

                {/* Size */}
                <td className="py-2.5 px-3 font-mono tabular-nums text-compass-muted">
                  {idx.sizeKb || 16} KB
                </td>

                {/* Actions */}
                <td className="py-2.5 px-3 text-right">
                  {idx.name === '_id_' ? (
                    <span className="text-[11px] text-compass-muted opacity-60 italic">Protected</span>
                  ) : (
                    <button
                      onClick={() => handleDropIndex(idx.name)}
                      className="p-1 hover:text-rose-500 text-compass-muted hover:bg-compass-hover rounded transition-colors"
                      title="Drop Index"
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Create Index Modal */}
      {isModalOpen && (
        <div className="fixed inset-0 bg-black/60 flex items-center justify-center p-4 z-50 animate-in fade-in">
          <div className="bg-compass-panel border border-compass rounded-xl max-w-md w-full p-5 space-y-4 shadow-2xl">
            <div className="flex items-center justify-between pb-2 border-b border-compass">
              <div className="flex items-center gap-2">
                <Key className="w-4 h-4 text-compass-accent" />
                <h3 className="text-sm font-semibold text-compass-primary">Create New Index</h3>
              </div>
              <button
                onClick={() => setIsModalOpen(false)}
                className="text-compass-muted hover:text-compass-primary text-xs"
              >
                ✕
              </button>
            </div>

            <form onSubmit={handleCreateIndex} className="space-y-3.5 text-xs">
              <div>
                <label className="block text-compass-secondary font-medium mb-1">Field Name</label>
                <input
                  type="text"
                  placeholder="e.g. email, year, user.address.city"
                  value={fieldName}
                  onChange={e => setFieldName(e.target.value)}
                  className="w-full bg-compass-input text-compass-primary p-2 rounded border border-compass font-mono focus:outline-none focus:border-emerald-500"
                />
              </div>

              <div>
                <label className="block text-compass-secondary font-medium mb-1">Index Type / Direction</label>
                <select
                  value={direction}
                  onChange={e => setDirection(e.target.value as any)}
                  className="w-full bg-compass-input text-compass-primary p-2 rounded border border-compass font-mono focus:outline-none focus:border-emerald-500"
                >
                  <option value="1">1 (Ascending)</option>
                  <option value="-1">-1 (Descending)</option>
                  <option value="text">text (Text Index)</option>
                </select>
              </div>

              <div className="pt-1">
                <label className="flex items-center gap-2 text-compass-secondary cursor-pointer">
                  <input
                    type="checkbox"
                    checked={isUnique}
                    onChange={e => setIsUnique(e.target.checked)}
                    className="accent-emerald-600 dark:accent-[#00ED64]"
                  />
                  <span>Create as Unique Index (Rejects duplicate values)</span>
                </label>
              </div>

              {errorMsg && (
                <div className="text-rose-500 text-xs flex items-center gap-1.5">
                  <AlertCircle className="w-3.5 h-3.5" />
                  <span>{errorMsg}</span>
                </div>
              )}

              <div className="flex items-center justify-end gap-2 pt-2 border-t border-compass">
                <button
                  type="button"
                  onClick={() => setIsModalOpen(false)}
                  className="px-3 py-1.5 bg-compass-subtle hover:bg-compass-hover text-compass-secondary rounded transition-colors"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="px-4 py-1.5 bg-compass-accent font-semibold rounded transition-colors"
                >
                  Create
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
