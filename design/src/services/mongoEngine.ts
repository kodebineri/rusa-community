import {
  ExplainPlanResult,
  MongoCollection,
  MongoDatabase,
  MongoDocument,
  MongoIndex,
  PipelineStage,
  QueryFilterOptions,
  SchemaFieldStat
} from '../types/mongo';
import { generateSampleDatabases } from './sampleData';

const STORAGE_KEY = 'compass_mongo_databases_v1';

export class MongoEngine {
  private databases: Record<string, MongoDatabase> = {};

  constructor() {
    this.loadFromStorage();
  }

  public loadFromStorage() {
    try {
      const stored = localStorage.getItem(STORAGE_KEY);
      if (stored) {
        this.databases = JSON.parse(stored);
        // Ensure default sample views exist if not present in saved databases
        const defaults = generateSampleDatabases();
        for (const [dbKey, defaultDb] of Object.entries(defaults)) {
          if (this.databases[dbKey]) {
            for (const [collKey, defaultColl] of Object.entries(defaultDb.collections)) {
              if (defaultColl.isView && !this.databases[dbKey].collections[collKey]) {
                this.databases[dbKey].collections[collKey] = defaultColl;
              }
            }
          }
        }
        this.populateAllViewDocuments();
      } else {
        this.resetToDefaults();
      }
    } catch {
      this.resetToDefaults();
    }
  }

