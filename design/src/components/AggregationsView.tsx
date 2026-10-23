import React, { useState, useEffect, useMemo, useRef } from 'react';
import {
  Layers,
  Code2,
  Play,
  Plus,
  Trash2,
  Copy,
  Check,
  ChevronUp,
  ChevronDown,
  RotateCcw,
  Download,
  AlertCircle,
  CheckCircle2,
  Sparkles,
  FileJson,
  Table as TableIcon,
  FolderTree,
  Search,
  ExternalLink,
  ChevronRight,
  Info,
  ArrowRightLeft,
  Eye
} from 'lucide-react';
import { PipelineStage } from '../types/mongo';
import { mongoEngine } from '../services/mongoEngine';
import { SaveViewModal } from './SaveViewModal';

interface AggregationsViewProps {
  dbName: string;
  collName: string;
  onExportPipeline?: (pipeline: PipelineStage[]) => void;
  onViewCreated?: (viewName: string) => void;
}

type AggregationMode = 'visual' | 'raw';
type ResultViewMode = 'json' | 'table' | 'tree';

interface PresetOption {
  id: string;
  name: string;
  description: string;
  script: string;
  stages: PipelineStage[];
}

const DEFAULT_TEMPLATES: Record<string, string> = {
  $match: '{\n  "year": { "$gte": 1990 }\n}',
  $group: '{\n  "_id": "$year",\n  "count": { "$sum": 1 },\n  "avgRating": { "$avg": "$imdb.rating" }\n}',
  $sort: '{\n  "avgRating": -1\n}',
  $project: '{\n  "title": 1,\n  "year": 1,\n  "rating": "$imdb.rating"\n}',
  $limit: '10',
  $skip: '0',
  $unwind: '"$genres"',
  $count: '"total_movies"',
  $addFields: '{\n  "isModern": { "$gte": ["$year", 2000] }\n}',
  $lookup: '{\n  "from": "comments",\n  "localField": "_id",\n  "foreignField": "movie_id",\n  "as": "userComments"\n}',
  $facet: '{\n  "byYear": [\n    { "$group": { "_id": "$year", "count": { "$sum": 1 } } },\n    { "$sort": { "count": -1 } },\n    { "$limit": 5 }\n  ],\n  "topRated": [\n    { "$sort": { "imdb.rating": -1 } },\n    { "$limit": 3 }\n  ]\n}'
};

const PRESET_PIPELINES: PresetOption[] = [
  {
    id: 'match-group-sort',
    name: '1. Match & Group (Count & Avg Rating)',
    description: 'Filter by year >= 1980, group by year, compute count & average rating, sort descending',
    script: `[
  {
    "$match": {
      "year": { "$gte": 1980 }
    }
  },
  {
    "$group": {
      "_id": "$year",
      "count": { "$sum": 1 },
      "avgRating": { "$avg": "$imdb.rating" }
    }
  },
  {
    "$sort": {
      "_id": -1
    }
  }
]`,
    stages: [
      { id: 'p1', operator: '$match', content: '{\n  "year": { "$gte": 1980 }\n}', enabled: true },
      { id: 'p2', operator: '$group', content: '{\n  "_id": "$year",\n  "count": { "$sum": 1 },\n  "avgRating": { "$avg": "$imdb.rating" }\n}', enabled: true },
      { id: 'p3', operator: '$sort', content: '{\n  "_id": -1\n}', enabled: true }
    ]
  },
  {
    id: 'unwind-genres',
    name: '2. Unwind Genres & Distribution',
    description: 'Deconstruct genres array and calculate movies count per genre',
    script: `[
  {
    "$unwind": "$genres"
  },
  {
    "$group": {
      "_id": "$genres",
      "count": { "$sum": 1 },
      "avgRating": { "$avg": "$imdb.rating" }
    }
  },
  {
    "$sort": {
      "count": -1
    }
  },
  {
    "$limit": 10
  }
]`,
    stages: [
      { id: 'u1', operator: '$unwind', content: '"$genres"', enabled: true },
      { id: 'u2', operator: '$group', content: '{\n  "_id": "$genres",\n  "count": { "$sum": 1 },\n  "avgRating": { "$avg": "$imdb.rating" }\n}', enabled: true },
      { id: 'u3', operator: '$sort', content: '{\n  "count": -1\n}', enabled: true },
      { id: 'u4', operator: '$limit', content: '10', enabled: true }
    ]
  },
  {
    id: 'lookup-comments',
    name: '3. Lookup Join (Movies with Comments)',
    description: 'Join movies collection with comments collection using $lookup',
    script: `[
  {
    "$match": {
      "year": { "$gte": 1990 }
    }
  },
  {
    "$lookup": {
      "from": "comments",
      "localField": "_id",
      "foreignField": "movie_id",
      "as": "userComments"
    }
  },
  {
    "$project": {
      "title": 1,
      "year": 1,
      "userComments": 1,
      "rating": "$imdb.rating"
    }
  },
  {
    "$limit": 5
  }
]`,
    stages: [
      { id: 'l1', operator: '$match', content: '{\n  "year": { "$gte": 1990 }\n}', enabled: true },
      { id: 'l2', operator: '$lookup', content: '{\n  "from": "comments",\n  "localField": "_id",\n  "foreignField": "movie_id",\n  "as": "userComments"\n}', enabled: true },
      { id: 'l3', operator: '$project', content: '{\n  "title": 1,\n  "year": 1,\n  "userComments": 1,\n  "rating": "$imdb.rating"\n}', enabled: true },
      { id: 'l4', operator: '$limit', content: '5', enabled: true }
    ]
  },
  {
    id: 'top-rated',
    name: '4. Sort & Limit (Top 10 Highest Rated)',
    description: 'Find highest rated films and project simplified fields',
    script: `[
  {
    "$sort": {
      "imdb.rating": -1
    }
  },
  {
    "$project": {
      "title": 1,
      "year": 1,
      "rating": "$imdb.rating",
      "genres": 1
    }
  },
  {
    "$limit": 10
  }
]`,
    stages: [
      { id: 't1', operator: '$sort', content: '{\n  "imdb.rating": -1\n}', enabled: true },
      { id: 't2', operator: '$project', content: '{\n  "title": 1,\n  "year": 1,\n  "rating": "$imdb.rating",\n  "genres": 1\n}', enabled: true },
      { id: 't3', operator: '$limit', content: '10', enabled: true }
    ]
  },
  {
    id: 'addfields-modern',
    name: '5. Add Computed Fields ($addFields)',
    description: 'Add custom flags and filter calculated properties',
    script: `[
  {
    "$addFields": {
      "isModern": { "$gte": ["$year", 2000] }
    }
  },
  {
    "$project": {
      "title": 1,
      "year": 1,
      "isModern": 1,
      "rating": "$imdb.rating"
    }
  },
  {
    "$limit": 10
  }
]`,
    stages: [
      { id: 'a1', operator: '$addFields', content: '{\n  "isModern": { "$gte": ["$year", 2000] }\n}', enabled: true },
      { id: 'a2', operator: '$project', content: '{\n  "title": 1,\n  "year": 1,\n  "isModern": 1,\n  "rating": "$imdb.rating"\n}', enabled: true },
      { id: 'a3', operator: '$limit', content: '10', enabled: true }
    ]
  },
  {
    id: 'count-aggregate',
    name: '6. Count Total Documents ($count)',
    description: 'Filter movies after 1990 and count result total',
    script: `[
  {
    "$match": {
      "year": { "$gte": 1990 }
    }
  },
  {
    "$count": "total_modern_movies"
  }
]`,
    stages: [
      { id: 'c1', operator: '$match', content: '{\n  "year": { "$gte": 1990 }\n}', enabled: true },
      { id: 'c2', operator: '$count', content: '"total_modern_movies"', enabled: true }
    ]
  }
];

