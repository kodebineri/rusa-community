/// Data models for the Rusa MongoDB client.
/// Equivalent to src/types/mongo.ts.
library;

/// A BSON ObjectId held in the in-memory mirror.
///
/// The bundled sample data stores ObjectIds as their 24-character hex strings,
/// but a document read from a real MongoDB server keeps its ObjectId type as
/// this wrapper. That preserves the distinction between a plain string and an
/// ObjectId when a document is round-tripped through an editor: the JSON view
/// renders it as Extended JSON (`{"$oid": "..."}`) and the parser turns
/// `ObjectId("...")` back into a [MongoObjectId].
class MongoObjectId implements Comparable<MongoObjectId> {
  final String hex;

  const MongoObjectId(this.hex);

  @override
  String toString() => hex;

  /// Serialised by `dart:convert` as Extended JSON so it survives a
  /// `JsonEncoder` round-trip through the document editors.
  Map<String, dynamic> toJson() => {r'$oid': hex};

  @override
  int compareTo(MongoObjectId other) => hex.compareTo(other.hex);

  @override
  bool operator ==(Object other) =>
      other is MongoObjectId && other.hex == hex;

  @override
  int get hashCode => hex.hashCode;
}

class MongoDocument {
  final String id;
  final Map<String, dynamic> data;

  MongoDocument({
    required this.id,
    required this.data,
  });

  factory MongoDocument.fromMap(Map<String, dynamic> map) {
    final docId = map['_id']?.toString() ?? 'unknown';
    return MongoDocument(
      id: docId,
      data: Map<String, dynamic>.from(map),
    );
  }

  Map<String, dynamic> toMap() => Map<String, dynamic>.from(data);

  dynamic operator [](String key) => data[key];
}

class MongoIndex {
  final String name;
  final Map<String, dynamic> keys;
  final bool unique;
  final bool sparse;
  final int sizeKb;

  MongoIndex({
    required this.name,
    required this.keys,
    this.unique = false,
    this.sparse = false,
    this.sizeKb = 16,
  });

  factory MongoIndex.fromMap(Map<String, dynamic> map) {
    return MongoIndex(
      name: map['name'] ?? '',
      keys: Map<String, dynamic>.from(map['keys'] ?? {}),
      unique: map['unique'] ?? false,
      sparse: map['sparse'] ?? false,
      sizeKb: map['sizeKb'] ?? 16,
    );
  }
}

class MongoCollection {
  final String name;
  List<MongoDocument> documents;
  List<MongoIndex> indexes;
  Map<String, dynamic>? validator;
  String validationLevel;
  String validationAction;
  bool isView;
  String? viewOn;
  List<dynamic>? pipeline;

  /// True while a live server is still fetching this collection's documents.
  /// The UI shows a loading state instead of a "0 documents" count.
  bool isLoading;

  /// The server's total document count, when known.
  ///
  /// The in-memory mirror may hold fewer documents than this (very large
  /// collections are capped), so the sidebar shows this value when available.
  int? documentCount;

  /// Set when the last on-demand load failed (e.g. a timeout), so the view can
  /// offer a retry instead of showing a misleading "no documents".
  String? loadError;

  MongoCollection({
    required this.name,
    required this.documents,
    required this.indexes,
    this.validator,
    this.validationLevel = 'moderate',
    this.validationAction = 'error',
    this.isView = false,
    this.viewOn,
    this.pipeline,
    this.isLoading = false,
    this.documentCount,
    this.loadError,
  });
}

class MongoDatabase {
  final String name;
  final Map<String, MongoCollection> collections;

  MongoDatabase({
    required this.name,
    required this.collections,
  });
}

class ConnectionProfile {
  final String id;
  final String name;
  final String uri;
  final String? color;
  final bool favorite;
  final String? lastConnected;
  final bool readOnly;

  ConnectionProfile({
    required this.id,
    required this.name,
    required this.uri,
    this.color,
    this.favorite = false,
    this.lastConnected,
    this.readOnly = false,
  });
}

class QueryFilterOptions {
  String filter;
  String project;
  String sort;
  String? collation;
  int? maxTimeMS;
  int skip;
  int limit;

  QueryFilterOptions({
    this.filter = '',
    this.project = '',
    this.sort = '',
    this.collation,
    this.maxTimeMS,
    this.skip = 0,
    this.limit = 20,
  });

  QueryFilterOptions copyWith({
    String? filter,
    String? project,
    String? sort,
    String? collation,
    int? maxTimeMS,
    int? skip,
    int? limit,
  }) {
    return QueryFilterOptions(
      filter: filter ?? this.filter,
      project: project ?? this.project,
      sort: sort ?? this.sort,
      collation: collation ?? this.collation,
      maxTimeMS: maxTimeMS ?? this.maxTimeMS,
      skip: skip ?? this.skip,
      limit: limit ?? this.limit,
    );
  }
}

/// Result of a `find` query: the paginated page of documents plus the total
/// number of matching documents and a mock execution time.
/// Mirrors the `{ documents, totalCount, executionTimeMs }` shape returned by
/// `mongoEngine.findDocuments` in the React app.
class QueryResult {
  final List<MongoDocument> documents;
  final int totalCount;
  final double executionTimeMs;

  QueryResult({
    required this.documents,
    required this.totalCount,
    required this.executionTimeMs,
  });
}

class PipelineStage {
  final String id;
  String operator;
  String content;
  bool enabled;

  PipelineStage({
    required this.id,
    required this.operator,
    required this.content,
    this.enabled = true,
  });

  PipelineStage copyWith({
    String? operator,
    String? content,
    bool? enabled,
  }) {
    return PipelineStage(
      id: id,
      operator: operator ?? this.operator,
      content: content ?? this.content,
      enabled: enabled ?? this.enabled,
    );
  }
}

class SchemaFieldTypeStat {
  final String type;
  final int count;
  final int percentage;

  SchemaFieldTypeStat({
    required this.type,
    required this.count,
    required this.percentage,
  });
}

class SchemaFieldStat {
  final String name;
  final String path;
  final List<SchemaFieldTypeStat> types;
  final int totalValues;
  final int missingCount;
  final int missingPercentage;
  final int distinctCount;
  final List<dynamic> sampleValues;
  final dynamic min;
  final dynamic max;

  SchemaFieldStat({
    required this.name,
    required this.path,
    required this.types,
    required this.totalValues,
    required this.missingCount,
    required this.missingPercentage,
    required this.distinctCount,
    required this.sampleValues,
    this.min,
    this.max,
  });
}
