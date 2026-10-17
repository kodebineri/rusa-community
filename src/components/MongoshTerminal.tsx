import React, { useState, useRef, useEffect } from 'react';
import {
  Terminal,
  Minimize2,
  Maximize2,
  X,
  Trash2,
  CornerDownLeft
} from 'lucide-react';
import { mongoEngine } from '../services/mongoEngine';
import {
  MongoshConfirmationModal,
  RiskyOperationDetails
} from './MongoshConfirmationModal';

interface MongoshTerminalProps {
  isOpen: boolean;
  onClose: () => void;
  activeDbName: string;
  onDbSwitched: (newDbName: string) => void;
  onDataChanged: () => void;
}

interface CommandHistoryItem {
  prompt: string;
  command: string;
  output: string;
  isError?: boolean;
}

// Split multiple arguments (e.g. filter and update) while respecting quotes and nested objects
function splitTopLevelArgs(argsStr: string): string[] {
  const args: string[] = [];
  let depth = 0;
  let inString: string | null = null;
  let current = '';

  for (let i = 0; i < argsStr.length; i++) {
    const ch = argsStr[i];
    const prev = i > 0 ? argsStr[i - 1] : '';

    if (inString) {
      current += ch;
      if (ch === inString && prev !== '\\') {
        inString = null;
      }
    } else {
      if (ch === '"' || ch === "'") {
        inString = ch;
        current += ch;
      } else if (ch === '{' || ch === '[') {
        depth++;
        current += ch;
      } else if (ch === '}' || ch === ']') {
        depth--;
        current += ch;
      } else if (ch === ',' && depth === 0) {
        args.push(current.trim());
        current = '';
      } else {
        current += ch;
      }
    }
  }
  if (current.trim()) {
    args.push(current.trim());
  }
  return args;
}