  public saveToStorage() {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(this.databases));
    } catch (e) {
      console.warn('Failed to persist databases to localStorage', e);
    }
  }

  public resetToDefaults() {
    this.databases = generateSampleDatabases();
    this.populateAllViewDocuments();
    this.saveToStorage();
  }

  public populateAllViewDocuments() {
    for (const [dbName, db] of Object.entries(this.databases)) {
      for (const coll of Object.values(db.collections)) {
        if (coll.isView && coll.viewOn) {
          try {
            const res = this.executeRawAggregation(dbName, coll.viewOn, coll.pipeline || []);
            coll.documents = res.documents;
          } catch {
            // view computation deferred
          }
        }
      }
    }
  }

  public getDatabases(): MongoDatabase[] {
    return Object.values(this.databases);
  }

  public getDatabase(dbName: string): MongoDatabase | undefined {
    return this.databases[dbName];
  }

  public getCollection(dbName: string, collName: string): MongoCollection | undefined {
    const coll = this.databases[dbName]?.collections[collName];
    if (coll && coll.isView && coll.viewOn) {
      try {
        const res = this.executeRawAggregation(dbName, coll.viewOn, coll.pipeline || []);
        coll.documents = res.documents;
      } catch {
        // keep existing documents
      }
    }
    return coll;
  }

  public createDatabase(dbName: string, initialCollName = 'users'): boolean {
    if (this.databases[dbName]) return false;
    this.databases[dbName] = {
      name: dbName,
      collections: {
        [initialCollName]: {
          name: initialCollName,
          documents: [
            {
              _id: this.generateObjectId(),
              createdAt: new Date().toISOString(),
              name: 'Sample Item',
              active: true
            }
          ],
          indexes: [{ name: '_id_', keys: { _id: 1 }, sizeKb: 16 }]
        }
      }
    };
    this.saveToStorage();
    return true;
  }

  public dropDatabase(dbName: string): boolean {
    if (!this.databases[dbName]) return false;
    delete this.databases[dbName];
    this.saveToStorage();
    return true;
  }

  public createCollection(dbName: string, collName: string): boolean {
    const db = this.databases[dbName];
    if (!db || db.collections[collName]) return false;
    db.collections[collName] = {
      name: collName,
      documents: [],
      indexes: [{ name: '_id_', keys: { _id: 1 }, sizeKb: 16 }]
    };
    this.saveToStorage();
    return true;
  }

  public createView(
    dbName: string,
    viewName: string,
    sourceCollName: string,
    pipeline: any[] | string
  ): boolean {
    const db = this.databases[dbName];
    if (!db) throw new Error(`Database "${dbName}" not found`);
    const cleanViewName = viewName.trim();
    if (!cleanViewName) {
      throw new Error('View name cannot be empty');
    }
    if (cleanViewName.includes('$') || cleanViewName.startsWith('.')) {
      throw new Error('Invalid view name: cannot contain "$" or begin with "."');
    }
    if (db.collections[cleanViewName]) {
      throw new Error(`A collection or view named "${cleanViewName}" already exists in database "${dbName}"`);
    }
    const sourceColl = db.collections[sourceCollName];
    if (!sourceColl) {
      throw new Error(`Source collection "${sourceCollName}" does not exist in database "${dbName}"`);
    }

    let parsedPipeline: any[] = [];
    if (typeof pipeline === 'string') {
      parsedPipeline = this.parseAggregationScript(pipeline);
    } else if (Array.isArray(pipeline)) {
      parsedPipeline = pipeline;
    }

    // Execute aggregation to verify pipeline and calculate initial documents
    const aggResult = this.executeRawAggregation(dbName, sourceCollName, parsedPipeline);

    db.collections[cleanViewName] = {
      name: cleanViewName,
      isView: true,
      viewOn: sourceCollName,
      pipeline: parsedPipeline,
      documents: aggResult.documents,
      indexes: [{ name: '_id_', keys: { _id: 1 }, sizeKb: 0 }]
    };

    this.saveToStorage();
    return true;
  }

  public dropCollection(dbName: string, collName: string): boolean {
    const db = this.databases[dbName];
    if (!db || !db.collections[collName]) return false;
    delete db.collections[collName];
    this.saveToStorage();
    return true;
  }

  public renameDatabase(oldDbName: string, newDbName: string): boolean {
    const cleanNewName = newDbName.trim();
    if (!cleanNewName) {
      throw new Error('Database name cannot be empty');
    }
    if (cleanNewName === oldDbName) {
      return true;
    }
    const db = this.databases[oldDbName];
    if (!db) {
      throw new Error(`Database "${oldDbName}" not found`);
    }
    if (/[/\\. "$*<>:|?]/.test(cleanNewName)) {
      throw new Error('Database name cannot contain spaces or any of: / \\ . " $ * < > : | ?');
    }
    if (cleanNewName.length > 63) {
      throw new Error('Database name must be fewer than 64 characters');
    }
    if (this.databases[cleanNewName]) {
      throw new Error(`Database "${cleanNewName}" already exists`);
    }

    const newDatabases: Record<string, MongoDatabase> = {};
    for (const [key, val] of Object.entries(this.databases)) {
      if (key === oldDbName) {
        val.name = cleanNewName;
        newDatabases[cleanNewName] = val;
      } else {
        newDatabases[key] = val;
      }
    }
    this.databases = newDatabases;
    this.saveToStorage();
    return true;
  }

  public renameCollection(dbName: string, oldCollName: string, newCollName: string): boolean {
    const db = this.databases[dbName];
    if (!db) {
      throw new Error(`Database "${dbName}" not found`);
    }
    const cleanNewName = newCollName.trim();
    if (!cleanNewName) {
      throw new Error('Collection name cannot be empty');
    }
    if (cleanNewName === oldCollName) {
      return true;
    }
    const coll = db.collections[oldCollName];
    if (!coll) {
      throw new Error(`Collection or view "${oldCollName}" not found in database "${dbName}"`);
    }
    if (cleanNewName.includes('$')) {
      throw new Error('Collection names cannot contain the "$" character');
    }
    if (cleanNewName.startsWith('system.')) {
      throw new Error('Collection names cannot start with the "system." prefix');
    }
    if (db.collections[cleanNewName]) {
      throw new Error(`A collection or view named "${cleanNewName}" already exists in database "${dbName}"`);
    }

    const newCollections: Record<string, MongoCollection> = {};
    for (const [key, val] of Object.entries(db.collections)) {
      if (key === oldCollName) {
        val.name = cleanNewName;
        newCollections[cleanNewName] = val;
      } else {
        if (val.isView && val.viewOn === oldCollName) {
          val.viewOn = cleanNewName;
        }
        newCollections[key] = val;
      }
    }
    db.collections = newCollections;
    this.saveToStorage();
    return true;
  }

  public insertDocument(dbName: string, collName: string, doc: Partial<MongoDocument>): MongoDocument {
    const coll = this.getCollection(dbName, collName);
    if (!coll) throw new Error('Collection not found');
    if (coll.isView) {
      throw new Error(`Cannot insert document: "${collName}" is a read-only MongoDB view.`);
    }

    const newDoc: MongoDocument = {
      _id: doc._id || this.generateObjectId(),
      ...doc
    };

    // Check unique indexes
    for (const index of coll.indexes) {
      if (index.unique) {
        for (const existing of coll.documents) {
          const isConflict = Object.keys(index.keys).every(key => {
            const v1 = this.resolvePath(existing, key);
            const v2 = this.resolvePath(newDoc, key);
            return v1 !== undefined && v2 !== undefined && v1 === v2;
          });
          if (isConflict) {
            throw new Error(`E11000 duplicate key error collection: ${dbName}.${collName} index: ${index.name}`);
          }
        }
      }
    }

    coll.documents.unshift(newDoc);
    this.saveToStorage();
    return newDoc;
  }

  public updateDocument(dbName: string, collName: string, docId: string, updatedFields: Record<string, any>): boolean {
    const coll = this.getCollection(dbName, collName);
    if (!coll) return false;
    if (coll.isView) {
      throw new Error(`Cannot update document: "${collName}" is a read-only MongoDB view.`);
    }
    const index = coll.documents.findIndex(d => d._id === docId);
    if (index === -1) return false;

    // Handle MongoDB update operators if present (e.g. $set, $unset, $inc)
    let finalDoc = { ...coll.documents[index] };
    if (updatedFields.$set) {
      for (const [k, v] of Object.entries(updatedFields.$set)) {
        this.setPath(finalDoc, k, v);
      }
    } else if (updatedFields.$inc) {
      for (const [k, v] of Object.entries(updatedFields.$inc)) {
        const cur = Number(this.resolvePath(finalDoc, k) || 0);
        this.setPath(finalDoc, k, cur + Number(v));
      }
    } else if (updatedFields.$unset) {
      for (const k of Object.keys(updatedFields.$unset)) {
        this.unsetPath(finalDoc, k);
      }
    } else {
      // Direct replacement/merge
      finalDoc = { ...finalDoc, ...updatedFields, _id: docId };
    }

    coll.documents[index] = finalDoc;
    this.saveToStorage();
    return true;
  }

  public deleteDocument(dbName: string, collName: string, docId: string): boolean {
    const coll = this.getCollection(dbName, collName);
    if (!coll) return false;
    if (coll.isView) {
      throw new Error(`Cannot delete document: "${collName}" is a read-only MongoDB view.`);
    }
    const initialLen = coll.documents.length;
    coll.documents = coll.documents.filter(d => d._id !== docId);
    this.saveToStorage();
    return coll.documents.length < initialLen;
  }

  public deleteMany(dbName: string, collName: string, filterStrOrObj: any): { acknowledged: boolean; deletedCount: number } {
    const coll = this.getCollection(dbName, collName);
    if (!coll) throw new Error(`Collection "${collName}" not found`);
    if (coll.isView) throw new Error(`Cannot delete from view "${collName}": views are read-only`);

    let parsedFilter: any = {};
    if (typeof filterStrOrObj === 'string') {
      parsedFilter = filterStrOrObj.trim() ? this.tolerantParse(filterStrOrObj) : {};
    } else if (filterStrOrObj && typeof filterStrOrObj === 'object') {
      parsedFilter = filterStrOrObj;
    }

    const beforeLen = coll.documents.length;
    coll.documents = coll.documents.filter(doc => !this.matchesFilter(doc, parsedFilter));
    const deletedCount = beforeLen - coll.documents.length;
    this.saveToStorage();
    return { acknowledged: true, deletedCount };
  }

  public deleteOne(dbName: string, collName: string, filterStrOrObj: any): { acknowledged: boolean; deletedCount: number } {
    const coll = this.getCollection(dbName, collName);
    if (!coll) throw new Error(`Collection "${collName}" not found`);
    if (coll.isView) throw new Error(`Cannot delete from view "${collName}": views are read-only`);

    let parsedFilter: any = {};
    if (typeof filterStrOrObj === 'string') {
      parsedFilter = filterStrOrObj.trim() ? this.tolerantParse(filterStrOrObj) : {};
    } else if (filterStrOrObj && typeof filterStrOrObj === 'object') {
      parsedFilter = filterStrOrObj;
    }

    const targetIdx = coll.documents.findIndex(doc => this.matchesFilter(doc, parsedFilter));
    let deletedCount = 0;
    if (targetIdx !== -1) {
      coll.documents.splice(targetIdx, 1);
      deletedCount = 1;
      this.saveToStorage();
    }
    return { acknowledged: true, deletedCount };
  }

  public updateMany(
    dbName: string,
    collName: string,
    filterStrOrObj: any,
    updateStrOrObj: any
  ): { acknowledged: boolean; matchedCount: number; modifiedCount: number } {
    const coll = this.getCollection(dbName, collName);
    if (!coll) throw new Error(`Collection "${collName}" not found`);
    if (coll.isView) throw new Error(`Cannot update view "${collName}": views are read-only`);

    let parsedFilter: any = {};
    if (typeof filterStrOrObj === 'string') {
      parsedFilter = filterStrOrObj.trim() ? this.tolerantParse(filterStrOrObj) : {};
    } else if (filterStrOrObj && typeof filterStrOrObj === 'object') {
      parsedFilter = filterStrOrObj;
    }

    let parsedUpdate: any = {};
    if (typeof updateStrOrObj === 'string') {
      parsedUpdate = updateStrOrObj.trim() ? this.tolerantParse(updateStrOrObj) : {};
    } else if (updateStrOrObj && typeof updateStrOrObj === 'object') {
      parsedUpdate = updateStrOrObj;
    }

    let matchedCount = 0;
    let modifiedCount = 0;

    for (let i = 0; i < coll.documents.length; i++) {
      if (this.matchesFilter(coll.documents[i], parsedFilter)) {
        matchedCount++;
        const docId = coll.documents[i]._id;
        const success = this.updateDocument(dbName, collName, docId, parsedUpdate);
        if (success) modifiedCount++;
      }
    }
    return { acknowledged: true, matchedCount, modifiedCount };
  }

  public updateOne(
    dbName: string,
    collName: string,
    filterStrOrObj: any,
    updateStrOrObj: any
  ): { acknowledged: boolean; matchedCount: number; modifiedCount: number } {
    const coll = this.getCollection(dbName, collName);
    if (!coll) throw new Error(`Collection "${collName}" not found`);
    if (coll.isView) throw new Error(`Cannot update view "${collName}": views are read-only`);

    let parsedFilter: any = {};
    if (typeof filterStrOrObj === 'string') {
      parsedFilter = filterStrOrObj.trim() ? this.tolerantParse(filterStrOrObj) : {};
    } else if (filterStrOrObj && typeof filterStrOrObj === 'object') {
      parsedFilter = filterStrOrObj;
    }

    let parsedUpdate: any = {};
    if (typeof updateStrOrObj === 'string') {
      parsedUpdate = updateStrOrObj.trim() ? this.tolerantParse(updateStrOrObj) : {};
    } else if (updateStrOrObj && typeof updateStrOrObj === 'object') {
      parsedUpdate = updateStrOrObj;
    }

    let matchedCount = 0;
    let modifiedCount = 0;

    const targetDoc = coll.documents.find(doc => this.matchesFilter(doc, parsedFilter));
    if (targetDoc) {
      matchedCount = 1;
      const success = this.updateDocument(dbName, collName, targetDoc._id, parsedUpdate);
      if (success) modifiedCount = 1;
    }
    return { acknowledged: true, matchedCount, modifiedCount };
  }

  public createIndex(dbName: string, collName: string, index: MongoIndex): boolean {
    const coll = this.getCollection(dbName, collName);
    if (!coll) return false;
    if (coll.indexes.some(i => i.name === index.name)) return false;
    coll.indexes.push({
      ...index,
      sizeKb: Math.floor(Math.random() * 40) + 16
    });
    this.saveToStorage();
    return true;
  }

  public dropIndex(dbName: string, collName: string, indexName: string): boolean {
    const coll = this.getCollection(dbName, collName);
    if (!coll || indexName === '_id_') return false;
    coll.indexes = coll.indexes.filter(i => i.name !== indexName);
    this.saveToStorage();
    return true;
  }

  // Query Execution
  public findDocuments(
    dbName: string,
    collName: string,
    options: QueryFilterOptions
  ): { documents: MongoDocument[]; totalCount: number; executionTimeMs: number } {
    const startTime = performance.now();
    const coll = this.getCollection(dbName, collName);
    if (!coll) return { documents: [], totalCount: 0, executionTimeMs: 0 };

    let parsedFilter: Record<string, any> = {};
    let parsedProject: Record<string, any> = {};
    let parsedSort: Record<string, 1 | -1> = {};

    try {
      if (options.filter && options.filter.trim()) {
        parsedFilter = this.tolerantParse(options.filter);
      }
    } catch (e: any) {
      throw new Error(`Invalid Filter JSON: ${e.message}`);
    }

    try {
      if (options.project && options.project.trim()) {
        parsedProject = this.tolerantParse(options.project);
      }
    } catch (e: any) {
      throw new Error(`Invalid Project JSON: ${e.message}`);
    }

    try {
      if (options.sort && options.sort.trim()) {
        parsedSort = this.tolerantParse(options.sort);
      }
    } catch (e: any) {
      throw new Error(`Invalid Sort JSON: ${e.message}`);
    }

    // 1. Filter
    let filtered = coll.documents.filter(doc => this.matchesFilter(doc, parsedFilter));
    const totalCount = filtered.length;

    // 2. Sort
    if (Object.keys(parsedSort).length > 0) {
      filtered = this.sortDocuments(filtered, parsedSort);
    }

    // 3. Skip & Limit
    const skip = Math.max(0, options.skip || 0);
    const limit = Math.max(1, options.limit || 20);
    const paginated = filtered.slice(skip, skip + limit);

    // 4. Project
    const projected = Object.keys(parsedProject).length > 0
      ? paginated.map(doc => this.applyProjection(doc, parsedProject))
      : paginated;

    const executionTimeMs = Math.round((performance.now() - startTime) * 100) / 100;
    return {
      documents: projected,
      totalCount,
      executionTimeMs: Math.max(0.4, executionTimeMs)
    };
  }

  // Aggregation Pipeline Execution (Visual Pipeline)
  public executeAggregation(
    dbName: string,
    collName: string,
    pipeline: PipelineStage[]
  ): { documents: any[]; stageResults: { stageIndex: number; count: number; sample: any[] }[]; executionTimeMs: number } {
    const startTime = performance.now();
    const coll = this.getCollection(dbName, collName);
    if (!coll) return { documents: [], stageResults: [], executionTimeMs: 0 };

    let currentDocs: any[] = JSON.parse(JSON.stringify(coll.documents));
    const stageResults: { stageIndex: number; count: number; sample: any[] }[] = [];

    pipeline.forEach((stage, idx) => {
      if (!stage.enabled) return;

      let stageContent: any;
      try {
        stageContent = this.tolerantParse(stage.content);
      } catch (err: any) {
        throw new Error(`Error in stage ${idx + 1} (${stage.operator}): ${err.message}`);
      }

      currentDocs = this.applyPipelineStage(currentDocs, stage.operator, stageContent, dbName, idx);

      stageResults.push({
        stageIndex: idx,
        count: currentDocs.length,
        sample: currentDocs.slice(0, 3)
      });
    });

    const executionTimeMs = Math.round((performance.now() - startTime) * 100) / 100;
    return {
      documents: currentDocs,
      stageResults,
      executionTimeMs: Math.max(0.3, executionTimeMs)
    };
  }

  // Raw Aggregation Script Execution (JSON Script)
  public executeRawAggregation(
    dbName: string,
    collName: string,
    rawInput: string | any[]
  ): {
    documents: any[];
    stageResults: { stageIndex: number; operator: string; count: number; sample: any[] }[];
    executionTimeMs: number;
    stagesCount: number;
  } {
    const startTime = performance.now();
    let stagesArr: any[];
    if (typeof rawInput === 'string') {
      stagesArr = this.parseAggregationScript(rawInput);
    } else {
      stagesArr = Array.isArray(rawInput) ? rawInput : [rawInput];
    }

    const coll = this.getCollection(dbName, collName);
    if (!coll) return { documents: [], stageResults: [], executionTimeMs: 0, stagesCount: 0 };

    let currentDocs: any[] = JSON.parse(JSON.stringify(coll.documents));
    const stageResults: { stageIndex: number; operator: string; count: number; sample: any[] }[] = [];

    stagesArr.forEach((stageObj, idx) => {
      if (!stageObj || typeof stageObj !== 'object') {
        throw new Error(`Stage ${idx + 1} is not a valid object, expected { $stage: ... }`);
      }
      const keys = Object.keys(stageObj);
      const op = keys.find(k => k.startsWith('$')) || keys[0];
      if (!op) return;
      const stageContent = stageObj[op];

      currentDocs = this.applyPipelineStage(currentDocs, op, stageContent, dbName, idx);

      stageResults.push({
        stageIndex: idx,
        operator: op,
        count: currentDocs.length,
        sample: currentDocs.slice(0, 3)
      });
    });

    const executionTimeMs = Math.round((performance.now() - startTime) * 100) / 100;
    return {
      documents: currentDocs,
      stageResults,
      executionTimeMs: Math.max(0.3, executionTimeMs),
      stagesCount: stagesArr.length
    };
  }

  // Convert visual PipelineStage array into formatted Raw JSON script
  public pipelineStagesToRawJson(stages: PipelineStage[]): string {
    const rawList = stages
      .filter(s => s.enabled)
      .map(s => {
        let parsed: any;
        try {
          parsed = this.tolerantParse(s.content);
        } catch {
          parsed = s.content;
        }
        return { [s.operator]: parsed };
      });
    return JSON.stringify(rawList, null, 2);
  }

  // Convert raw JSON script into visual PipelineStage array
  public rawJsonToPipelineStages(script: string): PipelineStage[] {
    const parsed = this.parseAggregationScript(script);
    if (!Array.isArray(parsed)) {
      throw new Error('Aggregation script must evaluate to an array of stage objects, e.g. [{ $match: { ... } }]');
    }
    return parsed.map((item, idx) => {
      if (!item || typeof item !== 'object') {
        throw new Error(`Stage ${idx + 1} must be an object, e.g. { $match: { ... } }`);
      }
      const keys = Object.keys(item);
      const opKey = (keys.find(k => k.startsWith('$')) || keys[0] || '$match') as PipelineStage['operator'];
      const val = item[opKey];
      return {
        id: String(Date.now() + idx),
        operator: opKey,
        content: typeof val === 'object' ? JSON.stringify(val, null, 2) : String(val),
        enabled: true
      };
    });
  }

  // Core execution logic for a single aggregation stage
  private applyPipelineStage(
    docs: any[],
    operator: string,
    stageContent: any,
    dbName: string,
    idx: number
  ): any[] {
    let currentDocs = docs;

    switch (operator) {
      case '$match':
        return currentDocs.filter(d => this.matchesFilter(d, stageContent));

      case '$project':
        return currentDocs.map(d => this.applyProjection(d, stageContent));

      case '$sort':
        return this.sortDocuments(currentDocs, stageContent);

      case '$limit': {
        const n = typeof stageContent === 'number' ? stageContent : Number(stageContent);
        return currentDocs.slice(0, Math.max(0, n));
      }

      case '$skip': {
        const n = typeof stageContent === 'number' ? stageContent : Number(stageContent);
        return currentDocs.slice(Math.max(0, n));
      }

      case '$count': {
        const fieldName = typeof stageContent === 'string' ? stageContent : 'count';
        return [{ [fieldName]: currentDocs.length }];
      }

      case '$unwind': {
        const path = typeof stageContent === 'string'
          ? stageContent.replace(/^\$/, '')
          : stageContent.path?.replace(/^\$/, '');
        const unrolled: any[] = [];
        for (const doc of currentDocs) {
          const arr = this.resolvePath(doc, path);
          if (Array.isArray(arr) && arr.length > 0) {
            for (const item of arr) {
              const clone = JSON.parse(JSON.stringify(doc));
              this.setPath(clone, path, item);
              unrolled.push(clone);
            }
          } else if (stageContent.preserveNullAndEmptyArrays) {
            unrolled.push(doc);
          }
        }
        return unrolled;
      }

      case '$group': {
        const idExpr = stageContent._id;
        const groups = new Map<string, any[]>();

        for (const doc of currentDocs) {
          let key = 'null';
          if (typeof idExpr === 'string' && idExpr.startsWith('$')) {
            key = String(this.resolvePath(doc, idExpr.slice(1)));
          } else if (idExpr === null) {
            key = 'null';
          } else if (typeof idExpr === 'object') {
            key = JSON.stringify(idExpr);
          }
          if (!groups.has(key)) groups.set(key, []);
          groups.get(key)!.push(doc);
        }

        const groupedDocs: any[] = [];
        groups.forEach((docsInGroup, key) => {
          const resultDoc: any = {};
          if (idExpr === null) {
            resultDoc._id = null;
          } else if (typeof idExpr === 'string' && idExpr.startsWith('$')) {
            resultDoc._id = this.resolvePath(docsInGroup[0], idExpr.slice(1));
          } else {
            resultDoc._id = key;
          }

          // Accumulators
          for (const [field, accExpr] of Object.entries(stageContent)) {
            if (field === '_id') continue;
            if (typeof accExpr === 'object' && accExpr !== null) {
              const [accOp, exprVal] = Object.entries(accExpr)[0] || [];
              if (accOp === '$sum') {
                if (typeof exprVal === 'number') {
                  resultDoc[field] = docsInGroup.length * exprVal;
                } else if (typeof exprVal === 'string' && exprVal.startsWith('$')) {
                  const p = exprVal.slice(1);
                  resultDoc[field] = docsInGroup.reduce((acc, d) => acc + (Number(this.resolvePath(d, p)) || 0), 0);
                }
              } else if (accOp === '$avg') {
                if (typeof exprVal === 'string' && exprVal.startsWith('$')) {
                  const p = exprVal.slice(1);
                  const total = docsInGroup.reduce((acc, d) => acc + (Number(this.resolvePath(d, p)) || 0), 0);
                  resultDoc[field] = docsInGroup.length ? Math.round((total / docsInGroup.length) * 100) / 100 : 0;
                }
              } else if (accOp === '$min' || accOp === '$max') {
                const p = typeof exprVal === 'string' && exprVal.startsWith('$') ? exprVal.slice(1) : '';
                const vals = docsInGroup.map(d => this.resolvePath(d, p)).filter(v => v !== undefined && v !== null);
                resultDoc[field] = accOp === '$min' ? Math.min(...vals) : Math.max(...vals);
              } else if (accOp === '$push') {
                const p = typeof exprVal === 'string' && exprVal.startsWith('$') ? exprVal.slice(1) : '';
                resultDoc[field] = docsInGroup.map(d => this.resolvePath(d, p));
              } else if (accOp === '$first') {
                const p = typeof exprVal === 'string' && exprVal.startsWith('$') ? exprVal.slice(1) : '';
                resultDoc[field] = this.resolvePath(docsInGroup[0], p);
              }
            }
          }
          groupedDocs.push(resultDoc);
        });
        return groupedDocs;
      }

      case '$addFields': {
        return currentDocs.map(doc => {
          const clone = { ...doc };
          for (const [k, v] of Object.entries(stageContent)) {
            if (typeof v === 'string' && v.startsWith('$')) {
              clone[k] = this.resolvePath(doc, v.slice(1));
            } else {
              clone[k] = v;
            }
          }
          return clone;
        });
      }

      case '$lookup': {
        const fromCollName = stageContent.from;
        const localField = stageContent.localField;
        const foreignField = stageContent.foreignField;
        const asField = stageContent.as;
        const foreignColl = this.getCollection(dbName, fromCollName);

        if (foreignColl) {
          return currentDocs.map(doc => {
            const localVal = this.resolvePath(doc, localField);
            const matches = foreignColl.documents.filter(fDoc => {
              const fVal = this.resolvePath(fDoc, foreignField);
              return fVal === localVal;
            });
            return { ...doc, [asField]: matches };
          });
        }
        return currentDocs;
      }

      case '$facet': {
        // Run multiple pipelines on current documents
        const facetResults: Record<string, any[]> = {};
        for (const [subFacetName, subPipeline] of Object.entries(stageContent)) {
          if (Array.isArray(subPipeline)) {
            let subDocs = JSON.parse(JSON.stringify(currentDocs));
            for (let sIdx = 0; sIdx < subPipeline.length; sIdx++) {
              const subStage = subPipeline[sIdx];
              const sOp = Object.keys(subStage).find(k => k.startsWith('$')) || Object.keys(subStage)[0];
              if (sOp) {
                subDocs = this.applyPipelineStage(subDocs, sOp, subStage[sOp], dbName, sIdx);
              }
            }
            facetResults[subFacetName] = subDocs;
          }
        }
        return [facetResults];
      }

      default:
        // Pass through unsupported stage or notify
        return currentDocs;
    }
  }

  // Schema Analyzer
  public analyzeSchema(dbName: string, collName: string): SchemaFieldStat[] {
    const coll = this.getCollection(dbName, collName);
    if (!coll || coll.documents.length === 0) return [];

    const totalDocs = coll.documents.length;
    const fieldMap = new Map<string, { types: Map<string, number>; values: any[]; missing: number }>();

    for (const doc of coll.documents) {
      const paths = this.collectPaths(doc);
      for (const [path, val] of Object.entries(paths)) {
        if (!fieldMap.has(path)) {
          fieldMap.set(path, { types: new Map(), values: [], missing: 0 });
        }
        const entry = fieldMap.get(path)!;
        const type = this.detectBsonType(val);
        entry.types.set(type, (entry.types.get(type) || 0) + 1);
        if (entry.values.length < 50) {
          entry.values.push(val);
        }
      }
    }

    const result: SchemaFieldStat[] = [];
    fieldMap.forEach((entry, path) => {
      const totalPresent = Array.from(entry.types.values()).reduce((a, b) => a + b, 0);
      const missingCount = Math.max(0, totalDocs - totalPresent);
      const typesList = Array.from(entry.types.entries()).map(([t, count]) => ({
        type: t,
        count,
        percentage: Math.round((count / totalDocs) * 100)
      }));

      // Find distinct count & min/max
      const distinctSet = new Set(entry.values.map(v => (typeof v === 'object' ? JSON.stringify(v) : v)));
      const numericValues = entry.values.filter(v => typeof v === 'number');

      result.push({
        name: path.split('.').pop() || path,
        path,
        types: typesList,
        totalValues: totalPresent,
        missingCount,
        missingPercentage: Math.round((missingCount / totalDocs) * 100),
        distinctCount: distinctSet.size,
        sampleValues: entry.values.slice(0, 6),
        min: numericValues.length ? Math.min(...numericValues) : undefined,
        max: numericValues.length ? Math.max(...numericValues) : undefined
      });
    });

    // Sort: _id first, then alphabetically
    return result.sort((a, b) => {
      if (a.path === '_id') return -1;
      if (b.path === '_id') return 1;
      return a.path.localeCompare(b.path);
    });
  }

  // Explain Plan
  public explainPlan(dbName: string, collName: string, filterStr: string, sortStr: string): ExplainPlanResult {
    const coll = this.getCollection(dbName, collName);
    const parsedFilter = filterStr ? this.tolerantParse(filterStr) : {};
    const parsedSort = sortStr ? this.tolerantParse(sortStr) : {};

    const filterKeys = Object.keys(parsedFilter);
    let winningIndex: any = null;

    if (coll) {
      for (const idx of coll.indexes) {
        const indexKeys = Object.keys(idx.keys);
        if (filterKeys.some(k => indexKeys.includes(k))) {
          winningIndex = idx;
          break;
        }
      }
    }

    const totalDocs = coll?.documents.length || 0;
    const isIxScan = !!winningIndex;
    const filteredCount = coll ? coll.documents.filter(d => this.matchesFilter(d, parsedFilter)).length : 0;
    const docsExamined = isIxScan ? Math.max(filteredCount, 1) : totalDocs;
    const keysExamined = isIxScan ? Math.max(filteredCount, 1) : 0;

    return {
      queryPlanner: {
        plannerVersion: 1,
        namespace: `${dbName}.${collName}`,
        indexFilterSet: false,
        winningPlan: {
          stage: isIxScan ? 'IXSCAN' : 'COLLSCAN',
          filter: parsedFilter,
          indexName: winningIndex ? winningIndex.name : undefined,
          direction: 'forward'
        },
        rejectedPlans: []
      },
      executionStats: {
        executionSuccess: true,
        nReturned: filteredCount,
        executionTimeMillis: isIxScan ? 0.35 : 1.2,
        totalKeysExamined: keysExamined,
        totalDocsExamined: docsExamined,
        executionStages: {
          stage: isIxScan ? 'FETCH' : 'COLLSCAN',
          nReturned: filteredCount,
          executionTimeMillisEstimate: isIxScan ? 0.35 : 1.2,
          works: docsExamined + 1,
          advanced: filteredCount,
          needTime: 0,
          isEOF: 1
        }
      },
      serverInfo: {
        host: '127.0.0.1',
        port: 27017,
        version: '7.0.8',
        gitVersion: 'c8d4745812e434f0e9f6556488d5e08b1a85e8d5'
      }
    };
  }

  // Code Generation for query & pipeline
  public generateCode(
    language: 'node' | 'python' | 'csharp' | 'java' | 'mongosh',
    dbName: string,
    collName: string,
    filterStr: string,
    projectStr?: string,
    sortStr?: string
  ): string {
    const f = filterStr?.trim() || '{}';
    const p = projectStr?.trim() || '{}';
    const s = sortStr?.trim() || '{}';

    switch (language) {
      case 'node':
        return `const { MongoClient } = require('mongodb');

async function run() {
  const uri = "mongodb://localhost:27017";
  const client = new MongoClient(uri);

  try {
    const database = client.db('${dbName}');
    const collection = database.collection('${collName}');

    // Query filter
    const query = ${f};
    const options = {
      projection: ${p},
      sort: ${s}
    };

    const cursor = collection.find(query, options);
    const results = await cursor.toArray();
    console.log(\`Found \${results.length} documents:\`, results);
  } finally {
    await client.close();
  }
}
run().catch(console.dir);`;

      case 'python':
        return `from pymongo import MongoClient

# Connect to MongoDB instance
client = MongoClient("mongodb://localhost:27017")
db = client["${dbName}"]
collection = db["${collName}"]

# Query criteria
filter_query = ${f.replace(/: true/g, ': True').replace(/: false/g, ': False').replace(/: null/g, ': None')}
projection = ${p}
sort_spec = ${s}

cursor = collection.find(filter_query, projection).sort(list(sort_spec.items()))

for document in cursor:
    print(document)

client.close()`;

      case 'csharp':
        return `using MongoDB.Bson;
using MongoDB.Driver;
using System;

class Program
{
    static void Main()
    {
        var client = new MongoClient("mongodb://localhost:27017");
        var database = client.GetDatabase("${dbName}");
        var collection = database.GetCollection<BsonDocument>("${collName}");

        var filter = BsonDocument.Parse(@"${f}");
        var findOptions = new FindOptions<BsonDocument>
        {
            Projection = BsonDocument.Parse(@"${p}"),
            Sort = BsonDocument.Parse(@"${s}")
        };

        var cursor = collection.Find(filter, findOptions);
        foreach (var doc in cursor.ToEnumerable())
        {
            Console.WriteLine(doc);
        }
    }
}`;

      case 'java':
        return `import com.mongodb.client.MongoClient;
import com.mongodb.client.MongoClients;
import com.mongodb.client.MongoCollection;
import com.mongodb.client.MongoDatabase;
import org.bson.Document;

public class CompassQuery {
    public static void main(String[] args) {
        try (MongoClient mongoClient = MongoClients.create("mongodb://localhost:27017")) {
            MongoDatabase database = mongoClient.getDatabase("${dbName}");
            MongoCollection<Document> collection = database.getCollection("${collName}");

            Document filter = Document.parse("${f.replace(/"/g, '\\"')}");
            for (Document doc : collection.find(filter)) {
                System.out.println(doc.toJson());
            }
        }
    }
}`;

      case 'mongosh':
      default:
        return `use ${dbName};

db.${collName}.find(
  ${f}${p !== '{}' ? `,\n  ${p}` : ''}
)${s !== '{}' ? `\n.sort(${s})` : ''};`;
    }
  }

  public generateAggregationCode(
    lang: 'node' | 'python' | 'csharp' | 'java' | 'mongosh',
    dbName: string,
    collName: string,
    pipelineStr: string
  ): string {
    const pipe = pipelineStr.trim() || '[]';
    switch (lang) {
      case 'node':
        return `import { MongoClient } from 'mongodb';

const uri = 'mongodb://localhost:27017';
const client = new MongoClient(uri);

async function runAggregation() {
  try {
    const database = client.db('${dbName}');
    const collection = database.collection('${collName}');

    const pipeline = ${pipe};

    const aggCursor = collection.aggregate(pipeline);
    for await (const doc of aggCursor) {
      console.log(doc);
    }
  } finally {
    await client.close();
  }
}

runAggregation().catch(console.error);`;

      case 'python':
        return `from pymongo import MongoClient

client = MongoClient('mongodb://localhost:27017/')
db = client['${dbName}']
collection = db['${collName}']

pipeline = ${pipe}

cursor = collection.aggregate(pipeline)
for doc in cursor:
    print(doc)`;

      case 'csharp':
        return `using MongoDB.Bson;
using MongoDB.Driver;
using System;

class Program
{
    static void Main()
    {
        var client = new MongoClient("mongodb://localhost:27017");
        var database = client.GetDatabase("${dbName}");
        var collection = database.GetCollection<BsonDocument>("${collName}");

        var pipeline = BsonSerializer.Deserialize<BsonDocument[]>(@"${pipe.replace(/"/g, '""')}");

        var cursor = collection.Aggregate<BsonDocument>(pipeline);
        foreach (var doc in cursor.ToEnumerable())
        {
            Console.WriteLine(doc);
        }
    }
}`;

      case 'java':
        return `import com.mongodb.client.MongoClient;
import com.mongodb.client.MongoClients;
import com.mongodb.client.MongoCollection;
import com.mongodb.client.MongoDatabase;
import org.bson.Document;

public class CompassAggregation {
    public static void main(String[] args) {
        try (MongoClient mongoClient = MongoClients.create("mongodb://localhost:27017")) {
            MongoDatabase database = mongoClient.getDatabase("${dbName}");
            MongoCollection<Document> collection = database.getCollection("${collName}");

            System.out.println("Running aggregation on ${collName}...");
        }
    }
}`;

      case 'mongosh':
      default:
        return `use ${dbName};

db.${collName}.aggregate(
${pipe}
);`;
    }
  }

  // --- Internal Utilities ---

  public parseAggregationScript(script: string): any[] {
    if (!script || !script.trim()) return [];
    let cleaned = script.trim();

    // Strip mongosh wrapper e.g. db.collection.aggregate([ ... ])
    const shellMatch = cleaned.match(/\.aggregate\s*\(\s*(\[[\s\S]*\])\s*\)/);
    if (shellMatch) {
      cleaned = shellMatch[1].trim();
    }

    // Try standard JSON.parse first
    try {
      const res = JSON.parse(cleaned);
      return Array.isArray(res) ? res : [res];
    } catch {
      // Relaxed JS evaluation sandbox (handles non-quoted keys, single quotes, comments, trailing commas, ISODate, ObjectId)
      try {
        const withoutComments = cleaned
          .replace(/\/\*[\s\S]*?\*\//g, '')
          .replace(/\/\/[^\n\r]*/g, '')
          .replace(/ObjectId\s*\(\s*["']?([^"')]+)["']?\s*\)/g, '"$1"')
          .replace(/ISODate\s*\(\s*["']?([^"')]+)["']?\s*\)/g, '"$1"');
        const fn = new Function(`"use strict"; return (${withoutComments});`);
        const res = fn();
        return Array.isArray(res) ? res : [res];
      } catch (err: any) {
        throw new Error(`Invalid aggregation syntax: ${err.message}`);
      }
    }
  }

  public tolerantParse(jsonStr: string): any {
    if (!jsonStr || !jsonStr.trim()) return {};
    const trimmed = jsonStr.trim();
    // Support non-quoted keys like { title: "Matrix" }
    const cleaned = trimmed
      .replace(/([{,]\s*)([a-zA-Z0-9_$.]+)\s*:/g, '$1"$2":')
      .replace(/'/g, '"');
    try {
      return JSON.parse(cleaned);
    } catch {
      // Fallback eval in safe sandbox context if JSON syntax allows
      return JSON.parse(trimmed);
    }
  }

  private matchesFilter(doc: MongoDocument, filter: Record<string, any>): boolean {
    if (!filter || Object.keys(filter).length === 0) return true;

    for (const [key, expected] of Object.entries(filter)) {
      if (key === '$and') {
        if (Array.isArray(expected) && !expected.every(sub => this.matchesFilter(doc, sub))) return false;
        continue;
      }
      if (key === '$or') {
        if (Array.isArray(expected) && !expected.some(sub => this.matchesFilter(doc, sub))) return false;
        continue;
      }
      if (key === '$nor') {
        if (Array.isArray(expected) && expected.some(sub => this.matchesFilter(doc, sub))) return false;
        continue;
      }

      const val = this.resolvePath(doc, key);

      if (typeof expected === 'object' && expected !== null && !Array.isArray(expected)) {
        for (const [op, opVal] of Object.entries(expected)) {
          if (op === '$eq' && val !== opVal) return false;
          if (op === '$ne' && val === opVal) return false;
          if (op === '$gt' && !(val > (opVal as any))) return false;
          if (op === '$gte' && !(val >= (opVal as any))) return false;
          if (op === '$lt' && !(val < (opVal as any))) return false;
          if (op === '$lte' && !(val <= (opVal as any))) return false;
          if (op === '$in') {
            if (Array.isArray(val)) {
              if (!val.some(item => (opVal as any[]).includes(item))) return false;
            } else if (!(opVal as any[]).includes(val)) return false;
          }
          if (op === '$nin' && (opVal as any[]).includes(val)) return false;
          if (op === '$exists') {
            const exists = val !== undefined;
            if (exists !== !!opVal) return false;
          }
          if (op === '$regex') {
            const regex = new RegExp(String(opVal), expected.$options || 'i');
            if (!regex.test(String(val || ''))) return false;
          }
          if (op === '$size' && (!Array.isArray(val) || val.length !== opVal)) return false;
        }
      } else {
        // Direct match or array contains element
        if (Array.isArray(val)) {
          if (!val.includes(expected)) return false;
        } else if (val !== expected) {
          return false;
        }
      }
    }
    return true;
  }

  private resolvePath(obj: any, path: string): any {
    if (!obj || !path) return undefined;
    const parts = path.split('.');
    let cur = obj;
    for (const part of parts) {
      if (cur === undefined || cur === null) return undefined;
      cur = cur[part];
    }
    return cur;
  }

  private setPath(obj: any, path: string, val: any) {
    const parts = path.split('.');
    let cur = obj;
    for (let i = 0; i < parts.length - 1; i++) {
      const p = parts[i];
      if (!cur[p] || typeof cur[p] !== 'object') {
        cur[p] = {};
      }
      cur = cur[p];
    }
    cur[parts[parts.length - 1]] = val;
  }

  private unsetPath(obj: any, path: string) {
    const parts = path.split('.');
    let cur = obj;
    for (let i = 0; i < parts.length - 1; i++) {
      if (!cur[parts[i]]) return;
      cur = cur[parts[i]];
    }
    delete cur[parts[parts.length - 1]];
  }

  private applyProjection(doc: MongoDocument, proj: Record<string, any>): any {
    const isExclusive = Object.values(proj).some(v => v === 0);
    const result: any = isExclusive ? { ...doc } : {};

    if (proj._id === 0) {
      delete result._id;
    } else if (doc._id !== undefined) {
      result._id = doc._id;
    }

    if (isExclusive) {
      for (const [k, v] of Object.entries(proj)) {
        if (v === 0) {
          delete result[k];
        }
      }
    } else {
      for (const [k, v] of Object.entries(proj)) {
        if (v === 1 && k !== '_id') {
          result[k] = this.resolvePath(doc, k);
        }
      }
    }
    return result;
  }

  private sortDocuments(docs: MongoDocument[], sortSpec: Record<string, 1 | -1>): MongoDocument[] {
    const keys = Object.keys(sortSpec);
    return [...docs].sort((a, b) => {
      for (const key of keys) {
        const order = sortSpec[key];
        const valA = this.resolvePath(a, key);
        const valB = this.resolvePath(b, key);

        if (valA === valB) continue;
        if (valA === undefined || valA === null) return 1;
        if (valB === undefined || valB === null) return -1;

        if (valA < valB) return order === 1 ? -1 : 1;
        if (valA > valB) return order === 1 ? 1 : -1;
      }
      return 0;
    });
  }

  private collectPaths(obj: any, prefix = ''): Record<string, any> {
    let map: Record<string, any> = {};
    if (obj === null || typeof obj !== 'object') {
      return { [prefix]: obj };
    }
    for (const [k, v] of Object.entries(obj)) {
      const fullPath = prefix ? `${prefix}.${k}` : k;
      map[fullPath] = v;
      if (v !== null && typeof v === 'object' && !Array.isArray(v)) {
        Object.assign(map, this.collectPaths(v, fullPath));
      }
    }
    return map;
  }

  public detectBsonType(val: any): string {
    if (val === null) return 'null';
    if (val === undefined) return 'undefined';
    if (Array.isArray(val)) return 'Array';
    if (typeof val === 'boolean') return 'Boolean';
    if (typeof val === 'number') return Number.isInteger(val) ? 'Int32' : 'Double';
    if (typeof val === 'string') {
      if (/^[0-9a-fA-F]{24}$/.test(val)) return 'ObjectId';
      if (/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/.test(val)) return 'Date';
      return 'String';
    }
    if (typeof val === 'object') return 'Object';
    return typeof val;
  }

  public generateObjectId(): string {
    const timestamp = Math.floor(new Date().getTime() / 1000).toString(16);
    const random = 'xxxxxxxxxxxxxxxx'
      .replace(/[x]/g, () => Math.floor(Math.random() * 16).toString(16))
      .toLowerCase();
    return (timestamp + random).substring(0, 24);
  }
}

export const mongoEngine = new MongoEngine();
