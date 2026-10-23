import React, { useState } from 'react';
import {
  Zap,
  Star,
  Trash2,
  Database,
  ChevronDown,
  ChevronUp
} from 'lucide-react';
import { ConnectionProfile } from '../types/mongo';

interface ConnectionModalProps {
  isOpen: boolean;
  onClose: () => void;
  onConnect: (profile: ConnectionProfile) => void;
  savedConnections: ConnectionProfile[];
  onSaveConnection: (profile: ConnectionProfile) => void;
  onDeleteConnection: (id: string) => void;
  onToggleFavorite: (id: string) => void;
  onLoadSamples: () => void;
}

export const ConnectionModal: React.FC<ConnectionModalProps> = ({
  isOpen,
  onClose,
  onConnect,
  savedConnections,
  onSaveConnection,
  onDeleteConnection,
  onToggleFavorite,
  onLoadSamples
}) => {
  const [uri, setUri] = useState('mongodb://localhost:27017');
  const [connName, setConnName] = useState('Local Standalone');
  const [showAdvanced, setShowAdvanced] = useState(false);
  const [host, setHost] = useState('localhost');
  const [port, setPort] = useState('27017');
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');

  if (!isOpen) return null;

  const handleConnect = (e: React.FormEvent) => {
    e.preventDefault();
    const profile: ConnectionProfile = {
      id: Date.now().toString(),
      name: connName || 'MongoDB Cluster',
      uri: uri || `mongodb://${host}:${port}`,
      lastConnected: new Date().toLocaleTimeString()
    };
    onConnect(profile);
    onClose();
  };

  const handleSaveAndConnect = () => {
    const profile: ConnectionProfile = {
      id: Date.now().toString(),
      name: connName || 'MongoDB Cluster',
      uri: uri || `mongodb://${host}:${port}`,
      lastConnected: new Date().toLocaleTimeString()
    };
    onSaveConnection(profile);
    onConnect(profile);
    onClose();
  };

  return (
    <div className="fixed inset-0 bg-black/60 flex items-center justify-center p-3 sm:p-4 z-50 animate-in fade-in select-none">
      <div className="bg-compass-panel border border-compass rounded-xl max-w-2xl w-full overflow-hidden shadow-2xl flex flex-col max-h-[92vh]">
        {/* Header */}
        <div className="p-4 sm:p-5 border-b border-compass flex items-center justify-between bg-compass-subtle">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-[#00ED64] to-[#00684A] flex items-center justify-center shadow-md shrink-0">
              <svg viewBox="0 0 24 24" className="w-5 h-5 fill-white" preserveAspectRatio="xMidYMid meet">
                <path d="M12 2C12 2 8 8 8 13.5C8 17.5 10 20 12 22C14 20 16 17.5 16 13.5C16 8 12 2 12 2Z" />
              </svg>
            </div>
            <div>
              <h2 className="text-sm sm:text-base font-bold text-compass-primary font-sans">Connect to MongoDB</h2>
              <p className="text-[11px] sm:text-xs text-compass-muted">
                Connect to a standalone instance, replica set, or Atlas cluster
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="text-compass-muted hover:text-compass-primary p-1 rounded hover:bg-compass-hover text-sm"
          >
            ✕
          </button>
        </div>

        {/* Modal Body */}
        <div className="p-4 sm:p-5 overflow-y-auto space-y-4 sm:space-y-5 custom-scrollbar flex-1 text-xs">
          {/* Quick Connect String Input */}
          <form onSubmit={handleConnect} className="space-y-3">
            <div>
              <label className="block text-compass-primary font-semibold mb-1.5 font-sans">
                URI Connection String
              </label>
              <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-2">
                <input
                  type="text"
                  value={uri}
                  onChange={e => setUri(e.target.value)}
                  placeholder="mongodb://localhost:27017 or mongodb+srv://..."
                  className="flex-1 bg-compass-input text-compass-primary font-mono p-2 sm:p-2.5 rounded-lg border border-compass focus:outline-none focus:border-emerald-500"
                />
                <button
                  type="submit"
                  className="px-5 py-2 sm:py-2.5 bg-compass-accent font-bold rounded-lg transition-colors whitespace-nowrap shadow-sm text-center"
                >
                  Connect
                </button>
              </div>
            </div>

            {/* Connection Name */}
            <div>
              <label className="block text-compass-muted mb-1">Friendly Connection Name</label>
              <input
                type="text"
                value={connName}
                onChange={e => setConnName(e.target.value)}
                placeholder="e.g. Production Cluster, Localhost Dev"
                className="w-full bg-compass-input text-compass-primary p-2 rounded border border-compass focus:outline-none focus:border-emerald-500"
              />
            </div>
          </form>

          {/* Advanced toggle */}
          <div>
            <button
              onClick={() => setShowAdvanced(!showAdvanced)}
              className="text-compass-accent hover:underline flex items-center gap-1 font-semibold"
            >
              <span>Advanced Connection Options</span>
              {showAdvanced ? <ChevronUp className="w-3.5 h-3.5" /> : <ChevronDown className="w-3.5 h-3.5" />}
            </button>

            {showAdvanced && (
              <div className="mt-3 p-3.5 bg-compass-input rounded-lg border border-compass grid grid-cols-2 gap-3 animate-in fade-in">
                <div>
                  <label className="block text-compass-muted mb-1">Host</label>
                  <input
                    type="text"
                    value={host}
                    onChange={e => setHost(e.target.value)}
                    className="w-full bg-compass-panel text-compass-primary p-2 rounded border border-compass font-mono"
                  />
                </div>
                <div>
                  <label className="block text-compass-muted mb-1">Port</label>
                  <input
                    type="text"
                    value={port}
                    onChange={e => setPort(e.target.value)}
                    className="w-full bg-compass-panel text-compass-primary p-2 rounded border border-compass font-mono"
                  />
                </div>
                <div>
                  <label className="block text-compass-muted mb-1">Authentication Username</label>
                  <input
                    type="text"
                    value={username}
                    onChange={e => setUsername(e.target.value)}
                    placeholder="Optional"
                    className="w-full bg-compass-panel text-compass-primary p-2 rounded border border-compass"
                  />
                </div>
                <div>
                  <label className="block text-compass-muted mb-1">Authentication Password</label>
                  <input
                    type="password"
                    value={password}
                    onChange={e => setPassword(e.target.value)}
                    placeholder="Optional"
                    className="w-full bg-compass-panel text-compass-primary p-2 rounded border border-compass"
                  />
                </div>
              </div>
            )}
          </div>

          {/* Saved & Favorite Connections */}
          <div className="pt-2 border-t border-compass">
            <div className="flex items-center justify-between mb-2">
              <span className="text-compass-muted font-semibold uppercase tracking-wider text-[11px]">
                Saved Connections ({savedConnections.length})
              </span>
              <button
                onClick={onLoadSamples}
                className="text-[11px] text-compass-accent hover:underline flex items-center gap-1 font-medium"
              >
                <Database className="w-3 h-3" />
                Load Sample Datasets
              </button>
            </div>

            <div className="space-y-1.5">
              {savedConnections.map(conn => (
                <div
                  key={conn.id}
                  className="flex items-center justify-between p-2.5 rounded-lg bg-compass-subtle border border-compass hover:border-compass-hover transition-colors group/item"
                >
                  <div
                    className="flex items-center gap-2.5 cursor-pointer flex-1"
                    onClick={() => {
                      onConnect(conn);
                      onClose();
                    }}
                  >
                    <button
                      onClick={e => {
                        e.stopPropagation();
                        onToggleFavorite(conn.id);
                      }}
                      className={`p-1 hover:text-amber-500 ${conn.favorite ? 'text-amber-500' : 'text-compass-muted'}`}
                    >
                      <Star className={`w-3.5 h-3.5 ${conn.favorite ? 'fill-amber-500' : ''}`} />
                    </button>
                    <div>
                      <div className="font-semibold text-compass-primary">{conn.name}</div>
                      <div className="text-[11px] font-mono text-compass-muted">{conn.uri}</div>
                    </div>
                  </div>

                  <div className="flex items-center gap-2">
                    <button
                      onClick={() => {
                        onConnect(conn);
                        onClose();
                      }}
                      className="px-3 py-1 bg-compass-input hover:bg-compass-accent text-compass-primary font-semibold rounded text-xs transition-colors border border-compass"
                    >
                      Connect
                    </button>
                    <button
                      onClick={() => onDeleteConnection(conn.id)}
                      title="Delete connection"
                      className="p-1 hover:text-rose-500 text-compass-muted"
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Modal Footer */}
        <div className="p-4 bg-compass-subtle border-t border-compass flex items-center justify-between text-xs">
          <span className="text-compass-muted">MongoDB Compass v1.42.0 Web Client</span>
          <div className="flex items-center gap-2">
            <button
              onClick={handleSaveAndConnect}
              className="px-3.5 py-1.5 bg-compass-panel hover:bg-compass-hover text-compass-secondary font-medium rounded transition-colors border border-compass"
            >
              Save & Connect
            </button>
            <button
              onClick={handleConnect}
              className="px-4 py-1.5 bg-compass-accent font-bold rounded transition-colors shadow-sm"
            >
              Connect
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