export const MongoshTerminal: React.FC<MongoshTerminalProps> = ({
  isOpen,
  onClose,
  activeDbName,
  onDbSwitched,
  onDataChanged
}) => {
  const [currentDb, setCurrentDb] = useState(activeDbName || 'test');
  const [inputVal, setInputVal] = useState('');
  const [history, setHistory] = useState<CommandHistoryItem[]>([
    {
      prompt: 'mongosh',
      command: '',
      output: `Current Mongosh Log ID: ${mongoEngine.generateObjectId()}\nConnecting to: mongodb://127.0.0.1:27017/?directConnection=true&serverSelectionTimeoutMS=2000\nUsing MongoDB: 7.0.8\nUsing Mongosh: 2.2.0\nType "help" for a list of available commands.`
    }
  ]);
  const [cmdHistory, setCmdHistory] = useState<string[]>([]);
  const [historyIndex, setHistoryIndex] = useState<number>(-1);
  const [isExpanded, setIsExpanded] = useState(false);

  // Risky database operation confirmation state
  const [pendingRiskyOp, setPendingRiskyOp] = useState<{
    details: RiskyOperationDetails;
    execute: () => void;
    promptText: string;
  } | null>(null);

  const terminalEndRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (activeDbName) {
      setCurrentDb(activeDbName);
    }
  }, [activeDbName]);

  useEffect(() => {
    if (isOpen && !pendingRiskyOp) {
      setTimeout(() => inputRef.current?.focus(), 100);
      terminalEndRef.current?.scrollIntoView({ behavior: 'smooth' });
    }
  }, [isOpen, history, pendingRiskyOp]);

  if (!isOpen) return null;

  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      e.stopPropagation();
      executeCommand(inputVal);
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      if (cmdHistory.length === 0) return;
      const nextIndex = historyIndex < cmdHistory.length - 1 ? historyIndex + 1 : historyIndex;
      setHistoryIndex(nextIndex);
      setInputVal(cmdHistory[cmdHistory.length - 1 - nextIndex] || '');
    } else if (e.key === 'ArrowDown') {
      e.preventDefault();
      if (historyIndex > 0) {
        const nextIndex = historyIndex - 1;
        setHistoryIndex(nextIndex);
        setInputVal(cmdHistory[cmdHistory.length - 1 - nextIndex] || '');
      } else if (historyIndex === 0) {
        setHistoryIndex(-1);
        setInputVal('');
      }
    }
  };

  const handleCancelRiskyOp = () => {
    if (!pendingRiskyOp) return;
    setHistory(prev => [
      ...prev,
      {
        prompt: pendingRiskyOp.promptText,
        command: pendingRiskyOp.details.command,
        output: `Operation cancelled by user. No changes were made to database "${pendingRiskyOp.details.dbName}".`,
        isError: false
      }
    ]);
    setPendingRiskyOp(null);
    setTimeout(() => inputRef.current?.focus(), 50);
  };

  const handleConfirmRiskyOp = () => {
    if (!pendingRiskyOp) return;
    const op = pendingRiskyOp;
    setPendingRiskyOp(null);
    try {
      op.execute();
    } catch (err: any) {
      setHistory(prev => [
        ...prev,
        {
          prompt: op.promptText,
          command: op.details.command,
          output: `MongoServerError: ${err.message}`,
          isError: true
        }
      ]);
    }
    setTimeout(() => inputRef.current?.focus(), 50);
  };

  const executeCommand = (cmd: string) => {
    const trimmed = cmd.trim();
    if (!trimmed) return;

    setCmdHistory(prev => [...prev, trimmed]);
    setHistoryIndex(-1);
    setInputVal('');

    const promptText = `${currentDb}>`;

    // Clear
    if (trimmed === 'cls' || trimmed === 'clear') {
      setHistory([]);
      return;
    }

    // Help
    if (trimmed === 'help') {
      setHistory(prev => [
        ...prev,
        {
          prompt: promptText,
          command: trimmed,
          output: `MongoDB Shell Commands:
  show dbs / show databases               List databases
  show collections                        List collections in current database
  use <db>                                Switch current database
  db.<coll>.find([filter])                Find documents in collection
  db.<coll>.findOne([filter])             Find single document
  db.<coll>.insertOne(doc)                Insert document into collection
  db.<coll>.countDocuments()              Count total documents
  db.<coll>.updateMany(filter, update)    Update matching documents [Risky Confirmation]
  db.<coll>.updateOne(filter, update)     Update single document [Risky Confirmation]
  db.<coll>.deleteMany(filter)            Delete matching documents [Risky Confirmation]
  db.<coll>.deleteOne(filter)             Delete single document [Risky Confirmation]
  db.<coll>.drop()                        Drop collection [Risky Confirmation]
  db.dropDatabase()                       Drop current database [Risky Confirmation]
  db.<coll>.renameCollection(newName)     Rename collection
  db.<coll>.aggregate(pipeline)           Execute aggregation pipeline
  cls / clear                             Clear shell output`
        }
      ]);
      return;
    }

    // Show dbs
    if (trimmed === 'show dbs' || trimmed === 'show databases') {
      const dbs = mongoEngine.getDatabases();
      const output = dbs.map(d => `${d.name.padEnd(20)} 0.000GB`).join('\n');
      setHistory(prev => [...prev, { prompt: promptText, command: trimmed, output }]);
      return;
    }

    // Show collections
    if (trimmed === 'show collections' || trimmed === 'show tables') {
      const db = mongoEngine.getDatabase(currentDb);
      const cols = db ? Object.keys(db.collections) : [];
      setHistory(prev => [
        ...prev,
        {
          prompt: promptText,
          command: trimmed,
          output: cols.length ? cols.join('\n') : 'No collections in this database.'
        }
      ]);
      return;
    }

    // use <db>
    if (trimmed.startsWith('use ')) {
      const newDb = trimmed.slice(4).trim();
      setCurrentDb(newDb);
      onDbSwitched(newDb);
      setHistory(prev => [
        ...prev,
        {
          prompt: promptText,
          command: trimmed,
          output: `switched to db ${newDb}`
        }
      ]);
      return;
    }

    // 1. Direct db.dropDatabase() call
    const dbDirectMatch = trimmed.match(/^db\.([a-zA-Z0-9_]+)\((.*)\)$/s);
    if (dbDirectMatch && dbDirectMatch[1] === 'dropDatabase') {
      const details: RiskyOperationDetails = {
        type: 'dropDatabase',
        title: 'Drop Database',
        command: trimmed,
        dbName: currentDb,
        description: `Permanently delete database "${currentDb}" and all contained collections and documents.`,
        impact: `Irreversible destruction of "${currentDb}". All collections, indexes, and documents will be erased immediately.`
      };

      setPendingRiskyOp({
        details,
        promptText,
        execute: () => {
          const dbToDrop = currentDb;
          const ok = mongoEngine.dropDatabase(dbToDrop);
          if (!ok) {
            throw new Error(`Database "${dbToDrop}" could not be dropped.`);
          }
          onDataChanged();
          const remainingDbs = mongoEngine.getDatabases();
          const nextDb = remainingDbs[0]?.name || 'test';
          setCurrentDb(nextDb);
          onDbSwitched(nextDb);
          setHistory(prev => [
            ...prev,
            {
              prompt: promptText,
              command: trimmed,
              output: JSON.stringify({ ok: 1, dropped: dbToDrop }, null, 2)
            }
          ]);
        }
      });
      return;
    }

    // 2. db.getCollection('<coll>').<method>(...)
    const getCollMatch = trimmed.match(/^db\.getCollection\(['"]([^'"]+)['"]\)\.([a-zA-Z0-9_]+)\((.*)\)$/s);
    if (getCollMatch) {
      const [, collName, method, argsStr] = getCollMatch;
      handleDbMethod(collName, method, argsStr.trim(), promptText, trimmed);
      return;
    }

    // 3. Standard db.<coll>.<method>(...)
    const dbCallMatch = trimmed.match(/^db\.([a-zA-Z0-9_]+)\.([a-zA-Z0-9_]+)\((.*)\)$/s);
    if (dbCallMatch) {
      const [, collName, method, argsStr] = dbCallMatch;
      handleDbMethod(collName, method, argsStr.trim(), promptText, trimmed);
      return;
    }

    // Unrecognized command
    setHistory(prev => [
      ...prev,
      {
        prompt: promptText,
        command: trimmed,
        output: `ReferenceError: ${trimmed} is not defined. Type 'help' for mongosh commands.`,
        isError: true
      }
    ]);
  };

  const handleDbMethod = (
    collName: string,
    method: string,
    argsStr: string,
    promptText: string,
    fullCmd: string
  ) => {
    try {
      const coll = mongoEngine.getCollection(currentDb, collName);

      // --- Read & Inspection Operations (Safe, no confirmation required) ---
      if (method === 'find') {
        const filterStr = argsStr || '{}';
        const result = mongoEngine.findDocuments(currentDb, collName, {
          filter: filterStr,
          project: '',
          sort: '',
          skip: 0,
          limit: 20
        });
        setHistory(prev => [
          ...prev,
          {
            prompt: promptText,
            command: fullCmd,
            output: JSON.stringify(result.documents, null, 2)
          }
        ]);
        return;
      }

      if (method === 'findOne') {
        const filterStr = argsStr || '{}';
        const result = mongoEngine.findDocuments(currentDb, collName, {
          filter: filterStr,
          project: '',
          sort: '',
          skip: 0,
          limit: 1
        });
        setHistory(prev => [
          ...prev,
          {
            prompt: promptText,
            command: fullCmd,
            output: result.documents[0] ? JSON.stringify(result.documents[0], null, 2) : 'null'
          }
        ]);
        return;
      }

      if (method === 'countDocuments') {
        const count = coll ? coll.documents.length : 0;
        setHistory(prev => [
          ...prev,
          {
            prompt: promptText,
            command: fullCmd,
            output: String(count)
          }
        ]);
        return;
      }

      if (method === 'insertOne') {
        const parsed = JSON.parse(argsStr);
        const inserted = mongoEngine.insertDocument(currentDb, collName, parsed);
        onDataChanged();
        setHistory(prev => [
          ...prev,
          {
            prompt: promptText,
            command: fullCmd,
            output: `{\n  acknowledged: true,\n  insertedId: ObjectId('${inserted._id}')\n}`
          }
        ]);
        return;
      }

      if (method === 'aggregate') {
        const parsedPipeline = JSON.parse(argsStr);
        const stages = parsedPipeline.map((p: any, i: number) => {
          const op = Object.keys(p)[0] as any;
          return {
            id: String(i),
            operator: op,
            content: JSON.stringify(p[op]),
            enabled: true
          };
        });
        const res = mongoEngine.executeAggregation(currentDb, collName, stages);
        setHistory(prev => [
          ...prev,
          {
            prompt: promptText,
            command: fullCmd,
            output: JSON.stringify(res.documents, null, 2)
          }
        ]);
        return;
      }

      if (method === 'renameCollection') {
        const targetName = argsStr.replace(/^['"]|['"]$/g, '').trim();
        if (!targetName) {
          throw new Error('Target collection name is required: db.<coll>.renameCollection("newName")');
        }
        mongoEngine.renameCollection(currentDb, collName, targetName);
        onDataChanged();
        setHistory(prev => [
          ...prev,
          {
            prompt: promptText,
            command: fullCmd,
            output: `{ ok: 1 }`
          }
        ]);
        return;
      }

      // --- Risky Operations (Confirmation Popup Required) ---

      // 1. Drop Collection
      if (method === 'drop') {
        const details: RiskyOperationDetails = {
          type: 'dropCollection',
          title: 'Drop Collection',
          command: fullCmd,
          dbName: currentDb,
          collName,
          description: `Permanently delete collection "${collName}" and all associated documents and indexes.`,
          impact: `All ${coll?.documents.length ?? 0} documents in "${currentDb}.${collName}" will be erased.`
        };

        setPendingRiskyOp({
          details,
          promptText,
          execute: () => {
            const ok = mongoEngine.dropCollection(currentDb, collName);
            onDataChanged();
            setHistory(prev => [
              ...prev,
              {
                prompt: promptText,
                command: fullCmd,
                output: ok ? 'true' : 'false'
              }
            ]);
          }
        });
        return;
      }

      // 2. Delete Many / Remove
      if (method === 'deleteMany' || method === 'remove') {
        let filterObj: any = {};
        if (argsStr.trim()) {
          try {
            filterObj = JSON.parse(argsStr);
          } catch (e: any) {
            setHistory(prev => [
              ...prev,
              {
                prompt: promptText,
                command: fullCmd,
                output: `SyntaxError: Invalid filter JSON argument - ${e.message}`,
                isError: true
              }
            ]);
            return;
          }
        }

        const details: RiskyOperationDetails = {
          type: 'deleteMany',
          title: 'Delete Multiple Documents',
          command: fullCmd,
          dbName: currentDb,
          collName,
          description: `Permanently delete all documents matching the specified filter criteria from "${collName}".`,
          impact: `Matching records in "${currentDb}.${collName}" will be permanently erased.`
        };

        setPendingRiskyOp({
          details,
          promptText,
          execute: () => {
            const res = mongoEngine.deleteMany(currentDb, collName, filterObj);
            onDataChanged();
            setHistory(prev => [
              ...prev,
              {
                prompt: promptText,
                command: fullCmd,
                output: JSON.stringify(res, null, 2)
              }
            ]);
          }
        });
        return;
      }

      // 3. Delete One
      if (method === 'deleteOne') {
        let filterObj: any = {};
        if (argsStr.trim()) {
          try {
            filterObj = JSON.parse(argsStr);
          } catch (e: any) {
            setHistory(prev => [
              ...prev,
              {
                prompt: promptText,
                command: fullCmd,
                output: `SyntaxError: Invalid filter JSON argument - ${e.message}`,
                isError: true
              }
            ]);
            return;
          }
        }

        const details: RiskyOperationDetails = {
          type: 'deleteOne',
          title: 'Delete Single Document',
          command: fullCmd,
          dbName: currentDb,
          collName,
          description: `Permanently delete a single document matching the filter criteria from "${collName}".`,
          impact: `One matching document in "${currentDb}.${collName}" will be removed.`
        };

        setPendingRiskyOp({
          details,
          promptText,
          execute: () => {
            const res = mongoEngine.deleteOne(currentDb, collName, filterObj);
            onDataChanged();
            setHistory(prev => [
              ...prev,
              {
                prompt: promptText,
                command: fullCmd,
                output: JSON.stringify(res, null, 2)
              }
            ]);
          }
        });
        return;
      }

      // 4. Update Many
      if (method === 'updateMany') {
        const parts = splitTopLevelArgs(argsStr);
        let filterObj: any = {};
        let updateObj: any = {};
        try {
          if (!parts[0]) throw new Error('Filter argument missing');
          if (!parts[1]) throw new Error('Update argument missing: db.<coll>.updateMany(filter, update)');
          filterObj = JSON.parse(parts[0]);
          updateObj = JSON.parse(parts[1]);
        } catch (e: any) {
          setHistory(prev => [
            ...prev,
            {
              prompt: promptText,
              command: fullCmd,
              output: `SyntaxError: Invalid update argument - ${e.message}`,
              isError: true
            }
          ]);
          return;
        }

        const details: RiskyOperationDetails = {
          type: 'updateMany',
          title: 'Update Multiple Documents',
          command: fullCmd,
          dbName: currentDb,
          collName,
          description: `Modify all documents matching the filter criteria in "${collName}".`,
          impact: `Fields and values will be overwritten or added to matching documents in "${currentDb}.${collName}".`
        };

        setPendingRiskyOp({
          details,
          promptText,
          execute: () => {
            const res = mongoEngine.updateMany(currentDb, collName, filterObj, updateObj);
            onDataChanged();
            setHistory(prev => [
              ...prev,
              {
                prompt: promptText,
                command: fullCmd,
                output: JSON.stringify(res, null, 2)
              }
            ]);
          }
        });
        return;
      }

      // 5. Update One / Update
      if (method === 'updateOne' || method === 'update') {
        const parts = splitTopLevelArgs(argsStr);
        let filterObj: any = {};
        let updateObj: any = {};
        try {
          if (!parts[0]) throw new Error('Filter argument missing');
          if (!parts[1]) throw new Error('Update argument missing: db.<coll>.updateOne(filter, update)');
          filterObj = JSON.parse(parts[0]);
          updateObj = JSON.parse(parts[1]);
        } catch (e: any) {
          setHistory(prev => [
            ...prev,
            {
              prompt: promptText,
              command: fullCmd,
              output: `SyntaxError: Invalid update argument - ${e.message}`,
              isError: true
            }
          ]);
          return;
        }

        const details: RiskyOperationDetails = {
          type: 'updateOne',
          title: 'Update Single Document',
          command: fullCmd,
          dbName: currentDb,
          collName,
          description: `Modify a single document matching the filter criteria in "${collName}".`,
          impact: `Fields in the matching document in "${currentDb}.${collName}" will be modified.`
        };

        setPendingRiskyOp({
          details,
          promptText,
          execute: () => {
            const res = mongoEngine.updateOne(currentDb, collName, filterObj, updateObj);
            onDataChanged();
            setHistory(prev => [
              ...prev,
              {
                prompt: promptText,
                command: fullCmd,
                output: JSON.stringify(res, null, 2)
              }
            ]);
          }
        });
        return;
      }

      // Unrecognized method
      setHistory(prev => [
        ...prev,
        {
          prompt: promptText,
          command: fullCmd,
          output: `TypeError: db.${collName}.${method} is not a supported method. Type 'help' for available commands.`,
          isError: true
        }
      ]);
    } catch (err: any) {
      setHistory(prev => [
        ...prev,
        {
          prompt: promptText,
          command: fullCmd,
          output: `MongoServerError: ${err.message}`,
          isError: true
        }
      ]);
    }
  };

  return (
    <>
      <div
        className={`w-full shrink-0 bg-[#080B0E] border-t border-compass shadow-lg flex flex-col transition-all duration-200 z-20 ${
          isExpanded ? 'h-[65vh] sm:h-[70vh]' : 'h-60 sm:h-72'
        }`}
      >
        {/* Shell Header Bar */}
        <div className="h-9 bg-[#11161B] border-b border-[#21313C] px-3 flex items-center justify-between select-none shrink-0">
          <div className="flex items-center gap-2">
            <Terminal className="w-3.5 h-3.5 text-[#00ED64]" />
            <span className="text-xs font-mono font-bold text-slate-100">_mongosh</span>
            <span className="text-[11px] font-mono text-slate-400 hidden sm:inline">
              mongodb://127.0.0.1:27017 ({currentDb})
            </span>
          </div>

          <div className="flex items-center gap-1 sm:gap-1.5">
            <button
              onClick={() => setHistory([])}
              title="Clear output"
              className="p-1.5 hover:text-white text-slate-400 hover:bg-[#1E293B] rounded transition-colors"
            >
              <Trash2 className="w-3.5 h-3.5" />
            </button>
            <button
              onClick={() => setIsExpanded(!isExpanded)}
              title={isExpanded ? 'Restore size' : 'Maximize'}
              className="p-1.5 hover:text-white text-slate-400 hover:bg-[#1E293B] rounded transition-colors"
            >
              {isExpanded ? <Minimize2 className="w-3.5 h-3.5" /> : <Maximize2 className="w-3.5 h-3.5" />}
            </button>
            <button
              onClick={onClose}
              title="Close shell"
              className="p-1.5 hover:text-rose-400 text-slate-400 hover:bg-[#1E293B] rounded transition-colors"
            >
              <X className="w-3.5 h-3.5" />
            </button>
          </div>
        </div>

        {/* Terminal Output Area */}
        <div className="flex-1 p-3 overflow-y-auto font-mono text-xs space-y-2 select-text custom-scrollbar">
          {history.map((item, idx) => (
            <div key={idx} className="space-y-1">
              {item.command && (
                <div className="flex items-center gap-2 text-slate-400">
                  <span className="text-[#00ED64] font-semibold">{item.prompt}</span>
                  <span className="text-slate-100">{item.command}</span>
                </div>
              )}
              <div
                className={`whitespace-pre-wrap leading-relaxed break-all ${
                  item.isError ? 'text-rose-400' : 'text-[#A0AEC0]'
                }`}
              >
                {item.output}
              </div>
            </div>
          ))}
          <div ref={terminalEndRef} />
        </div>

        {/* Active Input Line */}
        <div className="p-2 sm:p-2.5 bg-[#080B0E] border-t border-[#21313C] flex items-center gap-2 font-mono text-xs shrink-0">
          <span className="text-[#00ED64] font-bold shrink-0">{currentDb}&gt;</span>
          <input
            ref={inputRef}
            type="text"
            disabled={!!pendingRiskyOp}
            value={inputVal}
            onChange={e => setInputVal(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder={
              pendingRiskyOp
                ? 'Select Cancel or Confirm in the confirmation popup...'
                : 'Try "help", "db.dropDatabase()", "db.movies.drop()", or "db.movies.deleteMany({ year: 1990 })"'
            }
            className={`flex-1 bg-transparent text-slate-100 outline-none placeholder-[#889397]/50 min-w-0 ${
              pendingRiskyOp ? 'opacity-40 cursor-not-allowed' : ''
            }`}
          />
          <button
            onClick={() => executeCommand(inputVal)}
            disabled={!!pendingRiskyOp}
            className={`p-1.5 rounded shrink-0 transition-colors ${
              pendingRiskyOp
                ? 'text-slate-600 cursor-not-allowed'
                : 'hover:text-[#00ED64] text-[#889397] hover:bg-[#162029] cursor-pointer'
            }`}
            title="Run command"
          >
            <CornerDownLeft className="w-3.5 h-3.5" />
          </button>
        </div>
      </div>

      {/* Confirmation Modal for Risky Operations */}
      <MongoshConfirmationModal
        isOpen={!!pendingRiskyOp}
        operation={pendingRiskyOp?.details || null}
        onConfirm={handleConfirmRiskyOp}
        onCancel={handleCancelRiskyOp}
      />
    </>
  );
};
