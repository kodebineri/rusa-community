import React, { useState } from 'react';
import {
  Search,
  SlidersHorizontal,
  RotateCcw,
  Code2,
  CheckCircle2,
  AlertCircle,
  ChevronDown,
  ChevronUp
} from 'lucide-react';
import { QueryFilterOptions } from '../types/mongo';

interface QueryBarProps {
  options: QueryFilterOptions;
  onChangeOptions: (updated: Partial<QueryFilterOptions>) => void;
  onExecuteQuery: () => void;
  onResetQuery: () => void;
  onExportToLanguage: () => void;
  executionTimeMs?: number;
  totalResultsCount?: number;
}

export const QueryBar: React.FC<QueryBarProps> = ({
  options,
  onChangeOptions,
  onExecuteQuery,
  onResetQuery,
  onExportToLanguage,
  executionTimeMs,
  totalResultsCount
}) => {
  const [isOptionsExpanded, setIsOptionsExpanded] = useState(false);
  const [filterError, setFilterError] = useState<string | null>(null);

  const handleFilterChange = (val: string) => {
    onChangeOptions({ filter: val });
    if (!val.trim()) {
      setFilterError(null);
      return;
    }
    try {
      const cleaned = val
        .replace(/([{,]\s*)([a-zA-Z0-9_$.]+)\s*:/g, '$1"$2":')
        .replace(/'/g, '"');
      JSON.parse(cleaned);
      setFilterError(null);
    } catch {
      setFilterError('Incomplete or invalid JSON syntax');
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter') {
      onExecuteQuery();
    }
  };

  return (
    <div className="bg-compass-panel border-b border-compass px-3 sm:px-4 py-2.5 space-y-2 select-none transition-colors duration-150">
      {/* Primary Query Row */}
      <div className="flex flex-col md:flex-row items-stretch md:items-center gap-2">
        {/* Filter input container */}
        <div className="flex-1 relative flex items-center">
          <div className="absolute left-3 flex items-center gap-1.5 pointer-events-none text-compass-muted">
            <Search className="w-3.5 h-3.5" />
            <span className="text-xs font-mono font-semibold text-compass-accent">FILTER</span>
          </div>

          <input
            type="text"
            value={options.filter}
            onChange={e => handleFilterChange(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder="{ field: 'value', price: { $gte: 20 } }"
            className="w-full bg-compass-input text-xs font-mono text-compass-primary pl-20 pr-8 py-2 rounded-lg border border-compass focus:outline-none focus:border-emerald-500 transition-colors placeholder:text-compass-muted"
          />

          {filterError ? (
            <div className="absolute right-2.5 text-amber-500" title={filterError}>
              <AlertCircle className="w-4 h-4" />
            </div>
          ) : options.filter.trim() ? (
            <div className="absolute right-2.5 text-compass-accent" title="Valid query structure">
              <CheckCircle2 className="w-4 h-4" />
            </div>
          ) : null}
        </div>

        {/* Action Controls */}
        <div className="flex items-center gap-1.5 sm:gap-2 shrink-0">
          {/* Options toggle */}
          <button
            onClick={() => setIsOptionsExpanded(!isOptionsExpanded)}
            className={`flex-1 sm:flex-initial flex items-center justify-center gap-1.5 px-3 py-2 text-xs font-medium rounded-lg border transition-colors ${
              isOptionsExpanded || options.project || options.sort || options.skip > 0
                ? 'badge-compass-accent font-semibold'
                : 'text-compass-secondary bg-compass-subtle hover:bg-compass-hover border-compass'
            }`}
          >
            <SlidersHorizontal className="w-3.5 h-3.5" />
            <span>Options</span>
            {isOptionsExpanded ? <ChevronUp className="w-3 h-3" /> : <ChevronDown className="w-3 h-3" />}
          </button>

          {/* Reset */}
          <button
            onClick={onResetQuery}
            title="Reset query options"
            className="p-2 text-compass-muted hover:text-compass-primary bg-compass-subtle hover:bg-compass-hover border border-compass rounded-lg transition-colors shrink-0"
          >
            <RotateCcw className="w-3.5 h-3.5" />
          </button>

          {/* Export to Language */}
          <button
            onClick={onExportToLanguage}
            title="Export query to programming languages"
            className="flex items-center justify-center gap-1.5 p-2 sm:px-3 sm:py-2 text-xs font-medium text-compass-secondary bg-compass-subtle hover:bg-compass-hover hover:text-compass-primary border border-compass rounded-lg transition-colors whitespace-nowrap shrink-0"
          >
            <Code2 className="w-3.5 h-3.5 text-compass-accent" />
            <span className="hidden md:inline">Export</span>
          </button>

          {/* Find Button */}
          <button
            onClick={onExecuteQuery}
            className="flex-1 sm:flex-initial flex items-center justify-center gap-1.5 px-4 sm:px-5 py-2 text-xs font-bold bg-compass-accent rounded-lg transition-colors shadow-sm cursor-pointer whitespace-nowrap"
          >
            Find
          </button>
        </div>
      </div>

      {/* Expanded Query Options Panel */}
      {isOptionsExpanded && (
        <div className="pt-2 border-t border-compass grid grid-cols-2 md:grid-cols-4 gap-2 text-xs animate-in fade-in duration-150">
          {/* Project */}
          <div className="flex flex-col gap-1 col-span-2 sm:col-span-1">
            <label className="text-[11px] font-mono font-medium text-compass-muted flex items-center justify-between">
              <span>PROJECT</span>
              <span className="text-[10px] text-compass-muted font-sans">1 or 0</span>
            </label>
            <input
              type="text"
              value={options.project}
              onChange={e => onChangeOptions({ project: e.target.value })}
              placeholder="{ title: 1, year: 1, _id: 0 }"
              className="bg-compass-input text-xs font-mono text-compass-primary px-2.5 py-1.5 rounded border border-compass focus:outline-none focus:border-emerald-500 placeholder:text-compass-muted"
            />
          </div>

          {/* Sort */}
          <div className="flex flex-col gap-1 col-span-2 sm:col-span-1">
            <label className="text-[11px] font-mono font-medium text-compass-muted flex items-center justify-between">
              <span>SORT</span>
              <span className="text-[10px] text-compass-muted font-sans">1 (asc) / -1 (desc)</span>
            </label>
            <input
              type="text"
              value={options.sort}
              onChange={e => onChangeOptions({ sort: e.target.value })}
              placeholder="{ year: -1, rating: -1 }"
              className="bg-compass-input text-xs font-mono text-compass-primary px-2.5 py-1.5 rounded border border-compass focus:outline-none focus:border-emerald-500 placeholder:text-compass-muted"
            />
          </div>

          {/* Skip */}
          <div className="flex flex-col gap-1 col-span-1">
            <label className="text-[11px] font-mono font-medium text-compass-muted">
              SKIP
            </label>
            <input
              type="number"
              min="0"
              value={options.skip}
              onChange={e => onChangeOptions({ skip: Math.max(0, parseInt(e.target.value) || 0) })}
              className="bg-compass-input text-xs font-mono text-compass-primary px-2.5 py-1.5 rounded border border-compass focus:outline-none focus:border-emerald-500"
            />
          </div>

          {/* Limit */}
          <div className="flex flex-col gap-1 col-span-1">
            <label className="text-[11px] font-mono font-medium text-compass-muted">
              LIMIT
            </label>
            <input
              type="number"
              min="1"
              max="500"
              value={options.limit}
              onChange={e => onChangeOptions({ limit: Math.max(1, parseInt(e.target.value) || 20) })}
              className="bg-compass-input text-xs font-mono text-compass-primary px-2.5 py-1.5 rounded border border-compass focus:outline-none focus:border-emerald-500"
            />
          </div>
        </div>
      )}

      {/* Query Stats Ribbon */}
      {(executionTimeMs !== undefined || totalResultsCount !== undefined) && (
        <div className="flex items-center justify-between text-[11px] text-compass-muted pt-1 font-mono">
          <div className="flex items-center gap-2 sm:gap-3 flex-wrap">
            <span>
              Matches: <strong className="text-compass-primary font-semibold">{totalResultsCount}</strong>
            </span>
            <span>·</span>
            <span>
              Time: <strong className="text-compass-accent font-semibold">{executionTimeMs}ms</strong>
            </span>
          </div>
          <div className="hidden sm:block text-compass-muted text-[10px]">
            Tip: Press <kbd className="px-1 py-0.5 bg-compass-subtle border border-compass rounded text-compass-primary">Enter</kbd> to find
          </div>
        </div>
      )}
    </div>
  );
};