export const AggregationsView: React.FC<AggregationsViewProps> = ({
  dbName,
  collName,
  onExportPipeline,
  onViewCreated
}) => {
  // Current active mode: 'visual' (Pipeline Builder) or 'raw' (JSON Script)
  const [activeMode, setActiveMode] = useState<AggregationMode>('visual');

  // Check if current target is already a MongoDB View
  const currentColl = useMemo(() => {
    return mongoEngine.getCollection(dbName, collName);
  }, [dbName, collName]);
  const isCurrentCollView = Boolean(currentColl?.isView);

  // Visual Pipeline Stages State
  const [visualStages, setVisualStages] = useState<PipelineStage[]>([
    {
      id: '1',
      operator: '$match',
      content: '{\n  "year": { "$gte": 1980 }\n}',
      enabled: true
    },
    {
      id: '2',
      operator: '$group',
      content: '{\n  "_id": "$year",\n  "count": { "$sum": 1 },\n  "avgRating": { "$avg": "$imdb.rating" }\n}',
      enabled: true
    },
    {
      id: '3',
      operator: '$sort',
      content: '{\n  "_id": -1\n}',
      enabled: true
    }
  ]);

  // Raw Aggregation Script State (JSON array or shell script)
  const [rawScript, setRawScript] = useState<string>(() => {
    return PRESET_PIPELINES[0].script;
  });

  // Results & previews
  const [visualResults, setVisualResults] = useState<any[]>([]);
  const [visualExecutionTime, setVisualExecutionTime] = useState<number>(0);
  const [stagePreviews, setStagePreviews] = useState<{ stageIndex: number; count: number; sample: any[] }[]>([]);
  const [visualError, setVisualError] = useState<string | null>(null);

  const [rawResults, setRawResults] = useState<any[]>([]);
  const [rawExecutionTime, setRawExecutionTime] = useState<number>(0);
  const [rawStageCount, setRawStageCount] = useState<number>(0);
  const [rawError, setRawError] = useState<string | null>(null);

  // Common UI State
  const [autoRunRaw, setAutoRunRaw] = useState<boolean>(true);
  const [resultViewMode, setResultViewMode] = useState<ResultViewMode>('json');
  const [resultFilterTerm, setResultFilterTerm] = useState<string>('');
  const [notification, setNotification] = useState<{ message: string; type: 'success' | 'error' | 'info' } | null>(null);
  const [copiedScript, setCopiedScript] = useState<boolean>(false);
  const [copiedResults, setCopiedResults] = useState<boolean>(false);

  // Export Modal State
  const [isExportModalOpen, setIsExportModalOpen] = useState<boolean>(false);
  const [exportLang, setExportLang] = useState<'node' | 'python' | 'mongosh' | 'csharp' | 'java'>('node');
  const [copiedExportCode, setCopiedExportCode] = useState<boolean>(false);

  // Save as View Modal State
  const [isSaveViewModalOpen, setIsSaveViewModalOpen] = useState<boolean>(false);

  // Raw Script Textarea ref for inserting snippets
  const rawTextareaRef = useRef<HTMLTextAreaElement>(null);

  // Pre-load pipeline definition if current collection is an existing View
  useEffect(() => {
    if (currentColl && currentColl.isView && currentColl.pipeline && Array.isArray(currentColl.pipeline)) {
      setRawScript(JSON.stringify(currentColl.pipeline, null, 2));
      try {
        const stages: PipelineStage[] = currentColl.pipeline.map((p, idx) => {
          const op = (Object.keys(p).find(k => k.startsWith('$')) || Object.keys(p)[0]) as PipelineStage['operator'];
          return {
            id: String(idx + 1),
            operator: op,
            content: JSON.stringify(p[op], null, 2),
            enabled: true
          };
        });
        if (stages.length > 0) {
          setVisualStages(stages);
        }
      } catch {
        // fallback
      }
    }
  }, [dbName, collName, currentColl]);

  // Compute canonical pipeline array from either mode for Save as View
  const currentPipelineArray = useMemo(() => {
    if (activeMode === 'visual') {
      return visualStages
        .filter(s => s.enabled)
        .map(s => {
          let parsed: any;
          try {
            parsed = mongoEngine.tolerantParse(s.content);
          } catch {
            parsed = s.content;
          }
          return { [s.operator]: parsed };
        });
    } else {
      try {
        return mongoEngine.parseAggregationScript(rawScript);
      } catch {
        return [];
      }
    }
  }, [activeMode, visualStages, rawScript]);

  const currentPipelineJsonString = useMemo(() => {
    return JSON.stringify(currentPipelineArray, null, 2);
  }, [currentPipelineArray]);

  // Show transient notification toast
  const showToast = (message: string, type: 'success' | 'error' | 'info' = 'success') => {
    setNotification({ message, type });
    setTimeout(() => {
      setNotification(prev => (prev?.message === message ? null : prev));
    }, 3000);
  };

  // ----------------------------------------------------
  // Visual Pipeline Execution
  // ----------------------------------------------------
  const runVisualPipeline = () => {
    try {
      setVisualError(null);
      const res = mongoEngine.executeAggregation(dbName, collName, visualStages);
      setVisualResults(res.documents);
      setStagePreviews(res.stageResults);
      setVisualExecutionTime(res.executionTimeMs);
    } catch (err: any) {
      setVisualError(err.message);
    }
  };

  useEffect(() => {
    runVisualPipeline();
  }, [dbName, collName, visualStages]);

  // ----------------------------------------------------
  // Raw Aggregation Script Execution
  // ----------------------------------------------------
  const runRawPipeline = () => {
    try {
      setRawError(null);
      const res = mongoEngine.executeRawAggregation(dbName, collName, rawScript);
      setRawResults(res.documents);
      setRawExecutionTime(res.executionTimeMs);
      setRawStageCount(res.stagesCount);
    } catch (err: any) {
      setRawError(err.message);
    }
  };

  // Auto-run raw aggregation on changes with debounce
  useEffect(() => {
    if (!autoRunRaw) return;
    const timer = setTimeout(() => {
      runRawPipeline();
    }, 280);
    return () => clearTimeout(timer);
  }, [rawScript, dbName, collName, autoRunRaw]);

  // Initial execution of raw script
  useEffect(() => {
    runRawPipeline();
  }, [dbName, collName]);

  // ----------------------------------------------------
  // Two-Way Conversion Logic
  // ----------------------------------------------------
  // Convert Visual Stages -> Raw Script
  const handleConvertToRaw = () => {
    try {
      const generatedJson = mongoEngine.pipelineStagesToRawJson(visualStages);
      setRawScript(generatedJson);
      setActiveMode('raw');
      showToast(`Converted ${visualStages.filter(s => s.enabled).length} visual stages to raw JSON script`);
    } catch (err: any) {
      showToast(`Conversion failed: ${err.message}`, 'error');
    }
  };

  // Convert Raw Script -> Visual Stages
  const handleConvertToVisual = () => {
    try {
      const parsedStages = mongoEngine.rawJsonToPipelineStages(rawScript);
      setVisualStages(parsedStages);
      setActiveMode('visual');
      showToast(`Parsed ${parsedStages.length} stages into Visual Pipeline Builder`);
    } catch (err: any) {
      setRawError(err.message);
      showToast(`Cannot convert script: ${err.message}`, 'error');
    }
  };

  // Format / Prettify raw JSON script
  const handleFormatRawJson = () => {
    try {
      const parsed = mongoEngine.parseAggregationScript(rawScript);
      setRawScript(JSON.stringify(parsed, null, 2));
      setRawError(null);
      showToast('Formatted JSON script');
    } catch (err: any) {
      setRawError(`Cannot format: ${err.message}`);
    }
  };

  // Insert stage snippet into Raw Script
  const handleInsertRawSnippet = (operator: string) => {
    const template = DEFAULT_TEMPLATES[operator] || '{}';
    let snippetToAdd = `{\n    "${operator}": ${template}\n  }`;

    try {
      const parsed = mongoEngine.parseAggregationScript(rawScript);
      if (Array.isArray(parsed)) {
        let snippetObj: any;
        try {
          snippetObj = JSON.parse(template);
        } catch {
          snippetObj = template;
        }
        parsed.push({ [operator]: snippetObj });
        setRawScript(JSON.stringify(parsed, null, 2));
        showToast(`Appended ${operator} stage`);
        return;
      }
    } catch {
      // Fallback: append textually
    }

    // Textual append
    const trimmed = rawScript.trim();
    if (trimmed.endsWith(']')) {
      const withoutClose = trimmed.slice(0, -1).trimEnd();
      const needsComma = withoutClose.length > 1 && !withoutClose.endsWith('[');
      const newScript = `${withoutClose}${needsComma ? ',' : ''}\n  ${snippetToAdd}\n]`;
      setRawScript(newScript);
    } else {
      setRawScript(`[\n  ${snippetToAdd}\n]`);
    }
    showToast(`Appended ${operator} stage`);
  };

  // Load a preset pipeline
  const handleApplyPreset = (preset: PresetOption) => {
    setRawScript(preset.script);
    setVisualStages(preset.stages);
    showToast(`Loaded template "${preset.name}"`);
  };

  // ----------------------------------------------------
  // Visual Pipeline Actions
  // ----------------------------------------------------
  const addVisualStage = (operator: PipelineStage['operator'] = '$match') => {
    const newStage: PipelineStage = {
      id: String(Date.now()),
      operator,
      content: DEFAULT_TEMPLATES[operator] || '{}',
      enabled: true
    };
    setVisualStages(prev => [...prev, newStage]);
  };

  const updateVisualStage = (id: string, updates: Partial<PipelineStage>) => {
    setVisualStages(prev =>
      prev.map(s => {
        if (s.id !== id) return s;
        const updated = { ...s, ...updates };
        if (updates.operator && updates.operator !== s.operator) {
          updated.content = DEFAULT_TEMPLATES[updates.operator] || '{}';
        }
        return updated;
      })
    );
  };

  const removeVisualStage = (id: string) => {
    setVisualStages(prev => prev.filter(s => s.id !== id));
  };

  const moveVisualStage = (index: number, direction: 'up' | 'down') => {
    const targetIndex = direction === 'up' ? index - 1 : index + 1;
    if (targetIndex < 0 || targetIndex >= visualStages.length) return;

    setVisualStages(prev => {
      const copy = [...prev];
      const temp = copy[index];
      copy[index] = copy[targetIndex];
      copy[targetIndex] = temp;
      return copy;
    });
  };

  const duplicateVisualStage = (stage: PipelineStage) => {
    const cloned: PipelineStage = {
      ...stage,
      id: String(Date.now()),
      enabled: true
    };
    setVisualStages(prev => [...prev, cloned]);
    showToast(`Duplicated ${stage.operator} stage`);
  };

  const formatVisualStageContent = (id: string) => {
    const stage = visualStages.find(s => s.id === id);
    if (!stage) return;
    try {
      const parsed = mongoEngine.tolerantParse(stage.content);
      updateVisualStage(id, { content: JSON.stringify(parsed, null, 2) });
    } catch {
      // ignore
    }
  };

  // ----------------------------------------------------
  // Results Display Helpers
  // ----------------------------------------------------
  const currentActiveResults = activeMode === 'visual' ? visualResults : rawResults;
  const currentExecutionTime = activeMode === 'visual' ? visualExecutionTime : rawExecutionTime;

  const filteredResults = useMemo(() => {
    if (!resultFilterTerm.trim()) return currentActiveResults;
    const term = resultFilterTerm.toLowerCase();
    return currentActiveResults.filter(doc => {
      try {
        return JSON.stringify(doc).toLowerCase().includes(term);
      } catch {
        return false;
      }
    });
  }, [currentActiveResults, resultFilterTerm]);

  // Extract tabular columns for Table View
  const tableColumns = useMemo(() => {
    if (!filteredResults || filteredResults.length === 0) return [];
    const keysSet = new Set<string>();
    keysSet.add('_id');
    filteredResults.slice(0, 30).forEach(doc => {
      if (typeof doc === 'object' && doc !== null) {
        Object.keys(doc).forEach(k => keysSet.add(k));
      }
    });
    return Array.from(keysSet);
  }, [filteredResults]);

  const handleCopyResults = () => {
    navigator.clipboard.writeText(JSON.stringify(currentActiveResults, null, 2));
    setCopiedResults(true);
    setTimeout(() => setCopiedResults(false), 2000);
  };

  const handleDownloadResults = () => {
    const blob = new Blob([JSON.stringify(currentActiveResults, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `${collName}_aggregation_results.json`;
    a.click();
    URL.revokeObjectURL(url);
  };

  const handleCopyRawScript = () => {
    navigator.clipboard.writeText(rawScript);
    setCopiedScript(true);
    setTimeout(() => setCopiedScript(false), 2000);
  };

  // Generate code for export modal
  const exportPipelineJson = activeMode === 'visual'
    ? mongoEngine.pipelineStagesToRawJson(visualStages)
    : rawScript;

  const exportGeneratedCode = useMemo(() => {
    return mongoEngine.generateAggregationCode(exportLang, dbName, collName, exportPipelineJson);
  }, [exportLang, dbName, collName, exportPipelineJson]);

  const handleCopyExportCode = () => {
    navigator.clipboard.writeText(exportGeneratedCode);
    setCopiedExportCode(true);
    setTimeout(() => setCopiedExportCode(false), 2000);
  };

  // Compute line numbers for raw script editor
  const rawLineCount = useMemo(() => {
    return Math.max(1, rawScript.split('\n').length);
  }, [rawScript]);

  return (
    <div className="space-y-4">
      {/* Toast Notification */}
      {notification && (
        <div
          className={`flex items-center gap-2 px-3.5 py-2 rounded-lg text-xs font-medium border shadow-md animate-in fade-in slide-in-from-top-1 ${
            notification.type === 'error'
              ? 'bg-rose-500/10 text-rose-500 border-rose-500/30'
              : notification.type === 'info'
              ? 'bg-sky-500/10 text-sky-500 border-sky-500/30'
              : 'bg-emerald-500/10 text-emerald-600 dark:text-[#00ED64] border-emerald-500/30'
          }`}
        >
          {notification.type === 'error' ? (
            <AlertCircle className="w-4 h-4 shrink-0" />
          ) : (
            <CheckCircle2 className="w-4 h-4 shrink-0" />
          )}
          <span>{notification.message}</span>
        </div>
      )}

      {/* View Source Info Banner if target collection is a View */}
      {isCurrentCollView && (
        <div className="bg-amber-500/10 border border-amber-500/30 rounded-lg p-3 text-xs flex flex-col sm:flex-row sm:items-center justify-between gap-2.5 text-amber-700 dark:text-amber-400">
          <div className="flex items-center gap-2">
            <Eye className="w-4 h-4 text-amber-500 shrink-0" />
            <span>
              <strong>MongoDB View:</strong> You are aggregating on view <strong>{collName}</strong> (source: <strong>{currentColl?.viewOn || collName}</strong>). Pipeline below represents its underlying definition.
            </span>
          </div>
          <span className="text-[10px] uppercase font-bold tracking-wider px-2 py-0.5 rounded bg-amber-500/20 border border-amber-500/40 shrink-0 self-start sm:self-auto font-mono">
            Read-Only View
          </span>
        </div>
      )}

      {/* Top Main Mode Header: Segmented Switcher for Two Types of Aggregation */}
      <div className="bg-compass-panel border border-compass p-3.5 rounded-lg flex flex-col md:flex-row md:items-center justify-between gap-3 shadow-sm">
        {/* Left: Two Types of Aggregations Tab Switcher */}
        <div className="flex items-center gap-2">
          <div className="bg-compass-subtle p-1 rounded-lg border border-compass flex items-center">
            {/* Type 1: Visual Aggregation (Pipeline Builder) */}
            <button
              onClick={() => setActiveMode('visual')}
              className={`flex items-center gap-2 px-3.5 py-1.5 rounded text-xs font-semibold transition-all ${
                activeMode === 'visual'
                  ? 'bg-compass-panel text-compass-accent shadow-sm border border-compass font-bold'
                  : 'text-compass-muted hover:text-compass-primary'
              }`}
            >
              <Layers className="w-3.5 h-3.5" />
              <span>Visual Aggregation</span>
              <span className="text-[10px] px-1.5 py-0.2 rounded-full bg-compass-subtle border border-compass text-compass-muted">
                {visualStages.filter(s => s.enabled).length} stages
              </span>
            </button>

            {/* Type 2: Raw Aggregations (JSON Script) */}
            <button
              onClick={() => setActiveMode('raw')}
              className={`flex items-center gap-2 px-3.5 py-1.5 rounded text-xs font-semibold transition-all ${
                activeMode === 'raw'
                  ? 'bg-compass-panel text-compass-accent shadow-sm border border-compass font-bold'
                  : 'text-compass-muted hover:text-compass-primary'
              }`}
            >
              <Code2 className="w-3.5 h-3.5" />
              <span>Raw Aggregations</span>
              <span className="text-[10px] px-1.5 py-0.2 rounded-full bg-emerald-500/15 text-emerald-600 dark:text-[#00ED64] border border-emerald-500/30">
                JSON Script
              </span>
            </button>
          </div>
        </div>

        {/* Right: Presets, Conversion, Save As View & Export Actions */}
        <div className="flex items-center gap-2 flex-wrap">
          {/* Presets Dropdown */}
          <div className="relative">
            <select
              onChange={e => {
                const found = PRESET_PIPELINES.find(p => p.id === e.target.value);
                if (found) handleApplyPreset(found);
                e.target.value = '';
              }}
              defaultValue=""
              className="bg-compass-subtle text-xs text-compass-secondary hover:text-compass-primary border border-compass rounded px-2.5 py-1.5 focus:outline-none focus:border-emerald-500 cursor-pointer"
            >
              <option value="" disabled>
                Templates & Presets...
              </option>
              {PRESET_PIPELINES.map(p => (
                <option key={p.id} value={p.id}>
                  {p.name}
                </option>
              ))}
            </select>
          </div>

          {/* Mode-specific Two-Way Conversion Action Button */}
          {activeMode === 'visual' ? (
            <button
              onClick={handleConvertToRaw}
              title="Convert current visual stages to JSON script in Raw Aggregations mode"
              className="flex items-center gap-1.5 px-3 py-1.5 text-xs text-compass-secondary bg-compass-subtle hover:bg-compass-hover hover:text-compass-primary border border-compass rounded transition-colors"
            >
              <ArrowRightLeft className="w-3.5 h-3.5 text-compass-accent" />
              <span className="hidden sm:inline">Convert to</span> Raw Script
            </button>
          ) : (
            <button
              onClick={handleConvertToVisual}
              title="Parse this JSON script into visual stages in Visual Aggregation mode"
              className="flex items-center gap-1.5 px-3 py-1.5 text-xs text-compass-secondary bg-compass-subtle hover:bg-compass-hover hover:text-compass-primary border border-compass rounded transition-colors"
            >
              <ArrowRightLeft className="w-3.5 h-3.5 text-compass-accent" />
              <span className="hidden sm:inline">Convert to</span> Visual Pipeline
            </button>
          )}

          {/* Save as View Action Button */}
          <button
            onClick={() => setIsSaveViewModalOpen(true)}
            className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-semibold text-amber-600 dark:text-amber-400 bg-amber-500/10 hover:bg-amber-500/20 border border-amber-500/30 rounded transition-colors shadow-xs"
            title="Save current aggregation pipeline as a read-only MongoDB View"
          >
            <Eye className="w-3.5 h-3.5" />
            <span>Save as View</span>
          </button>

          {/* Export to Language Modal Trigger */}
          <button
            onClick={() => setIsExportModalOpen(true)}
            className="flex items-center gap-1.5 px-3 py-1.5 text-xs text-compass-secondary bg-compass-subtle hover:bg-compass-hover hover:text-compass-primary border border-compass rounded transition-colors"
          >
            <ExternalLink className="w-3.5 h-3.5 text-compass-accent" />
            <span>Export Code</span>
          </button>
        </div>
      </div>

      {/* ========================================================================= */}
      {/* TYPE 1: RAW AGGREGATIONS (JSON SCRIPT) VIEW                               */}
      {/* ========================================================================= */}
      {activeMode === 'raw' && (
        <div className="space-y-3">
          {/* Raw Aggregation Controls Bar */}
          <div className="bg-compass-panel border border-compass p-3 rounded-lg flex flex-col sm:flex-row sm:items-center justify-between gap-2.5 shadow-sm text-xs">
            <div className="flex items-center gap-2 flex-wrap">
              <span className="font-mono font-semibold text-compass-primary flex items-center gap-1.5">
                <FileJson className="w-4 h-4 text-compass-accent" />
                <span>db.{collName}.aggregate([ ... ])</span>
              </span>
              <span className="text-[11px] text-compass-muted">
                Write a valid JSON array of pipeline stage objects
              </span>
            </div>

            <div className="flex items-center gap-2 flex-wrap">
              {/* Auto Run Toggle */}
              <label className="flex items-center gap-1.5 text-compass-secondary cursor-pointer select-none">
                <input
                  type="checkbox"
                  checked={autoRunRaw}
                  onChange={e => setAutoRunRaw(e.target.checked)}
                  className="rounded accent-emerald-600 dark:accent-[#00ED64]"
                />
                <span>Auto-run</span>
              </label>

              {/* Format / Prettify Button */}
              <button
                onClick={handleFormatRawJson}
                title="Format JSON script with indentation"
                className="flex items-center gap-1 px-2.5 py-1.5 bg-compass-subtle hover:bg-compass-hover border border-compass text-compass-secondary hover:text-compass-primary rounded transition-colors"
              >
                <Sparkles className="w-3.5 h-3.5 text-compass-accent" />
                <span>Format JSON</span>
              </button>

              {/* Copy Script Button */}
              <button
                onClick={handleCopyRawScript}
                title="Copy script to clipboard"
                className="flex items-center gap-1 px-2.5 py-1.5 bg-compass-subtle hover:bg-compass-hover border border-compass text-compass-secondary hover:text-compass-primary rounded transition-colors"
              >
                {copiedScript ? <Check className="w-3.5 h-3.5 text-emerald-500" /> : <Copy className="w-3.5 h-3.5" />}
                <span>{copiedScript ? 'Copied' : 'Copy'}</span>
              </button>

              {/* Primary Run Button */}
              <button
                onClick={runRawPipeline}
                className="flex items-center gap-1.5 px-4 py-1.5 font-semibold bg-compass-accent rounded transition-colors shadow-sm"
              >
                <Play className="w-3.5 h-3.5 fill-current" />
                <span>Run Aggregation</span>
              </button>
            </div>
          </div>

          {/* Quick Stage Insertion Pills */}
          <div className="flex items-center gap-1.5 flex-wrap px-1 text-xs">
            <span className="text-compass-muted text-[11px] font-mono mr-1">Insert Stage:</span>
            {[
              '$match',
              '$group',
              '$sort',
              '$project',
              '$limit',
              '$skip',
              '$unwind',
              '$count',
              '$addFields',
              '$lookup',
              '$facet'
            ].map(op => (
              <button
                key={op}
                onClick={() => handleInsertRawSnippet(op)}
                className="px-2 py-0.5 text-[11px] font-mono bg-compass-subtle hover:bg-compass-hover text-compass-secondary hover:text-compass-accent border border-compass rounded transition-colors"
              >
                +{op}
              </button>
            ))}
          </div>

          {/* Raw Error Banner */}
          {rawError && (
            <div className="bg-rose-500/10 border border-rose-500/30 rounded-lg p-3 text-xs text-rose-500 dark:text-rose-300 flex items-start gap-2 animate-in fade-in">
              <AlertCircle className="w-4 h-4 text-rose-500 shrink-0 mt-0.5" />
              <div>
                <div className="font-semibold">Raw Aggregation Script Error</div>
                <div className="font-mono mt-0.5 break-all text-[11px]">{rawError}</div>
              </div>
            </div>
          )}

          {/* Code Editor Container */}
          <div className="bg-compass-panel border border-compass rounded-lg overflow-hidden shadow-sm">
            <div className="bg-compass-subtle px-3 py-2 border-b border-compass flex items-center justify-between text-xs text-compass-muted font-mono">
              <div className="flex items-center gap-2">
                <span>AGGREGATION SCRIPT (JSON)</span>
                <span className="text-[10px] px-1.5 py-0.5 rounded bg-compass-panel border border-compass">
                  {rawLineCount} lines
                </span>
              </div>
              <div className="text-[11px] text-compass-muted">
                Tip: Press <kbd className="px-1 py-0.5 bg-compass-panel rounded border border-compass">Ctrl</kbd> + <kbd className="px-1 py-0.5 bg-compass-panel rounded border border-compass">Enter</kbd> to execute
              </div>
            </div>

            <div className="relative flex min-h-[260px] font-mono text-xs">
              {/* Line Numbers Gutter */}
              <div
                aria-hidden="true"
                className="select-none py-3 px-2 bg-compass-subtle/50 text-compass-muted/40 text-right font-mono text-[11px] border-r border-compass min-w-[38px]"
              >
                {Array.from({ length: rawLineCount }).map((_, i) => (
                  <div key={i} className="leading-5">
                    {i + 1}
                  </div>
                ))}
              </div>

              {/* Textarea Code Input */}
              <textarea
                ref={rawTextareaRef}
                value={rawScript}
                onChange={e => setRawScript(e.target.value)}
                onKeyDown={e => {
                  if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
                    e.preventDefault();
                    runRawPipeline();
                  }
                }}
                spellCheck={false}
                rows={Math.max(14, rawLineCount)}
                className="w-full bg-compass-input text-compass-primary p-3 font-mono text-xs leading-5 border-none focus:outline-none custom-scrollbar resize-y whitespace-pre"
                placeholder={`[\n  {\n    "$match": { "year": { "$gte": 1990 } }\n  },\n  {\n    "$group": { "_id": "$year", "count": { "$sum": 1 } }\n  }\n]`}
              />
            </div>
          </div>
        </div>
      )}

      {/* ========================================================================= */}
      {/* TYPE 2: VISUAL AGGREGATION (PIPELINE BUILDER) VIEW                        */}
      {/* ========================================================================= */}
      {activeMode === 'visual' && (
        <div className="space-y-3">
          {/* Visual Pipeline Controls Bar */}
          <div className="bg-compass-panel border border-compass p-3.5 rounded-lg flex flex-col sm:flex-row sm:items-center justify-between gap-3 shadow-sm">
            <div className="flex items-center gap-2 flex-wrap">
              <Layers className="w-4 h-4 text-compass-accent shrink-0" />
              <span className="text-sm font-semibold text-compass-primary">Visual Pipeline Stages</span>
              <span className="text-xs text-compass-muted font-mono">
                ({visualStages.filter(s => s.enabled).length} of {visualStages.length} enabled)
              </span>
            </div>

            <div className="flex items-center gap-2 flex-wrap">
              {/* Add Stage Selector */}
              <div className="relative">
                <select
                  onChange={e => {
                    addVisualStage(e.target.value as any);
                    e.target.value = '';
                  }}
                  defaultValue=""
                  className="bg-compass-subtle text-xs text-compass-secondary hover:text-compass-primary border border-compass rounded px-2.5 py-1.5 focus:outline-none focus:border-emerald-500 cursor-pointer"
                >
                  <option value="" disabled>
                    + Add Specific Stage...
                  </option>
                  <option value="$match">$match (Filter)</option>
                  <option value="$group">$group (Aggregate)</option>
                  <option value="$sort">$sort (Order)</option>
                  <option value="$project">$project (Select fields)</option>
                  <option value="$limit">$limit (Cap count)</option>
                  <option value="$skip">$skip (Offset)</option>
                  <option value="$unwind">$unwind (Array split)</option>
                  <option value="$count">$count (Total)</option>
                  <option value="$addFields">$addFields (Calculate)</option>
                  <option value="$lookup">$lookup (Join collection)</option>
                  <option value="$facet">$facet (Multi-pipeline)</option>
                </select>
              </div>

              {/* Add Default Stage Button */}
              <button
                onClick={() => addVisualStage('$match')}
                className="flex items-center gap-1.5 px-3.5 py-1.5 text-xs font-semibold bg-compass-accent rounded transition-colors shadow-sm"
              >
                <Plus className="w-3.5 h-3.5" />
                <span>Add Stage</span>
              </button>
            </div>
          </div>

          {/* Visual Pipeline Error Notification */}
          {visualError && (
            <div className="bg-rose-500/10 border border-rose-500/30 rounded-lg p-3 text-xs text-rose-500 dark:text-rose-300 flex items-start gap-2 animate-in fade-in">
              <AlertCircle className="w-4 h-4 text-rose-500 shrink-0 mt-0.5" />
              <div>
                <div className="font-semibold">Pipeline Execution Error</div>
                <div className="font-mono mt-0.5 break-all text-[11px]">{visualError}</div>
              </div>
            </div>
          )}

          {/* Visual Pipeline Stages Cards List */}
          <div className="space-y-3">
            {visualStages.length === 0 ? (
              <div className="bg-compass-panel border border-dashed border-compass rounded-lg p-8 text-center text-xs text-compass-muted space-y-3">
                <Layers className="w-8 h-8 text-compass-muted mx-auto opacity-50" />
                <div>No stages defined in pipeline. Add a stage to begin aggregating documents.</div>
                <button
                  onClick={() => addVisualStage('$match')}
                  className="px-3.5 py-1.5 font-semibold bg-compass-accent rounded text-xs transition-colors"
                >
                  Add First Stage
                </button>
              </div>
            ) : (
              visualStages.map((stage, index) => {
                const preview = stagePreviews.find(p => p.stageIndex === index);

                return (
                  <div
                    key={stage.id}
                    className={`bg-compass-panel border rounded-lg overflow-hidden transition-all shadow-sm ${
                      stage.enabled ? 'border-compass' : 'border-compass/40 opacity-60'
                    }`}
                  >
                    {/* Stage Card Header */}
                    <div className="bg-compass-subtle px-3 py-2 border-b border-compass flex flex-wrap items-center justify-between gap-2 text-xs">
                      <div className="flex items-center gap-2 sm:gap-3 flex-wrap">
                        {/* Reorder Buttons */}
                        <div className="flex items-center gap-0.5 text-compass-muted">
                          <button
                            disabled={index === 0}
                            onClick={() => moveVisualStage(index, 'up')}
                            title="Move stage up"
                            className="p-1 hover:text-compass-primary disabled:opacity-30 disabled:hover:text-compass-muted rounded transition-colors"
                          >
                            <ChevronUp className="w-3.5 h-3.5" />
                          </button>
                          <button
                            disabled={index === visualStages.length - 1}
                            onClick={() => moveVisualStage(index, 'down')}
                            title="Move stage down"
                            className="p-1 hover:text-compass-primary disabled:opacity-30 disabled:hover:text-compass-muted rounded transition-colors"
                          >
                            <ChevronDown className="w-3.5 h-3.5" />
                          </button>
                        </div>

                        <span className="font-mono text-[11px] text-compass-muted font-semibold">
                          Stage {index + 1}
                        </span>

                        {/* Stage Operator Dropdown */}
                        <select
                          value={stage.operator}
                          onChange={e => updateVisualStage(stage.id, { operator: e.target.value as any })}
                          className="bg-compass-input text-xs font-mono font-bold text-compass-accent px-2.5 py-1 rounded border border-compass focus:outline-none focus:border-emerald-500"
                        >
                          <option value="$match">$match</option>
                          <option value="$group">$group</option>
                          <option value="$sort">$sort</option>
                          <option value="$project">$project</option>
                          <option value="$limit">$limit</option>
                          <option value="$skip">$skip</option>
                          <option value="$unwind">$unwind</option>
                          <option value="$count">$count</option>
                          <option value="$addFields">$addFields</option>
                          <option value="$lookup">$lookup</option>
                          <option value="$facet">$facet</option>
                        </select>

                        {preview && (
                          <span className="text-[11px] text-compass-muted font-mono">
                            Output: <strong className="text-compass-primary">{preview.count}</strong> docs
                          </span>
                        )}
                      </div>

                      {/* Stage Card Right Actions */}
                      <div className="flex items-center gap-2 ml-auto sm:ml-0">
                        {/* Format Stage JSON */}
                        <button
                          onClick={() => formatVisualStageContent(stage.id)}
                          title="Format this stage JSON"
                          className="p-1 hover:text-compass-accent text-compass-muted hover:bg-compass-hover rounded transition-colors"
                        >
                          <Sparkles className="w-3.5 h-3.5" />
                        </button>

                        {/* Duplicate Stage */}
                        <button
                          onClick={() => duplicateVisualStage(stage)}
                          title="Duplicate this stage"
                          className="p-1 hover:text-compass-primary text-compass-muted hover:bg-compass-hover rounded transition-colors"
                        >
                          <Copy className="w-3.5 h-3.5" />
                        </button>

                        {/* Enabled Checkbox */}
                        <label className="flex items-center gap-1.5 text-[11px] text-compass-secondary cursor-pointer select-none">
                          <input
                            type="checkbox"
                            checked={stage.enabled}
                            onChange={e => updateVisualStage(stage.id, { enabled: e.target.checked })}
                            className="rounded accent-emerald-600 dark:accent-[#00ED64]"
                          />
                          <span>Enabled</span>
                        </label>

                        {/* Remove Stage */}
                        <button
                          onClick={() => removeVisualStage(stage.id)}
                          title="Delete Stage"
                          className="p-1 hover:text-rose-500 text-compass-muted hover:bg-compass-hover rounded transition-colors"
                        >
                          <Trash2 className="w-3.5 h-3.5" />
                        </button>
                      </div>
                    </div>

                    {/* Stage Card Body */}
                    <div className="p-3 grid grid-cols-1 lg:grid-cols-2 gap-3 text-xs">
                      {/* Left: Stage JSON Editor */}
                      <div>
                        <div className="text-[11px] font-mono text-compass-muted mb-1.5 flex items-center justify-between">
                          <span>STAGE DEFINITION (JSON)</span>
                        </div>
                        <textarea
                          value={stage.content}
                          onChange={e => updateVisualStage(stage.id, { content: e.target.value })}
                          rows={6}
                          className="w-full bg-compass-input text-compass-primary font-mono text-xs p-2.5 rounded border border-compass focus:outline-none focus:border-emerald-500 custom-scrollbar"
                        />
                      </div>

                      {/* Right: Stage Sample Output */}
                      <div>
                        <div className="text-[11px] font-mono text-compass-muted mb-1.5 flex items-center justify-between">
                          <span>STAGE SAMPLE OUTPUT ({preview?.count ?? 0} docs)</span>
                        </div>
                        <div className="bg-compass-input text-xs font-mono p-2.5 rounded border border-compass h-[126px] overflow-y-auto custom-scrollbar">
                          {preview && preview.sample.length > 0 ? (
                            <pre className="text-compass-secondary whitespace-pre-wrap break-all text-[11px]">
                              {JSON.stringify(preview.sample[0], null, 2)}
                            </pre>
                          ) : (
                            <span className="text-compass-muted italic text-[11px]">
                              No documents produced by this stage
                            </span>
                          )}
                        </div>
                      </div>
                    </div>
                  </div>
                );
              })
            )}
          </div>
        </div>
      )}

      {/* ========================================================================= */}
      {/* COMMON RESULTS PANEL: EXPLORE PIPELINE RESULTS                            */}
      {/* ========================================================================= */}
      <div className="bg-compass-panel border border-compass rounded-lg p-4 shadow-sm space-y-3">
        {/* Results Header */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-3 border-b border-compass">
          <div className="flex items-center gap-2.5 flex-wrap">
            <CheckCircle2 className="w-4 h-4 text-compass-accent shrink-0" />
            <h3 className="text-xs font-semibold uppercase tracking-wider text-compass-primary">
              Pipeline Results
            </h3>
            <span className="text-xs text-compass-muted font-mono">
              ({currentActiveResults.length} documents in {currentExecutionTime} ms)
            </span>
            <span className="text-[10px] px-1.5 py-0.5 rounded bg-compass-subtle border border-compass text-compass-muted font-mono">
              Mode: {activeMode === 'visual' ? 'Visual Builder' : 'Raw Script'}
            </span>
          </div>

          <div className="flex items-center gap-2 flex-wrap">
            {/* Filter in Results */}
            <div className="relative">
              <Search className="w-3.5 h-3.5 absolute left-2 top-2 text-compass-muted" />
              <input
                type="text"
                placeholder="Filter results..."
                value={resultFilterTerm}
                onChange={e => setResultFilterTerm(e.target.value)}
                className="pl-7 pr-2.5 py-1 text-xs bg-compass-input text-compass-primary border border-compass rounded focus:outline-none focus:border-emerald-500 w-36 sm:w-44"
              />
            </div>

            {/* View Mode Switcher: JSON / Table / Tree */}
            <div className="bg-compass-subtle p-0.5 rounded border border-compass flex items-center">
              <button
                onClick={() => setResultViewMode('json')}
                title="JSON View"
                className={`p-1 rounded text-xs transition-colors ${
                  resultViewMode === 'json'
                    ? 'bg-compass-panel text-compass-accent shadow-xs'
                    : 'text-compass-muted hover:text-compass-primary'
                }`}
              >
                <FileJson className="w-3.5 h-3.5" />
              </button>
              <button
                onClick={() => setResultViewMode('table')}
                title="Table View"
                className={`p-1 rounded text-xs transition-colors ${
                  resultViewMode === 'table'
                    ? 'bg-compass-panel text-compass-accent shadow-xs'
                    : 'text-compass-muted hover:text-compass-primary'
                }`}
              >
                <TableIcon className="w-3.5 h-3.5" />
              </button>
              <button
                onClick={() => setResultViewMode('tree')}
                title="Tree View"
                className={`p-1 rounded text-xs transition-colors ${
                  resultViewMode === 'tree'
                    ? 'bg-compass-panel text-compass-accent shadow-xs'
                    : 'text-compass-muted hover:text-compass-primary'
                }`}
              >
                <FolderTree className="w-3.5 h-3.5" />
              </button>
            </div>

            {/* Copy Results */}
            <button
              onClick={handleCopyResults}
              title="Copy output documents as JSON"
              className="p-1.5 text-compass-secondary hover:text-compass-primary bg-compass-subtle hover:bg-compass-hover border border-compass rounded transition-colors"
            >
              {copiedResults ? <Check className="w-3.5 h-3.5 text-emerald-500" /> : <Copy className="w-3.5 h-3.5" />}
            </button>

            {/* Download Results */}
            <button
              onClick={handleDownloadResults}
              title="Download results as JSON file"
              className="p-1.5 text-compass-secondary hover:text-compass-primary bg-compass-subtle hover:bg-compass-hover border border-compass rounded transition-colors"
            >
              <Download className="w-3.5 h-3.5" />
            </button>
          </div>
        </div>

        {/* Results Body */}
        {filteredResults.length === 0 ? (
          <div className="text-center py-8 text-compass-muted italic text-xs bg-compass-input/40 border border-compass rounded">
            {currentActiveResults.length === 0
              ? 'Pipeline returned 0 documents'
              : 'No documents match the filter criteria'}
          </div>
        ) : resultViewMode === 'json' ? (
          /* JSON View */
          <div className="bg-compass-input border border-compass rounded p-3 max-h-[340px] overflow-y-auto custom-scrollbar font-mono text-xs">
            <pre className="text-compass-secondary whitespace-pre-wrap break-all leading-relaxed">
              {JSON.stringify(filteredResults, null, 2)}
            </pre>
          </div>
        ) : resultViewMode === 'table' ? (
          /* Table View */
          <div className="bg-compass-input border border-compass rounded max-h-[340px] overflow-auto custom-scrollbar font-mono text-xs">
            <table className="w-full text-left border-collapse text-xs">
              <thead className="bg-compass-subtle sticky top-0 border-b border-compass text-[11px] text-compass-muted">
                <tr>
                  <th className="p-2 border-r border-compass w-12 text-center">#</th>
                  {tableColumns.map(col => (
                    <th key={col} className="p-2 border-r border-compass font-semibold text-compass-primary whitespace-nowrap">
                      {col}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {filteredResults.map((doc, idx) => (
                  <tr key={doc._id || idx} className="border-b border-compass/40 hover:bg-compass-hover/50">
                    <td className="p-2 border-r border-compass text-center text-compass-muted text-[11px]">
                      {idx + 1}
                    </td>
                    {tableColumns.map(col => {
                      const val = doc[col];
                      const displayVal = val === undefined
                        ? '—'
                        : typeof val === 'object' && val !== null
                        ? JSON.stringify(val)
                        : String(val);
                      return (
                        <td
                          key={col}
                          className="p-2 border-r border-compass whitespace-nowrap overflow-hidden text-ellipsis max-w-[240px] text-compass-secondary"
                        >
                          {displayVal}
                        </td>
                      );
                    })}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          /* Tree View */
          <div className="bg-compass-input border border-compass rounded p-3 max-h-[340px] overflow-y-auto custom-scrollbar font-mono text-xs space-y-2">
            {filteredResults.map((doc, idx) => (
              <details key={doc._id || idx} className="group border border-compass/60 rounded bg-compass-panel/60 p-2">
                <summary className="cursor-pointer select-none font-semibold text-compass-accent flex items-center gap-2">
                  <span className="text-compass-muted text-[11px]">#{idx + 1}</span>
                  <span>Document {doc._id ? `[${doc._id}]` : ''}</span>
                  <span className="text-[10px] text-compass-muted font-normal ml-auto">
                    {Object.keys(doc).length} fields
                  </span>
                </summary>
                <div className="mt-2 pl-3 border-l border-compass space-y-1 text-xs">
                  {Object.entries(doc).map(([k, v]) => (
                    <div key={k} className="flex items-start gap-2 py-0.5">
                      <span className="text-compass-primary font-semibold">{k}:</span>
                      <span className="text-compass-secondary break-all">
                        {typeof v === 'object' && v !== null ? JSON.stringify(v, null, 1) : String(v)}
                      </span>
                    </div>
                  ))}
                </div>
              </details>
            ))}
          </div>
        )}
      </div>

      {/* ========================================================================= */}
      {/* EXPORT PIPELINE CODE MODAL                                                */}
      {/* ========================================================================= */}
      {isExportModalOpen && (
        <div className="fixed inset-0 bg-black/60 flex items-center justify-center p-3 sm:p-4 z-50 animate-in fade-in select-none">
          <div className="bg-compass-panel border border-compass rounded-xl max-w-2xl w-full p-4 sm:p-5 space-y-4 shadow-2xl flex flex-col max-h-[90vh]">
            {/* Header */}
            <div className="flex items-center justify-between pb-3 border-b border-compass">
              <div className="flex items-center gap-2">
                <Code2 className="w-4 h-4 text-compass-accent shrink-0" />
                <h2 className="text-sm font-semibold text-compass-primary">
                  Export Aggregation Pipeline
                </h2>
              </div>
              <button
                onClick={() => setIsExportModalOpen(false)}
                className="text-compass-muted hover:text-compass-primary transition-colors text-xs font-semibold px-2 py-1 rounded hover:bg-compass-hover"
              >
                Close
              </button>
            </div>

            {/* Language Selection Tabs */}
            <div className="flex items-center gap-1.5 overflow-x-auto pb-1 text-xs custom-scrollbar">
              {(
                [
                  { id: 'node', label: 'Node.js' },
                  { id: 'python', label: 'Python (PyMongo)' },
                  { id: 'mongosh', label: 'Mongo Shell (mongosh)' },
                  { id: 'csharp', label: 'C# (.NET)' },
                  { id: 'java', label: 'Java' }
                ] as const
              ).map(lang => (
                <button
                  key={lang.id}
                  onClick={() => setExportLang(lang.id)}
                  className={`px-3 py-1.5 rounded font-medium whitespace-nowrap transition-colors ${
                    exportLang === lang.id
                      ? 'bg-compass-accent font-semibold shadow-xs'
                      : 'bg-compass-subtle text-compass-secondary hover:text-compass-primary border border-compass'
                  }`}
                >
                  {lang.label}
                </button>
              ))}
            </div>

            {/* Code Output Box */}
            <div className="relative flex-1 min-h-[220px] max-h-[360px] bg-compass-input border border-compass rounded-lg p-3 overflow-auto custom-scrollbar font-mono text-xs">
              <pre className="text-compass-secondary whitespace-pre-wrap break-all leading-relaxed">
                {exportGeneratedCode}
              </pre>
            </div>

            {/* Actions Footer */}
            <div className="flex items-center justify-between pt-2 border-t border-compass text-xs">
              <span className="text-compass-muted font-mono text-[11px]">
                Target: {dbName}.{collName}
              </span>
              <button
                onClick={handleCopyExportCode}
                className="flex items-center gap-1.5 px-4 py-2 font-semibold bg-compass-accent rounded transition-colors"
              >
                {copiedExportCode ? <Check className="w-4 h-4 text-emerald-500" /> : <Copy className="w-4 h-4" />}
                <span>{copiedExportCode ? 'Copied to Clipboard' : 'Copy Code'}</span>
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Save as View Modal */}
      <SaveViewModal
        isOpen={isSaveViewModalOpen}
        onClose={() => setIsSaveViewModalOpen(false)}
        dbName={dbName}
        sourceCollName={currentColl?.isView && currentColl.viewOn ? currentColl.viewOn : collName}
        pipeline={currentPipelineArray}
        pipelineJsonString={currentPipelineJsonString}
        onViewSaved={(newViewName) => {
          showToast(`Saved view "${newViewName}" successfully!`, 'success');
          onViewCreated?.(newViewName);
        }}
      />
    </div>
  );
};
