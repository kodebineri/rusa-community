import React, { useState } from 'react';
import { Activity, Zap, FileText } from 'lucide-react';
import { ExplainPlanResult } from '../types/mongo';
import { mongoEngine } from '../services/mongoEngine';

interface ExplainPlanViewProps {
  dbName: string;
  collName: string;
  filterStr: string;
  sortStr: string;
}

export const ExplainPlanView: React.FC<ExplainPlanViewProps> = ({
  dbName,
  collName,
  filterStr,
  sortStr
}) => {
  const [explainResult, setExplainResult] = useState<ExplainPlanResult>(() =>
    mongoEngine.explainPlan(dbName, collName, filterStr, sortStr)
  );

  const reExecute = () => {
    setExplainResult(mongoEngine.explainPlan(dbName, collName, filterStr, sortStr));
  };

  const isIxScan = explainResult.queryPlanner.winningPlan.stage === 'IXSCAN';

  return (
    <div className="space-y-4">
      {/* Header bar */}
      <div className="bg-compass-panel border border-compass p-3.5 sm:p-4 rounded-lg flex flex-col sm:flex-row sm:items-center justify-between gap-3 shadow-sm">
        <div>
          <div className="flex items-center gap-2">
            <Activity className="w-4 h-4 text-compass-accent shrink-0" />
            <h3 className="text-sm font-semibold text-compass-primary">Query Explain Plan</h3>
          </div>
          <p className="text-xs text-compass-muted mt-0.5">
            Visualize the query execution pipeline and identify whether an index was utilized.
          </p>
        </div>

        <button
          onClick={reExecute}
          className="px-3.5 py-1.5 text-xs font-semibold bg-compass-accent rounded transition-colors shadow-sm self-start sm:self-auto"
        >
          Execute Explain
        </button>
      </div>

      {/* KPI Cards Strip */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {/* Execution Stage */}
        <div className="bg-compass-panel border border-compass p-3 rounded-lg shadow-sm">
          <div className="text-[11px] font-mono text-compass-muted uppercase">Winning Stage</div>
          <div className="flex items-center gap-1.5 mt-1">
            <div className={`w-2 h-2 rounded-full ${isIxScan ? 'bg-[#00ED64]' : 'bg-amber-500'}`} />
            <span className="text-base font-bold font-mono text-compass-primary">
              {explainResult.queryPlanner.winningPlan.stage}
            </span>
          </div>
          <div className="text-[10px] text-compass-muted mt-1">
            {isIxScan ? `Index: ${explainResult.queryPlanner.winningPlan.indexName}` : 'Full collection scan'}
          </div>
        </div>

        {/* Execution Time */}
        <div className="bg-compass-panel border border-compass p-3 rounded-lg shadow-sm">
          <div className="text-[11px] font-mono text-compass-muted uppercase">Execution Time</div>
          <div className="text-base font-bold font-mono text-compass-primary mt-1 tabular-nums">
            {explainResult.executionStats.executionTimeMillis} ms
          </div>
          <div className="text-[10px] text-compass-muted mt-1">Simulated latency</div>
        </div>

        {/* Docs Examined */}
        <div className="bg-compass-panel border border-compass p-3 rounded-lg shadow-sm">
          <div className="text-[11px] font-mono text-compass-muted uppercase">Documents Examined</div>
          <div className="text-base font-bold font-mono text-compass-primary mt-1 tabular-nums">
            {explainResult.executionStats.totalDocsExamined}
          </div>
          <div className="text-[10px] text-compass-muted mt-1">
            vs {explainResult.executionStats.nReturned} returned
          </div>
        </div>

        {/* Keys Examined */}
        <div className="bg-compass-panel border border-compass p-3 rounded-lg shadow-sm">
          <div className="text-[11px] font-mono text-compass-muted uppercase">Keys Examined</div>
          <div className="text-base font-bold font-mono text-compass-primary mt-1 tabular-nums">
            {explainResult.executionStats.totalKeysExamined}
          </div>
          <div className="text-[10px] text-compass-muted mt-1">Index keys processed</div>
        </div>
      </div>

      {/* Visual Execution Tree */}
      <div className="bg-compass-panel border border-compass rounded-lg p-4 shadow-sm">
        <h4 className="text-xs font-semibold uppercase tracking-wider text-compass-primary mb-3 flex items-center gap-2">
          <Zap className="w-3.5 h-3.5 text-compass-accent" />
          Visual Execution Tree
        </h4>

        <div className="bg-compass-input border border-compass rounded-lg p-4 space-y-4 font-mono text-xs">
          {/* Root stage */}
          <div className="p-3 rounded border border-compass bg-compass-subtle">
            <div className="flex items-center justify-between text-compass-primary font-bold">
              <span>PROJECTION / RESULT FEED</span>
              <span className="text-compass-accent text-[11px]">Returned: {explainResult.executionStats.nReturned}</span>
            </div>
          </div>

          <div className="w-[2px] h-4 bg-compass mx-auto" />

          {/* Winning Plan stage */}
          <div className={`p-3 rounded border ${isIxScan ? 'badge-compass-accent' : 'border-amber-500/30 bg-amber-500/10 text-amber-700 dark:text-amber-300'}`}>
            <div className="flex items-center justify-between">
              <span className="font-bold">
                STAGE: {explainResult.queryPlanner.winningPlan.stage}
              </span>
              <span className="text-[11px] opacity-75">
                Examined: {explainResult.executionStats.totalDocsExamined}
              </span>
            </div>
            {explainResult.queryPlanner.winningPlan.indexName && (
              <div className="mt-1 text-[11px] font-semibold">
                Target Index: {explainResult.queryPlanner.winningPlan.indexName}
              </div>
            )}
            <div className="mt-1 text-[11px] opacity-75">
              Namespace: {explainResult.queryPlanner.namespace}
            </div>
          </div>
        </div>
      </div>

      {/* Raw Explain JSON output */}
      <div className="bg-compass-panel border border-compass rounded-lg p-4 shadow-sm">
        <div className="flex items-center gap-2 mb-2">
          <FileText className="w-3.5 h-3.5 text-compass-muted" />
          <h4 className="text-xs font-semibold text-compass-primary uppercase tracking-wider">
            Raw Explain JSON
          </h4>
        </div>
        <div className="bg-compass-input border border-compass rounded p-3 font-mono text-xs max-h-48 overflow-y-auto custom-scrollbar">
          <pre className="text-compass-secondary whitespace-pre-wrap">
            {JSON.stringify(explainResult, null, 2)}
          </pre>
        </div>
      </div>
    </div>
  );
};
