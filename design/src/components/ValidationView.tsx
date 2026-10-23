import React, { useState } from 'react';
import { ShieldCheck, Check, AlertCircle, Save } from 'lucide-react';
import { MongoCollection } from '../types/mongo';

interface ValidationViewProps {
  collection: MongoCollection;
  onSaveValidator: (validator: Record<string, any>, level: string, action: string) => void;
}

export const ValidationView: React.FC<ValidationViewProps> = ({
  collection,
  onSaveValidator
}) => {
  const [schemaText, setSchemaText] = useState(
    JSON.stringify(
      collection.validator || {
        $jsonSchema: {
          bsonType: 'object',
          required: ['_id'],
          properties: {
            _id: { bsonType: 'string' }
          }
        }
      },
      null,
      2
    )
  );

  const [validationLevel, setValidationLevel] = useState(collection.validationLevel || 'moderate');
  const [validationAction, setValidationAction] = useState(collection.validationAction || 'error');
  const [statusMsg, setStatusMsg] = useState<{ text: string; isError: boolean } | null>(null);

  const handleSave = () => {
    try {
      const parsed = JSON.parse(schemaText);
      onSaveValidator(parsed, validationLevel, validationAction);
      setStatusMsg({ text: 'Validation rules saved successfully!', isError: false });
      setTimeout(() => setStatusMsg(null), 3000);
    } catch (err: any) {
      setStatusMsg({ text: `Invalid JSON Schema: ${err.message}`, isError: true });
    }
  };

  return (
    <div className="space-y-4">
      {/* Header */}
      <div className="bg-compass-panel border border-compass p-3.5 sm:p-4 rounded-lg flex flex-col sm:flex-row sm:items-center justify-between gap-3 shadow-sm">
        <div>
          <div className="flex items-center gap-2">
            <ShieldCheck className="w-4 h-4 text-compass-accent shrink-0" />
            <h3 className="text-sm font-semibold text-compass-primary">Document Validation</h3>
          </div>
          <p className="text-xs text-compass-muted mt-0.5">
            Specify JSON Schema validation rules to enforce document structure.
          </p>
        </div>

        <button
          onClick={handleSave}
          className="flex items-center gap-1.5 px-3.5 py-1.5 text-xs font-semibold bg-compass-accent rounded transition-colors shadow-sm self-start sm:self-auto"
        >
          <Save className="w-3.5 h-3.5" />
          <span>Save Rules</span>
        </button>
      </div>

      {statusMsg && (
        <div
          className={`p-3 rounded-lg text-xs flex items-center gap-2 ${
            statusMsg.isError
              ? 'bg-rose-500/10 border border-rose-500/30 text-rose-500 dark:text-rose-300'
              : 'bg-emerald-500/10 border border-emerald-500/30 text-emerald-700 dark:text-emerald-300'
          }`}
        >
          {statusMsg.isError ? (
            <AlertCircle className="w-4 h-4 shrink-0" />
          ) : (
            <Check className="w-4 h-4 shrink-0" />
          )}
          <span>{statusMsg.text}</span>
        </div>
      )}

      {/* Settings Row */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs bg-compass-panel border border-compass p-3.5 rounded-lg shadow-sm">
        <div>
          <label className="block text-compass-secondary font-medium mb-1">Validation Action</label>
          <select
            value={validationAction}
            onChange={e => setValidationAction(e.target.value as any)}
            className="w-full bg-compass-input text-compass-primary p-2 rounded border border-compass focus:outline-none focus:border-emerald-500"
          >
            <option value="error">error (Reject invalid documents)</option>
            <option value="warn">warn (Allow write but record warning)</option>
          </select>
        </div>

        <div>
          <label className="block text-compass-secondary font-medium mb-1">Validation Level</label>
          <select
            value={validationLevel}
            onChange={e => setValidationLevel(e.target.value as any)}
            className="w-full bg-compass-input text-compass-primary p-2 rounded border border-compass focus:outline-none focus:border-emerald-500"
          >
            <option value="strict">strict (Apply to all inserts and updates)</option>
            <option value="moderate">moderate (Apply to inserts and valid docs)</option>
            <option value="off">off (Disable validation)</option>
          </select>
        </div>
      </div>

      {/* JSON Schema Editor */}
      <div className="bg-compass-panel border border-compass rounded-lg p-4 space-y-2 shadow-sm">
        <div className="text-[11px] font-mono text-compass-muted flex items-center justify-between">
          <span>VALIDATION CRITERIA ($jsonSchema)</span>
        </div>
        <textarea
          value={schemaText}
          onChange={e => setSchemaText(e.target.value)}
          rows={14}
          className="w-full bg-compass-input text-compass-primary font-mono text-xs p-3 rounded border border-compass focus:outline-none focus:border-emerald-500 custom-scrollbar"
        />
      </div>
    </div>
  );
};
