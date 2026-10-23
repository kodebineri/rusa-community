export type BsonType = 
  | 'objectId'
  | 'string'
  | 'number'
  | 'boolean'
  | 'date'
  | 'array'
  | 'object'
  | 'null'
  | 'regex';

export interface MongoDocument {
  _id: string;
  [key: string]: any;
}

export interface MongoIndex {
  name: string;
  keys: Record<string, 1 | -1 | 'text' | '2dsphere'>;
  unique?: boolean;
  sparse?: boolean;
  sizeKb?: number;
}

export interface MongoCollection {
  name: string;
  documents: MongoDocument[];
  indexes: MongoIndex[];
  validator?: Record<string, any>;
  validationLevel?: 'off' | 'moderate' | 'strict';
  validationAction?: 'warn' | 'error';
  // MongoDB View support
  isView?: boolean;
  viewOn?: string; // Source collection name
  pipeline?: any[]; // View aggregation pipeline
}

export interface MongoDatabase {
  name: string;
  collections: Record<string, MongoCollection>;
}

export interface ConnectionProfile {
  id: string;
  name: string;
  uri: string;
  color?: string;
  favorite?: boolean;
  lastConnected?: string;
  readOnly?: boolean;
}

export interface QueryFilterOptions {
  filter: string; // JSON string
  project: string; // JSON string
  sort: string; // JSON string
  collation?: string;
  maxTimeMS?: number;
  skip: number;
  limit: number;
}

export interface PipelineStage {
  id: string;
  operator: 
    | '$match' 
    | '$project' 
    | '$group' 
    | '$sort' 
    | '$limit' 
    | '$skip' 
    | '$unwind' 
    | '$count' 
    | '$addFields' 
    | '$lookup';
  content: string; // JSON string stage definition
  enabled: boolean;
}

export interface SchemaFieldStat {
  name: string;
  path: string;
  types: { type: string; count: number; percentage: number }[];
  totalValues: number;
  missingCount: number;
  missingPercentage: number;
  distinctCount: number;
  sampleValues: any[];
  min?: any;
  max?: any;
}

export interface ExplainPlanResult {
  queryPlanner: {
    plannerVersion: number;
    namespace: string;
    indexFilterSet: boolean;
    winningPlan: {
      stage: 'COLLSCAN' | 'IXSCAN' | 'FETCH' | 'PROJECTION_SIMPLE';
      filter?: Record<string, any>;
      indexName?: string;
      direction?: 'forward' | 'backward';
    };
    rejectedPlans: any[];
  };
  executionStats: {
    executionSuccess: boolean;
    nReturned: number;
    executionTimeMillis: number;
    totalKeysExamined: number;
    totalDocsExamined: number;
    executionStages: {
      stage: string;
      nReturned: number;
      executionTimeMillisEstimate: number;
      works: number;
      advanced: number;
      needTime: number;
      isEOF: number;
    };
  };
  serverInfo: {
    host: string;
    port: number;
    version: string;
    gitVersion: string;
  };
}
