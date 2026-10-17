import React, { useEffect, useState, useRef } from 'react';
import { createPortal } from 'react-dom';
import {
  AlertTriangle,
  Database,
  Table2,
  Terminal,
  ShieldAlert,
  X,
  CheckCircle2,
  ShieldCheck,
  Check
} from 'lucide-react';

export interface RiskyOperationDetails {
  type: 'dropDatabase' | 'dropCollection' | 'deleteMany' | 'deleteOne' | 'updateMany' | 'updateOne';
  title: string;
  command: string;
  dbName: string;
  collName?: string;
  description: string;
  impact: string;
  filterPreview?: string;
  updatePreview?: string;
}

interface MongoshConfirmationModalProps {
  isOpen: boolean;
  operation: RiskyOperationDetails | null;
  onConfirm: () => void;
  onCancel: () => void;
}

export const MongoshConfirmationModal: React.FC<MongoshConfirmationModalProps> = ({
  isOpen,
  operation,
  onConfirm,
  onCancel
}) => {
  // Explicitly tracked selection state: default to safe 'cancel'
  const [selectedAction, setSelectedAction] = useState<'cancel' | 'confirm'>('cancel');
  
  // Guard confirming too fast (only for destructive confirm action, never for cancel)
  const [canConfirmDestructive, setCanConfirmDestructive] = useState(false);

  const cancelBtnRef = useRef<HTMLButtonElement>(null);
  const confirmBtnRef = useRef<HTMLButtonElement>(null);
  const modalContainerRef = useRef<HTMLDivElement>(null);

  // Reset state whenever modal opens
  useEffect(() => {
    if (!isOpen) {
      setSelectedAction('cancel');
      setCanConfirmDestructive(false);
      return;
    }

    setSelectedAction('cancel');
    setCanConfirmDestructive(false);

    // Focus safe Cancel button
    const focusTimer = setTimeout(() => {
      cancelBtnRef.current?.focus();
    }, 40);

    // Require small 200ms debounce before Enter can confirm a destructive action
    const confirmTimer = setTimeout(() => {
      setCanConfirmDestructive(true);
    }, 200);

    return () => {
      clearTimeout(focusTimer);
      clearTimeout(confirmTimer);
    };
  }, [isOpen]);

  // Sync button focus when selection state changes
  useEffect(() => {
    if (!isOpen) return;
    if (selectedAction === 'cancel') {
      cancelBtnRef.current?.focus();
    } else {
      confirmBtnRef.current?.focus();
    }
  }, [selectedAction, isOpen]);

  // Comprehensive keyboard handling
  useEffect(() => {
    if (!isOpen) return;

    const handleKeyDown = (e: KeyboardEvent) => {
      // 1. Escape always cancels immediately
      if (e.key === 'Escape') {
        e.preventDefault();
        e.stopPropagation();
        onCancel();
        return;
      }

      // 2. Direct hotkey shortcuts: 'c' or 'C' or 'n' or 'N' cancels immediately
      if (e.key === 'c' || e.key === 'C' || e.key === 'n' || e.key === 'N') {
        e.preventDefault();
        e.stopPropagation();
        onCancel();
        return;
      }

      // 3. 'y' or 'Y' selects Confirm
      if (e.key === 'y' || e.key === 'Y') {
        e.preventDefault();
        e.stopPropagation();
        setSelectedAction('confirm');
        return;
      }

      // 4. Arrow keys switch between Cancel and Confirm
      if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') {
        e.preventDefault();
        e.stopPropagation();
        setSelectedAction('cancel');
        cancelBtnRef.current?.focus();
        return;
      }

      if (e.key === 'ArrowRight' || e.key === 'ArrowDown') {
        e.preventDefault();
        e.stopPropagation();
        setSelectedAction('confirm');
        confirmBtnRef.current?.focus();
        return;
      }

      // 5. Tab / Shift+Tab toggles selection and traps focus
      if (e.key === 'Tab') {
        e.preventDefault();
        e.stopPropagation();
        setSelectedAction(prev => {
          const next = prev === 'cancel' ? 'confirm' : 'cancel';
          if (next === 'cancel') {
            cancelBtnRef.current?.focus();
          } else {
            confirmBtnRef.current?.focus();
          }
          return next;
        });
        return;
      }

      // 6. Enter key executes current selection
      if (e.key === 'Enter') {
        e.preventDefault();
        e.stopPropagation();

        if (selectedAction === 'cancel') {
          // Cancel is always instant, 100% safe
          onCancel();
          return;
        }

        if (selectedAction === 'confirm') {
          if (!canConfirmDestructive) return;
          onConfirm();
          return;
        }

        // Default safe fallback: cancel
        onCancel();
      }

      // 7. Space key executes current selection
      if (e.key === ' ') {
        e.preventDefault();
        e.stopPropagation();
        if (selectedAction === 'cancel') {
          onCancel();
        } else if (canConfirmDestructive) {
          onConfirm();
        }
      }
    };

    window.addEventListener('keydown', handleKeyDown, true);
    return () => window.removeEventListener('keydown', handleKeyDown, true);
  }, [isOpen, selectedAction, canConfirmDestructive, onConfirm, onCancel]);

  if (!isOpen || !operation) return null;

  const isDestructive =
    operation.type === 'dropDatabase' ||
    operation.type === 'dropCollection' ||
    operation.type === 'deleteMany' ||
    operation.type === 'deleteOne';

  const badgeColor =
    operation.type === 'dropDatabase' || operation.type === 'dropCollection'
      ? 'bg-rose-500/20 text-rose-400 border-rose-500/40'
      : isDestructive
      ? 'bg-red-500/20 text-red-400 border-red-500/40'
      : 'bg-amber-500/20 text-amber-400 border-amber-500/40';

  const typeLabel = {
    dropDatabase: 'DROP DATABASE',
    dropCollection: 'DROP COLLECTION',
    deleteMany: 'DELETE MANY',
    deleteOne: 'DELETE ONE',
    updateMany: 'UPDATE MANY',
    updateOne: 'UPDATE ONE'
  }[operation.type];

  return createPortal(
    <div
      onClick={onCancel}
      className="fixed inset-0 bg-black/80 backdrop-blur-xs flex items-center justify-center p-3 sm:p-4 z-50 animate-in fade-in select-none cursor-pointer"
      role="dialog"
      aria-modal="true"
      aria-labelledby="risky-op-title"
    >
      <div
        ref={modalContainerRef}
        onClick={e => e.stopPropagation()}
        className="bg-[#12181F] border border-compass rounded-xl max-w-lg w-full p-4 sm:p-5 space-y-4 shadow-2xl overflow-hidden text-slate-100 cursor-default"
      >
        {/* Header */}
        <div className="flex items-start justify-between pb-3 border-b border-[#21313C]">
          <div className="flex items-center gap-3">
            <div
              className={`p-2.5 rounded-lg border ${
                isDestructive
                  ? 'bg-rose-500/10 text-rose-400 border-rose-500/30'
                  : 'bg-amber-500/10 text-amber-400 border-amber-500/30'
              }`}
            >
              <AlertTriangle className="w-5 h-5" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h3
                  id="risky-op-title"
                  className="text-sm sm:text-base font-bold text-white font-sans"
                >
                  Risky Database Operation
                </h3>
                <span
                  className={`text-[10px] font-mono font-bold px-1.5 py-0.5 rounded border ${badgeColor}`}
                >
                  {typeLabel}
                </span>
              </div>
              <p className="text-[11px] text-slate-400 mt-0.5">
                mongosh requested execution of a data-altering command
              </p>
            </div>
          </div>
          <button
            onClick={onCancel}
            type="button"
            className="p-1 text-slate-400 hover:text-white hover:bg-[#1E293B] rounded transition-colors cursor-pointer"
            title="Cancel (Esc)"
            aria-label="Close dialog"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Target Context Strip */}
        <div className="grid grid-cols-2 gap-2 text-xs">
          <div className="p-2.5 rounded-lg bg-[#0A0E13] border border-[#21313C] flex items-center gap-2">
            <Database className="w-4 h-4 text-compass-accent shrink-0" />
            <div className="truncate">
              <span className="text-[10px] text-slate-400 block uppercase tracking-wider font-semibold">
                Database
              </span>
              <span className="font-mono text-xs font-semibold text-white truncate">
                {operation.dbName}
              </span>
            </div>
          </div>

          <div className="p-2.5 rounded-lg bg-[#0A0E13] border border-[#21313C] flex items-center gap-2">
            <Table2 className="w-4 h-4 text-compass-accent shrink-0" />
            <div className="truncate">
              <span className="text-[10px] text-slate-400 block uppercase tracking-wider font-semibold">
                Target
              </span>
              <span className="font-mono text-xs font-semibold text-white truncate">
                {operation.collName || '(All collections in DB)'}
              </span>
            </div>
          </div>
        </div>

        {/* Command Terminal Preview */}
        <div>
          <label className="block text-[11px] font-mono text-slate-400 uppercase tracking-wider font-semibold mb-1.5 flex items-center gap-1.5">
            <Terminal className="w-3.5 h-3.5 text-compass-accent" />
            <span>Command to execute</span>
          </label>
          <div className="p-3 rounded-lg bg-[#080B0E] border border-[#283946] font-mono text-xs text-amber-300 break-all overflow-x-auto custom-scrollbar select-text">
            <code>{operation.command}</code>
          </div>
        </div>

        {/* Warning Callout Box */}
        <div
          className={`p-3 rounded-lg border text-xs space-y-1.5 ${
            isDestructive
              ? 'bg-rose-950/20 border-rose-500/30 text-rose-200'
              : 'bg-amber-950/20 border-amber-500/30 text-amber-200'
          }`}
        >
          <div className="flex items-center gap-1.5 font-semibold">
            <ShieldAlert className="w-4 h-4 shrink-0" />
            <span>{operation.description}</span>
          </div>
          <p className="text-[11px] opacity-90 pl-5.5">{operation.impact}</p>
        </div>

        {/* Interactive Selection Cards */}
        <div className="space-y-2">
          <label className="block text-[11px] font-mono text-slate-400 uppercase tracking-wider font-semibold">
            Select Action:
          </label>

          {/* Option 1: Cancel Operation (Selected by default) */}
          <div
            onClick={() => {
              setSelectedAction('cancel');
              cancelBtnRef.current?.focus();
            }}
            onDoubleClick={onCancel}
            className={`p-3 rounded-lg border transition-all cursor-pointer flex items-center justify-between ${
              selectedAction === 'cancel'
                ? 'bg-emerald-950/30 border-emerald-500 ring-2 ring-emerald-500/30 text-white shadow-md'
                : 'bg-[#0E141B] border-[#21313C] text-slate-300 hover:border-slate-500 hover:bg-[#141C24]'
            }`}
          >
            <div className="flex items-center gap-3">
              <div
                className={`w-5 h-5 rounded-full border-2 flex items-center justify-center shrink-0 transition-colors ${
                  selectedAction === 'cancel'
                    ? 'border-emerald-400 bg-emerald-500 text-black'
                    : 'border-slate-500 bg-transparent'
                }`}
              >
                {selectedAction === 'cancel' && <Check className="w-3.5 h-3.5 stroke-[3]" />}
              </div>
              <div>
                <div className="flex items-center gap-2">
                  <span className="text-xs font-semibold text-white">
                    Cancel Operation
                  </span>
                  <span className="text-[10px] px-1.5 py-0.2 rounded font-mono font-bold bg-emerald-500/20 text-emerald-400 border border-emerald-500/30">
                    SAFE / RECOMMENDED
                  </span>
                </div>
                <p className="text-[11px] text-slate-400 mt-0.5">
                  Abort execution and keep all database records untouched.
                </p>
              </div>
            </div>
            <ShieldCheck className={`w-4 h-4 shrink-0 ${selectedAction === 'cancel' ? 'text-emerald-400' : 'text-slate-500'}`} />
          </div>

          {/* Option 2: Confirm & Execute */}
          <div
            onClick={() => {
              setSelectedAction('confirm');
              confirmBtnRef.current?.focus();
            }}
            onDoubleClick={() => {
              if (canConfirmDestructive) onConfirm();
            }}
            className={`p-3 rounded-lg border transition-all cursor-pointer flex items-center justify-between ${
              selectedAction === 'confirm'
                ? 'bg-rose-950/30 border-rose-500 ring-2 ring-rose-500/30 text-white shadow-md'
                : 'bg-[#0E141B] border-[#21313C] text-slate-300 hover:border-slate-500 hover:bg-[#141C24]'
            }`}
          >
            <div className="flex items-center gap-3">
              <div
                className={`w-5 h-5 rounded-full border-2 flex items-center justify-center shrink-0 transition-colors ${
                  selectedAction === 'confirm'
                    ? 'border-rose-400 bg-rose-500 text-white'
                    : 'border-slate-500 bg-transparent'
                }`}
              >
                {selectedAction === 'confirm' && <Check className="w-3.5 h-3.5 stroke-[3]" />}
              </div>
              <div>
                <div className="flex items-center gap-2">
                  <span className="text-xs font-semibold text-white">
                    Confirm & Execute Command
                  </span>
                  <span className="text-[10px] px-1.5 py-0.2 rounded font-mono font-bold bg-rose-500/20 text-rose-400 border border-rose-500/30">
                    IRREVERSIBLE
                  </span>
                </div>
                <p className="text-[11px] text-slate-400 mt-0.5">
                  Proceed with data modification or deletion.
                </p>
              </div>
            </div>
            <AlertTriangle className={`w-4 h-4 shrink-0 ${selectedAction === 'confirm' ? 'text-rose-400' : 'text-slate-500'}`} />
          </div>
        </div>

        {/* Action Buttons */}
        <div className="flex items-center justify-between pt-3 border-t border-[#21313C] gap-2">
          <div className="text-[11px] text-slate-400 hidden sm:flex items-center gap-1.5">
            <span className="text-slate-500">Shortcuts:</span>
            <kbd className="px-1.5 py-0.5 rounded bg-black/50 border border-slate-700 font-mono text-[10px] text-slate-300">Esc</kbd>
            <span className="text-slate-500">or</span>
            <kbd className="px-1.5 py-0.5 rounded bg-black/50 border border-slate-700 font-mono text-[10px] text-slate-300">N</kbd>
            <span className="text-slate-400 font-medium">Cancel</span>
            <span className="text-slate-600">|</span>
            <kbd className="px-1.5 py-0.5 rounded bg-black/50 border border-slate-700 font-mono text-[10px] text-slate-300">Tab</kbd>
            <kbd className="px-1.5 py-0.5 rounded bg-black/50 border border-slate-700 font-mono text-[10px] text-slate-300">← →</kbd>
            <span className="text-slate-400 font-medium">Toggle</span>
          </div>

          <div className="flex items-center gap-2.5 w-full sm:w-auto justify-end">
            {/* Cancel Button */}
            <button
              ref={cancelBtnRef}
              type="button"
              tabIndex={0}
              onClick={e => {
                e.stopPropagation();
                onCancel();
              }}
              onFocus={() => setSelectedAction('cancel')}
              className={`flex-1 sm:flex-initial px-4 py-2.5 rounded-lg text-xs font-semibold transition-all cursor-pointer flex items-center justify-center gap-2 shadow-sm ${
                selectedAction === 'cancel'
                  ? 'bg-emerald-600 hover:bg-emerald-500 text-white ring-2 ring-emerald-300 border-2 border-emerald-400 shadow-emerald-950/50 scale-102'
                  : 'bg-[#1A232C] hover:bg-[#22303D] text-slate-200 border-2 border-slate-600 hover:border-slate-400'
              }`}
            >
              <CheckCircle2 className="w-4 h-4 text-emerald-200" />
              <span>Cancel Operation</span>
              <span className="text-[10px] opacity-75 font-mono">(Esc / N)</span>
            </button>

            {/* Confirm Button */}
            <button
              ref={confirmBtnRef}
              type="button"
              tabIndex={0}
              onClick={e => {
                e.stopPropagation();
                onConfirm();
              }}
              onFocus={() => setSelectedAction('confirm')}
              className={`flex-1 sm:flex-initial px-4 py-2.5 rounded-lg text-xs font-semibold text-white transition-all shadow-md flex items-center justify-center gap-2 cursor-pointer ${
                selectedAction === 'confirm'
                  ? isDestructive
                    ? 'bg-rose-600 hover:bg-rose-500 ring-2 ring-white border-2 border-rose-400 shadow-rose-950/50 scale-102'
                    : 'bg-amber-600 hover:bg-amber-500 ring-2 ring-white border-2 border-amber-400 shadow-amber-950/50 scale-102'
                  : 'bg-[#2A151B] hover:bg-[#3D1E26] text-rose-300 border-2 border-rose-900/60'
              }`}
            >
              <AlertTriangle className="w-4 h-4" />
              <span>Confirm & Execute</span>
              <span className="text-[10px] opacity-75 font-mono">(Y)</span>
            </button>
          </div>
        </div>
      </div>
    </div>,
    document.body
  );
};
