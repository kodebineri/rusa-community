import React, { useState, useEffect } from 'react';
import { RefreshCw, BarChart2 } from 'lucide-react';
import { SchemaFieldStat } from '../types/mongo';
import { mongoEngine } from '../services/mongoEngine';

interface SchemaViewProps {
  dbName: string;
  collName: string;
}

export const SchemaView: React.FC<SchemaViewProps> = ({ dbName, collName }) => {
  const [fields, setFields] = useState<SchemaFieldStat[]>([]);
  const [isAnalyzing, setIsAnalyzing] = useState(false);

  const analyze = () => {
    setIsAnalyzing(true);
    setTimeout(() => {
      const stats = mongoEngine.analyzeSchema(dbName, collName);
      setFields(stats);
      setIsAnalyzing(false);
    }, 250);
  };

  useEffect(() => {
    analyze();
  }, [dbName, collName]);

  const getTypeBadgeColor = (type: string) => {
    switch (type) {
      case 'ObjectId':
        return 'badge-compass-accent border';
      case 'String':
        return 'bg-emerald-500/10 text-emerald-700 dark:text-emerald-300 border-emerald-500/30';
      case 'Int32':
      case 'Double':
      case 'number':
        return 'bg-amber-500/10 text-amber-700 dark:text-amber-300 border-amber-500/30';
      case 'Boolean':
        return 'bg-blue-500/10 text-blue-700 dark:text-blue-300 border-blue-500/30';
      case 'Date':
        return 'bg-purple-500/10 text-purple-700 dark:text-purple-300 border-purple-500/30';
      case 'Array':
        return 'bg-cyan-500/10 text-cyan-700 dark:text-cyan-300 border-cyan-500/30';
      default:
        return 'bg-compass-subtle text-compass-secondary border-compass';
    }
  };

  return (
    <div className="space-y-4">
      {/* Schema Control Header */}
      <div className="bg-compass-panel border border-compass p-3.5 sm:p-4 rounded-lg flex flex-col sm:flex-row sm:items-center justify-between gap-3 shadow-sm">
        <div>
          <div className="flex items-center gap-2">
            <BarChart2 className="w-4 h-4 text-compass-accent shrink-0" />
            <h3 className="text-sm font-semibold text-compass-primary">Schema Analysis</h3>
          </div>
          <p className="text-xs text-compass-muted mt-0.5">
            Analyzed {fields.length} unique fields in <span className="font-mono text-compass-primary font-medium">{collName}</span>
          </p>
        </div>

        <button
          onClick={analyze}
          disabled={isAnalyzing}
          className="flex items-center gap-2 px-3.5 py-1.5 text-xs font-semibold bg-compass-accent disabled:opacity-50 rounded transition-colors shadow-sm self-start sm:self-auto"
        >
          <RefreshCw className={`w-3.5 h-3.5 ${isAnalyzing ? 'animate-spin' : ''}`} />
          <span>{isAnalyzing ? 'Analyzing...' : 'Analyze Schema'}</span>
        </button>
      </div>

      {/* Field Distribution Cards */}
      <div className="space-y-2.5">
        {fields.map(field => (
          <div
            key={field.path}
            className="bg-compass-panel border border-compass rounded-lg p-3 hover:border-compass-hover transition-colors shadow-sm"
          >
            {/* Top Row: Field Path & Type Breakdown */}
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 pb-2 border-b border-compass text-xs">
              <div className="flex items-center gap-2 font-mono">
                <span className="font-semibold text-compass-primary">{field.path}</span>
                <span className="text-[10px] text-compass-muted">
                  ({field.distinctCount} distinct {field.distinctCount === 1 ? 'value' : 'values'})
                </span>
              </div>

              {/* Type pills */}
              <div className="flex items-center gap-1.5 flex-wrap">
                {field.types.map(t => (
                  <span
                    key={t.type}
                    className={`text-[10px] font-mono px-2 py-0.5 rounded border ${getTypeBadgeColor(t.type)}`}
                  >
                    {t.type} ({t.percentage}%)
                  </span>
                ))}
                {field.missingPercentage > 0 && (
                  <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-rose-500/10 text-rose-600 dark:text-rose-300 border border-rose-500/30">
                    Missing ({field.missingPercentage}%)
                  </span>
                )}
              </div>
            </div>

            {/* Middle Row: Visual Distribution Bar */}
            <div className="my-2.5">
              <div className="h-2 w-full bg-compass-subtle rounded-full overflow-hidden flex border border-compass/40">
                {field.types.map(t => (
                  <div
                    key={t.type}
                    style={{ width: `${t.percentage}%` }}
                    className={`h-full ${
                      t.type === 'String'
                        ? 'bg-emerald-500'
                        : t.type === 'ObjectId'
                        ? 'bg-[#00ED64]'
                        : t.type === 'Int32' || t.type === 'Double'
                        ? 'bg-amber-500'
                        : t.type === 'Boolean'
                        ? 'bg-blue-500'
                        : t.type === 'Array'
                        ? 'bg-cyan-500'
                        : 'bg-purple-500'
                    }`}
                    title={`${t.type}: ${t.percentage}%`}
                  />
                ))}
                {field.missingPercentage > 0 && (
                  <div
                    style={{ width: `${field.missingPercentage}%` }}
                    className="h-full bg-rose-500/50"
                    title={`Missing: ${field.missingPercentage}%`}
                  />
                )}
              </div>
            </div>

            {/* Bottom Row: Min/Max or Sample Values */}
            <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-2 text-xs">
              <div className="flex items-center gap-1.5 flex-wrap">
                <span className="text-[11px] text-compass-muted font-sans">Sample values:</span>
                {field.sampleValues.map((val, idx) => (
                  <span
                    key={idx}
                    className="font-mono text-[11px] text-compass-secondary bg-compass-input px-1.5 py-0.5 rounded border border-compass max-w-[200px] truncate"
                  >
                    {typeof val === 'object' ? JSON.stringify(val) : String(val)}
                  </span>
                ))}
              </div>

              {(field.min !== undefined || field.max !== undefined) && (
                <div className="flex items-center gap-3 text-[11px] font-mono text-compass-muted shrink-0">
                  <span>min: <strong className="text-compass-primary">{field.min}</strong></span>
                  <span>max: <strong className="text-compass-primary">{field.max}</strong></span>
                </div>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};
