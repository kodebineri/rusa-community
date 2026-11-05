import 'dart:convert';
import 'dart:math';

import '../models/mongo_models.dart';
import '../utils/mongo_json_parser.dart';

/// Dart implementation of sample data and Mongo engine service
/// Mirrors src/services/sampleData.ts and mongoEngine.ts.
/// Local, in-memory implementation of the Mongo engine: the bundled sample
/// data plus all of the query, aggregation and mutation logic. It intentionally
/// mirrors the synchronous API of the React `mongoEngine` so the widgets can
/// read state during `build`; [RealMongoService] extends it to serve data from
/// an actual MongoDB server.
class LocalMongoEngine {
  /// The default engine, preloaded with the bundled sample datasets
  /// (`library`, `social_networks`).
  static final LocalMongoEngine instance = LocalMongoEngine.seeded();

  static final Random _random = Random();

  /// In-memory representation of the databases this engine serves.
  List<MongoDatabase> databases = [];

  LocalMongoEngine();

  /// Creates an engine preloaded with the bundled sample data.
  factory LocalMongoEngine.seeded() => LocalMongoEngine()..seedSampleData();

  /// Seeds the bundled sample datasets from `sample_library.json` and
  /// `sample_social_network.json` in the repo root.
  ///
  /// The JSON files use MongoDB extended JSON (`{ "$oid": ... }`,
  /// `{ "$date": ... }`); here ObjectIds keep the BSON type ([MongoObjectId],
  /// built from the 24-char hex strings via [_typedSeedDocs]) and dates are
  /// ISO-8601 strings — the same shape [RealMongoService] applies to real
  /// server documents.
  /// The bundled JSON expresses ObjectIds as 24-char hex strings; the in-memory
  /// engine keeps the BSON type ([MongoObjectId]) instead, so the editors can
  /// show `ObjectId("...")` and distinguish it from a plain string.
  static List<MongoDocument> _typedSeedDocs(List<MongoDocument> docs) => [
        for (final doc in docs)
          MongoDocument.fromMap(_typedSeedValue(doc.data) as Map<String, dynamic>),
      ];

  static dynamic _typedSeedValue(dynamic value) {
    if (value is String &&
        value.length == 24 &&
        RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(value)) {
      return MongoObjectId(value);
    }
    if (value is Map) {
      return <String, dynamic>{
        for (final entry in value.entries)
          entry.key.toString(): _typedSeedValue(entry.value),
      };
    }
    if (value is List) return value.map(_typedSeedValue).toList();
    return value;
  }

  void seedSampleData() {
    final books = [
      MongoDocument.fromMap({
        '_id': '60c72b2f9b1d8b0015f8a001',
        'title': 'The Silent Horizon',
        'author': 'Elena Rostova',
        'isbn': '978-3-16-148410-0',
        'published_year': 2019,
        'publisher_id': '60c72b2f9b1d8b0015f8a010',
        'genre_ids': ['60c72b2f9b1d8b0015f8a020', '60c72b2f9b1d8b0015f8a021'],
        'copies_available': 4,
        'rating': 4.5,
      }),
      MongoDocument.fromMap({
        '_id': '60c72b2f9b1d8b0015f8a002',
        'title': 'Algorithms of the Mind',
        'author': 'Dr. Marcus Vance',
        'isbn': '978-1-23-456789-7',
        'published_year': 2022,
        'publisher_id': '60c72b2f9b1d8b0015f8a011',
        'genre_ids': ['60c72b2f9b1d8b0015f8a022'],
        'copies_available': 2,
        'rating': 4.8,
      }),
    ];

    final publishers = [
      MongoDocument.fromMap({
        '_id': '60c72b2f9b1d8b0015f8a010',
        'name': 'Apex Academic Press',
        'city': 'Boston',
        'country': 'USA',
        'founded_year': 1985,
      }),
      MongoDocument.fromMap({
        '_id': '60c72b2f9b1d8b0015f8a011',
        'name': 'Vanguard Publishing House',
        'city': 'London',
        'country': 'UK',
        'founded_year': 2001,
      }),
    ];

    final genres = [
      MongoDocument.fromMap({
        '_id': '60c72b2f9b1d8b0015f8a020',
        'name': 'Science Fiction',
        'description': 'Speculative fiction dealing with imaginative and futuristic concepts.',
      }),
      MongoDocument.fromMap({
        '_id': '60c72b2f9b1d8b0015f8a021',
        'name': 'Mystery',
        'description': 'Fiction revolving around the solution of a crime or secrets.',
      }),
      MongoDocument.fromMap({
        '_id': '60c72b2f9b1d8b0015f8a022',
        'name': 'Technology',
        'description': 'Non-fiction works discussing computing, artificial intelligence, and software.',
      }),
    ];

    final users = [
      MongoDocument.fromMap({
        '_id': '60c72b2f9b1d8b0015f8a030',
        'username': 'coder_sam',
        'email': 'samuel.dev@example.com',
        'profile': {
          'display_name': 'Sam Thorne',
          'bio': 'Building scalable systems and drinking espresso.',
          'location': 'Seattle, WA',
        },
        'followers_count': 342,
        'created_at': '2023-01-15T08:30:00.000Z',
      }),
      MongoDocument.fromMap({
        '_id': '60c72b2f9b1d8b0015f8a031',
        'username': 'design_maya',
        'email': 'maya.art@example.com',
        'profile': {
          'display_name': 'Maya Lin',
          'bio': 'UI/UX enthusiast and digital illustrator.',
          'location': 'Toronto, Canada',
        },
        'followers_count': 1280,
        'created_at': '2023-03-22T14:15:00.000Z',
      }),
    ];

    final posts = [
      MongoDocument.fromMap({
        '_id': '60c72b2f9b1d8b0015f8a040',
        'author_id': '60c72b2f9b1d8b0015f8a030',
        'content': 'Just deployed my first custom MongoDB aggregation pipeline! Loving the flexibility.',
        'tags': ['mongodb', 'database', 'backend'],
        'likes_count': 42,
        'created_at': '2023-10-01T10:00:00.000Z',
      }),
      MongoDocument.fromMap({
        '_id': '60c72b2f9b1d8b0015f8a041',
        'author_id': '60c72b2f9b1d8b0015f8a031',
        'content': "Minimalist design isn't about removing features—it's about removing friction.",
        'tags': ['design', 'ux', 'product'],
        'likes_count': 115,
        'created_at': '2023-10-02T16:45:00.000Z',
      }),
    ];

    final comments = [
      MongoDocument.fromMap({
        '_id': '60c72b2f9b1d8b0015f8a050',
        'post_id': '60c72b2f9b1d8b0015f8a040',
        'author_id': '60c72b2f9b1d8b0015f8a031',
        'text': 'Congrats Sam! Aggregation pipelines are a game changer once you get indexing right.',
        'created_at': '2023-10-01T10:15:00.000Z',
      }),
      MongoDocument.fromMap({
        '_id': '60c72b2f9b1d8b0015f8a051',
        'post_id': '60c72b2f9b1d8b0015f8a041',
        'author_id': '60c72b2f9b1d8b0015f8a030',
        'text': '100% agree. Simple interfaces hide complex engineering.',
        'created_at': '2023-10-02T17:05:00.000Z',
      }),
    ];

    databases = [
      MongoDatabase(
        name: 'library',
        collections: {
          'books': MongoCollection(
            name: 'books',
            documents: _typedSeedDocs(books),
            indexes: [
              MongoIndex(name: '_id_', keys: {'_id': 1}, unique: true),
              MongoIndex(name: 'isbn_1', keys: {'isbn': 1}, unique: true),
              MongoIndex(name: 'title_text', keys: {'title': 'text'}),
              MongoIndex(name: 'publisher_id_1', keys: {'publisher_id': 1}),
            ],
          ),
          'publishers': MongoCollection(
            name: 'publishers',
            documents: _typedSeedDocs(publishers),
            indexes: [
              MongoIndex(name: '_id_', keys: {'_id': 1}, unique: true),
              MongoIndex(name: 'name_1', keys: {'name': 1}),
            ],
          ),
          'genres': MongoCollection(
            name: 'genres',
            documents: _typedSeedDocs(genres),
            indexes: [
              MongoIndex(name: '_id_', keys: {'_id': 1}, unique: true),
              MongoIndex(name: 'name_1', keys: {'name': 1}),
            ],
          ),
        },
      ),
      MongoDatabase(
        name: 'social_networks',
        collections: {
          'users': MongoCollection(
            name: 'users',
            documents: _typedSeedDocs(users),
            indexes: [
              MongoIndex(name: '_id_', keys: {'_id': 1}, unique: true),
              MongoIndex(name: 'username_1', keys: {'username': 1}, unique: true),
              MongoIndex(name: 'email_1', keys: {'email': 1}, unique: true),
            ],
          ),
          'posts': MongoCollection(
            name: 'posts',
            documents: _typedSeedDocs(posts),
            indexes: [
              MongoIndex(name: '_id_', keys: {'_id': 1}, unique: true),
              MongoIndex(name: 'author_id_1', keys: {'author_id': 1}),
              MongoIndex(name: 'tags_1', keys: {'tags': 1}),
            ],
          ),
          'comments': MongoCollection(
            name: 'comments',
            documents: _typedSeedDocs(comments),
            indexes: [
              MongoIndex(name: '_id_', keys: {'_id': 1}, unique: true),
              MongoIndex(name: 'post_id_1', keys: {'post_id': 1}),
              MongoIndex(name: 'author_id_1', keys: {'author_id': 1}),
            ],
          ),
        },
      ),
    ];
  }

  List<MongoDatabase> getDatabases() => databases;

  MongoDatabase? getDatabase(String name) {
    try {
      return databases.firstWhere((d) => d.name == name);
    } catch (_) {
      return null;
    }
  }

  MongoCollection? getCollection(String dbName, String collName) {
    final db = getDatabase(dbName);
    return db?.collections[collName];
  }

  /// Executes a `find` against the mock engine, mirroring
  /// `mongoEngine.findDocuments`: filter -> sort -> skip/limit -> project.
  /// Returns the paginated page of documents along with the total match count.
  QueryResult findDocuments(String dbName, String collName, QueryFilterOptions options) {
    final coll = getCollection(dbName, collName);
    if (coll == null) {
      return QueryResult(documents: const [], totalCount: 0, executionTimeMs: 0);
    }

    Map parsedFilter = {};
    Map parsedProject = {};
    Map parsedSort = {};

    // Invalid partial JSON (e.g. the user is mid-typing "{") must never throw
    // out of a build. Mirror React's App-level catch: yield an empty result.
    try {
      if (options.filter.trim().isNotEmpty) {
        final parsed = tolerantParse(options.filter);
        if (parsed is Map) {
          parsedFilter = _normalizeExtendedJson(parsed) as Map;
        }
      }
      if (options.project.trim().isNotEmpty) {
        final parsed = tolerantParse(options.project);
        if (parsed is Map) {
          parsedProject = _normalizeExtendedJson(parsed) as Map;
        }
      }
      if (options.sort.trim().isNotEmpty) {
        final parsed = tolerantParse(options.sort);
        if (parsed is Map) {
          parsedSort = _normalizeExtendedJson(parsed) as Map;
        }
      }
    } catch (_) {
      return QueryResult(documents: const [], totalCount: 0, executionTimeMs: 0);
    }

    // 1. Filter
    var filtered = coll.documents.where((d) => _matchesFilter(d.data, parsedFilter)).toList();
    final totalCount = filtered.length;

    // 2. Sort
    if (parsedSort.isNotEmpty) {
      filtered = _sortDocs(filtered, parsedSort);
    }

    // 3. Skip & Limit
    final skip = options.skip < 0 ? 0 : options.skip;
    final limit = options.limit < 1 ? 1 : options.limit;
    final paginated = filtered.skip(skip).take(limit).toList();

    // 4. Project
    final projected = parsedProject.isNotEmpty
        ? paginated.map((d) => MongoDocument.fromMap(_applyProjection(d, parsedProject))).toList()
        : paginated;

    return QueryResult(
      documents: projected,
      totalCount: totalCount,
      executionTimeMs: 0.8,
    );
  }

  /// Computes per-field schema statistics for [collName] by scanning the
  /// in-memory documents (a generic stand-in for Compass's schema analysis,
  /// which works for any of the bundled collections).
  List<SchemaFieldStat> analyzeSchema(String dbName, String collName) {
    final coll = getCollection(dbName, collName);
    if (coll == null || coll.documents.isEmpty) return [];

    final docs = coll.documents;
    final total = docs.length;

    // Preserve first-seen field order across all documents.
    final fieldOrder = <String>[];
    for (final d in docs) {
      for (final key in d.data.keys) {
        if (!fieldOrder.contains(key)) fieldOrder.add(key);
      }
    }

    final result = <SchemaFieldStat>[];
    for (final field in fieldOrder) {
      final present = docs.map((d) => d.data[field]).where((v) => v != null).toList();
      final missing = total - present.length;

      final typeCounts = <String, int>{};
      for (final v in present) {
        final type = field == '_id' ? 'ObjectId' : _jsonTypeOf(v);
        typeCounts[type] = (typeCounts[type] ?? 0) + 1;
      }
      final types = typeCounts.entries
          .map((e) => SchemaFieldTypeStat(
                type: e.key,
                count: e.value,
                percentage: (e.value * 100) ~/ total,
              ))
          .toList();

      num? min;
      num? max;
      for (final v in present) {
        if (v is num) {
          if (min == null || v < min) min = v;
          if (max == null || v > max) max = v;
        }
      }

      result.add(SchemaFieldStat(
        name: field,
        path: field,
        types: types,
        totalValues: present.length,
        missingCount: missing,
        missingPercentage: (missing * 100) ~/ total,
        distinctCount: present.map((v) => jsonEncode(v)).toSet().length,
        sampleValues: present.take(3).toList(),
        min: min,
        max: max,
      ));
    }
    return result;
  }

  /// Maps a decoded JSON value to the BSON type name Compass would display.
  String _jsonTypeOf(dynamic v) {
    if (v is MongoObjectId) return 'ObjectId';
    if (v is String) return 'String';
    if (v is int) return 'Int32';
    if (v is double) return 'Double';
    if (v is bool) return 'Boolean';
    if (v is List) return 'Array';
    if (v is Map) return 'Object';
    return 'Null';
  }

  // ---------------------------------------------------------------------------
  // Mutations (ported from src/services/mongoEngine.ts)
  // ---------------------------------------------------------------------------

  void resetToDefaults() {
    seedSampleData();
  }

  String generateObjectId() {
    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toRadixString(16);
    final random = List.generate(16, (_) => _random.nextInt(16).toRadixString(16)).join();
    return (timestamp + random).substring(0, 24);
  }

  bool createDatabase(String dbName, [String initialCollName = 'users']) {
    if (getDatabase(dbName) != null) return false;
    databases.add(
      MongoDatabase(
        name: dbName,
        collections: {
          initialCollName: MongoCollection(
            name: initialCollName,
            documents: [
              MongoDocument.fromMap({
                '_id': MongoObjectId(generateObjectId()),
                'createdAt': DateTime.now().toIso8601String(),
                'name': 'Sample Item',
                'active': true,
              }),
            ],
            indexes: [MongoIndex(name: '_id_', keys: {'_id': 1})],
          ),
        },
      ),
    );
    return true;
  }

  bool dropDatabase(String dbName) {
    final before = databases.length;
    databases.removeWhere((d) => d.name == dbName);
    return databases.length < before;
  }

  bool createCollection(String dbName, String collName) {
    final db = getDatabase(dbName);
    if (db == null || db.collections.containsKey(collName)) return false;
    db.collections[collName] = MongoCollection(
      name: collName,
      documents: [],
      indexes: [MongoIndex(name: '_id_', keys: {'_id': 1})],
    );
    return true;
  }

  bool createView(
    String dbName,
    String viewName,
    String sourceCollName,
    List<dynamic> pipeline,
  ) {
    final db = getDatabase(dbName);
    if (db == null) throw Exception('Database "$dbName" not found');
    final clean = viewName.trim();
    if (clean.isEmpty) throw Exception('View name cannot be empty');
    if (clean.contains('\$') || clean.startsWith('.')) {
      throw Exception('Invalid view name: cannot contain "\$" or begin with "."');
    }
    if (db.collections.containsKey(clean)) {
      throw Exception('A collection or view named "$clean" already exists in database "$dbName"');
    }
    final source = db.collections[sourceCollName];
    if (source == null) {
      throw Exception('Source collection "$sourceCollName" does not exist in database "$dbName"');
    }

    final normalizedPipeline = _normalizeExtendedJson(pipeline) as List;
    final docs = _runPipeline(source.documents, normalizedPipeline, dbName);
    db.collections[clean] = MongoCollection(
      name: clean,
      documents: docs,
      indexes: [MongoIndex(name: '_id_', keys: {'_id': 1}, sizeKb: 0)],
      isView: true,
      viewOn: sourceCollName,
      pipeline: normalizedPipeline,
    );
    return true;
  }

  bool dropCollection(String dbName, String collName) {
    final db = getDatabase(dbName);
    if (db == null || !db.collections.containsKey(collName)) return false;
    db.collections.remove(collName);
    return true;
  }

  bool renameDatabase(String oldName, String newName) {
    final clean = newName.trim();
    if (clean.isEmpty) throw Exception('Database name cannot be empty');
    if (clean == oldName) return true;
    final db = getDatabase(oldName);
    if (db == null) throw Exception('Database "$oldName" not found');
    if (RegExp(r'[/\\. "\$*<>:|?]').hasMatch(clean)) {
      throw Exception('Database name cannot contain spaces or any of: / \\ . " \$ * < > : | ?');
    }
    if (clean.length > 63) throw Exception('Database name must be fewer than 64 characters');
    if (getDatabase(clean) != null) throw Exception('Database "$clean" already exists');

    final idx = databases.indexWhere((d) => d.name == oldName);
    databases[idx] = MongoDatabase(name: clean, collections: db.collections);
    return true;
  }

  bool renameCollection(String dbName, String oldName, String newName) {
    final db = getDatabase(dbName);
    if (db == null) throw Exception('Database "$dbName" not found');
    final clean = newName.trim();
    if (clean.isEmpty) throw Exception('Collection name cannot be empty');
    if (clean == oldName) return true;
    final coll = db.collections[oldName];
    if (coll == null) {
      throw Exception('Collection or view "$oldName" not found in database "$dbName"');
    }
    if (clean.contains('\$')) throw Exception('Collection names cannot contain the "\$" character');
    if (clean.startsWith('system.')) {
      throw Exception('Collection names cannot start with the "system." prefix');
    }
    if (db.collections.containsKey(clean)) {
      throw Exception('A collection or view named "$clean" already exists in database "$dbName"');
    }

    final renamed = <String, MongoCollection>{};
    db.collections.forEach((key, val) {
      if (key == oldName) {
        renamed[clean] = MongoCollection(
          name: clean,
          documents: val.documents,
          indexes: val.indexes,
          validator: val.validator,
          validationLevel: val.validationLevel,
          validationAction: val.validationAction,
          isView: val.isView,
          viewOn: val.viewOn,
          pipeline: val.pipeline,
        );
      } else {
        if (val.isView && val.viewOn == oldName) {
          val.viewOn = clean;
        }
        renamed[key] = val;
      }
    });
    db.collections
      ..clear()
      ..addAll(renamed);
    return true;
  }

  MongoDocument insertDocument(String dbName, String collName, Map<String, dynamic> doc) {
    final coll = getCollection(dbName, collName);
    if (coll == null) throw Exception('Collection not found');
    if (coll.isView) {
      throw Exception('Cannot insert document: "$collName" is a read-only MongoDB view.');
    }

    final newMap = <String, dynamic>{
      for (final entry in doc.entries)
        entry.key: _normalizeExtendedJson(entry.value),
    };
    // A user-supplied `_id` (string or ObjectId) is kept as typed; only a
    // missing `_id` gets a generated BSON ObjectId.
    newMap['_id'] = newMap['_id'] ?? MongoObjectId(generateObjectId());

    for (final index in coll.indexes) {
      if (index.unique) {
        for (final existing in coll.documents) {
          final conflict = index.keys.keys.every((key) {
            final v1 = _resolvePath(existing.data, key);
            final v2 = _resolvePath(newMap, key);
            return v1 != null &&
                v2 != null &&
                _sameValue(v1, v2, looseId: key == '_id');
          });
          if (conflict) {
            throw Exception(
              'E11000 duplicate key error collection: $dbName.$collName index: ${index.name}',
            );
          }
        }
      }
    }

    final newDoc = MongoDocument.fromMap(newMap);
    coll.documents.insert(0, newDoc);
    return newDoc;
  }

  bool updateDocument(
    String dbName,
    String collName,
    String docId,
    Map<String, dynamic> updatedFields,
  ) {
    final coll = getCollection(dbName, collName);
    if (coll == null) return false;
    if (coll.isView) {
      throw Exception('Cannot update document: "$collName" is a read-only MongoDB view.');
    }
    final index = coll.documents.indexWhere((d) => d.id == docId);
    if (index == -1) return false;

    final normalizedFields = <String, dynamic>{
      for (final entry in updatedFields.entries)
        entry.key: _normalizeExtendedJson(entry.value),
    };

    var finalMap = Map<String, dynamic>.from(coll.documents[index].data);
    if (normalizedFields.containsKey('\$set')) {
      final setObj = normalizedFields['\$set'] as Map;
      setObj.forEach((k, v) => _setPath(finalMap, k.toString(), v));
    } else if (normalizedFields.containsKey('\$inc')) {
      final incObj = normalizedFields['\$inc'] as Map;
      incObj.forEach((k, v) {
        final current = _asNum(_resolvePath(finalMap, k.toString()));
        _setPath(finalMap, k.toString(), current + _asNum(v));
      });
    } else if (normalizedFields.containsKey('\$unset')) {
      final unsetObj = normalizedFields['\$unset'] as Map;
      for (final k in unsetObj.keys) {
        _unsetPath(finalMap, k.toString());
      }
    } else {
      // A plain map is a full replacement (MongoDB semantics): the provided map
      // becomes the whole document, so fields omitted from it are removed.
      // `_id` is always preserved (keeping its BSON type, e.g. an ObjectId).
      finalMap = {
        ...normalizedFields,
        '_id': coll.documents[index].data['_id'] ?? docId,
      };
    }

    coll.documents[index] = MongoDocument.fromMap(finalMap);
    return true;
  }

  bool deleteDocument(String dbName, String collName, String docId) {
    final coll = getCollection(dbName, collName);
    if (coll == null) return false;
    if (coll.isView) {
      throw Exception('Cannot delete document: "$collName" is a read-only MongoDB view.');
    }
    final before = coll.documents.length;
    coll.documents.removeWhere((d) => d.id == docId);
    return coll.documents.length < before;
  }

  int deleteMany(String dbName, String collName, Map filter) {
    final coll = getCollection(dbName, collName);
    if (coll == null || coll.isView) return 0;
    final normalizedFilter = _normalizeExtendedJson(filter) as Map;
    final before = coll.documents.length;
    coll.documents.removeWhere((d) => _matchesFilter(d.data, normalizedFilter));
    return before - coll.documents.length;
  }

  bool deleteOne(String dbName, String collName, Map filter) {
    final coll = getCollection(dbName, collName);
    if (coll == null || coll.isView) return false;
    final normalizedFilter = _normalizeExtendedJson(filter) as Map;
    final index = coll.documents.indexWhere((d) => _matchesFilter(d.data, normalizedFilter));
    if (index == -1) return false;
    coll.documents.removeAt(index);
    return true;
  }

  int updateMany(String dbName, String collName, Map filter, Map update) {
    final coll = getCollection(dbName, collName);
    if (coll == null || coll.isView) return 0;
    final normalizedFilter = _normalizeExtendedJson(filter) as Map;
    final normalizedUpdate = _normalizeExtendedJson(update) as Map;
    var count = 0;
    for (var i = 0; i < coll.documents.length; i++) {
      final d = coll.documents[i];
      if (!_matchesFilter(d.data, normalizedFilter)) continue;
      late Map<String, dynamic> map;
      if (normalizedUpdate.containsKey('\$set') && normalizedUpdate['\$set'] is Map) {
        map = Map<String, dynamic>.from(d.data);
        (normalizedUpdate['\$set'] as Map).forEach((k, v) => _setPath(map, k.toString(), v));
      } else if (normalizedUpdate.containsKey('\$inc') && normalizedUpdate['\$inc'] is Map) {
        map = Map<String, dynamic>.from(d.data);
        (normalizedUpdate['\$inc'] as Map).forEach((k, v) {
          _setPath(map, k.toString(), _asNum(_resolvePath(map, k.toString())) + _asNum(v));
        });
      } else {
        // A plain map is a full replacement (MongoDB semantics): each matched
        // document becomes the provided map, so omitted fields are removed.
        // `_id` is always preserved.
        map = <String, dynamic>{
          for (final entry in normalizedUpdate.entries)
            if (!entry.key.toString().startsWith('\$'))
              entry.key.toString(): entry.value,
          '_id': d.data['_id'] ?? d.id,
        };
      }
      coll.documents[i] = MongoDocument.fromMap(map);
      count++;
    }
    return count;
  }

  bool createIndex(String dbName, String collName, MongoIndex index) {
    final coll = getCollection(dbName, collName);
    if (coll == null) return false;
    if (coll.indexes.any((i) => i.name == index.name)) return false;
    coll.indexes.add(
      MongoIndex(
        name: index.name,
        keys: index.keys,
        unique: index.unique,
        sparse: index.sparse,
        sizeKb: _random.nextInt(40) + 16,
      ),
    );
    return true;
  }

  bool dropIndex(String dbName, String collName, String indexName) {
    final coll = getCollection(dbName, collName);
    if (coll == null || indexName == '_id_') return false;
    final before = coll.indexes.length;
    coll.indexes.removeWhere((i) => i.name == indexName);
    return coll.indexes.length < before;
  }

  bool saveValidator(
    String dbName,
    String collName,
    Map<String, dynamic>? validator,
    String level,
    String action,
  ) {
    final coll = getCollection(dbName, collName);
    if (coll == null) return false;
    coll.validator = validator;
    coll.validationLevel = level;
    coll.validationAction = action;
    return true;
  }

  /// Tolerant JSON parser mirroring `mongoEngine.tolerantParse` (supports
  /// unquoted keys, single-quoted strings, and mongosh constructors such as
  /// `ObjectId("...")` / `ISODate("...")`).
  dynamic tolerantParse(String jsonStr) {
    if (jsonStr.trim().isEmpty) return {};
    final trimmed = jsonStr.trim();
    final preprocessed = preprocessMongoJson(trimmed);
    final cleaned = preprocessed
        .replaceAllMapped(
          RegExp(r'([{,]\s*)([a-zA-Z0-9_$.]+)\s*:'),
          (m) => '${m[1]}"${m[2]}":',
        )
        .replaceAll("'", '"');
    try {
      return jsonDecode(cleaned);
    } catch (_) {
      return jsonDecode(preprocessed);
    }
  }

  /// Converts Extended JSON wrappers (`{"$oid": ...}`, `{"$date": ...}`,
  /// `{"$timestamp": ...}`) into the values the in-memory mirror stores:
  /// ObjectIds keep their BSON type ([MongoObjectId]) and dates become ISO-8601
  /// strings. [RealMongoService] applies the same shape to server documents and
  /// reverses it when writing back.
  dynamic _normalizeExtendedJson(dynamic value) {
    if (value is Map) {
      if (value.length == 1) {
        if (value.containsKey(r'$oid')) {
          final oid = value[r'$oid'];
          if (oid is String) return MongoObjectId(oid);
        }
        if (value.containsKey(r'$date')) {
          final date = value[r'$date'];
          if (date is String) return date;
          if (date is int) {
            return DateTime.fromMillisecondsSinceEpoch(date).toIso8601String();
          }
        }
        if (value.containsKey(r'$timestamp')) {
          final ts = value[r'$timestamp'];
          if (ts is Map && ts['t'] is int) {
            return DateTime.fromMillisecondsSinceEpoch((ts['t'] as int) * 1000)
                .toIso8601String();
          }
        }
      }
      return <String, dynamic>{
        for (final entry in value.entries)
          entry.key.toString(): _normalizeExtendedJson(entry.value),
      };
    }
    if (value is List) {
      return value.map(_normalizeExtendedJson).toList();
    }
    return value;
  }

  // ---------------------------------------------------------------------------
  // Aggregation pipeline execution (used by views and aggregations view)
  // ---------------------------------------------------------------------------

  QueryResult runAggregation(String dbName, String collName, List<dynamic> pipeline) {
    final coll = getCollection(dbName, collName);
    if (coll == null) {
      return QueryResult(documents: const [], totalCount: 0, executionTimeMs: 0.0);
    }
    final stopwatch = Stopwatch()..start();
    try {
      final normalizedPipeline = _normalizeExtendedJson(pipeline) as List;
      final results = _runPipeline(coll.documents, normalizedPipeline, dbName);
      stopwatch.stop();
      return QueryResult(
        documents: results,
        totalCount: results.length,
        executionTimeMs: (stopwatch.elapsedMicroseconds / 1000.0).clamp(0.2, 9999.0),
      );
    } catch (_) {
      stopwatch.stop();
      rethrow;
    }
  }

  List<dynamic> parseAggregationScript(String script) {
    if (script.trim().isEmpty) return [];
    var cleaned = script.trim();
    final match = RegExp(r'\.aggregate\s*\(\s*(\[[\s\S]*\])\s*\);?\s*$').firstMatch(cleaned);
    if (match != null) {
      cleaned = match.group(1)!.trim();
    }
    final parsed = tolerantParse(cleaned);
    if (parsed is List) return parsed;
    if (parsed is Map) return [parsed];
    return [];
  }

  List<MongoDocument> _runPipeline(List<MongoDocument> docs, List<dynamic> pipeline, String dbName) {
    var current = docs
        .map((d) => MongoDocument(id: d.id, data: Map<String, dynamic>.from(d.data)))
        .toList();

    for (final rawStage in pipeline) {
      if (rawStage is! Map || rawStage.isEmpty) continue;
      final keys = rawStage.keys.map((k) => k.toString()).toList();
      final op = keys.firstWhere((k) => k.startsWith('\$'), orElse: () => keys.first);
      current = _applyStage(current, op, rawStage[op] ?? rawStage[keys.first], dbName);
    }
    return current;
  }

  List<MongoDocument> _applyStage(
    List<MongoDocument> docs,
    String operator,
    dynamic content,
    String dbName,
  ) {
    switch (operator) {
      case '\$lookup':
        if (content is Map) {
          final fromCollName = content['from']?.toString() ?? '';
          final localField = content['localField']?.toString() ?? '';
          final foreignField = content['foreignField']?.toString() ?? '';
          final asField = content['as']?.toString() ?? 'joined';
          final foreignColl = getCollection(dbName, fromCollName);
          final foreignDocs = foreignColl?.documents ?? [];

          return docs.map((d) {
            final localVal = _resolvePath(d.data, localField);
            final matches = foreignDocs
                .where((fd) => _resolvePath(fd.data, foreignField) == localVal)
                .map((fd) => Map<String, dynamic>.from(fd.data))
                .toList();
            final clone = Map<String, dynamic>.from(d.data);
            clone[asField] = matches;
            return MongoDocument.fromMap(clone);
          }).toList();
        }
        return docs;
      case '\$match':
        if (content is Map) {
          return docs.where((d) => _matchesFilter(d.data, content)).toList();
        }
        return docs;
      case '\$project':
        if (content is Map) {
          return docs.map((d) => MongoDocument.fromMap(_applyProjection(d, content))).toList();
        }
        return docs;
      case '\$sort':
        if (content is Map) return _sortDocs(docs, content);
        return docs;
      case '\$limit':
        final n = _asNum(content).toInt();
        return docs.take(n < 0 ? 0 : n).toList();
      case '\$skip':
        final n = _asNum(content).toInt();
        return docs.skip(n < 0 ? 0 : n).toList();
      case '\$count':
        final field = content is String ? content : 'count';
        return [MongoDocument.fromMap({field: docs.length})];
      case '\$addFields':
        if (content is Map) {
          return docs.map((d) {
            final clone = Map<String, dynamic>.from(d.data);
            content.forEach((k, v) {
              clone[k.toString()] =
                  (v is String && v.startsWith('\$')) ? _resolvePath(d.data, v.substring(1)) : v;
            });
            return MongoDocument.fromMap(clone);
          }).toList();
        }
        return docs;
      case '\$unwind':
        final path = (content is String
                ? content
                : (content is Map ? content['path']?.toString() ?? '' : ''))
            .replaceFirst(RegExp(r'^\$'), '');
        final preserve = content is Map && content['preserveNullAndEmptyArrays'] == true;
        final unrolled = <MongoDocument>[];
        for (final doc in docs) {
          final arr = _resolvePath(doc.data, path);
          if (arr is List && arr.isNotEmpty) {
            for (final item in arr) {
              final clone = Map<String, dynamic>.from(doc.data);
              _setPath(clone, path, item);
              unrolled.add(MongoDocument.fromMap(clone));
            }
          } else if (preserve) {
            unrolled.add(doc);
          }
        }
        return unrolled;
      case '\$group':
        if (content is Map) return _applyGroup(docs, content);
        return docs;
      default:
        return docs;
    }
  }

  List<MongoDocument> _applyGroup(List<MongoDocument> docs, Map content) {
    final idExpr = content['_id'];
    final groups = <String, List<MongoDocument>>{};

    for (final doc in docs) {
      String key = 'null';
      if (idExpr is String && idExpr.startsWith('\$')) {
        key = '${_resolvePath(doc.data, idExpr.substring(1))}';
      } else if (idExpr == null) {
        key = 'null';
      } else if (idExpr is Map) {
        key = jsonEncode(idExpr);
      }
      groups.putIfAbsent(key, () => []).add(doc);
    }

    final result = <MongoDocument>[];
    groups.forEach((key, groupDocs) {
      final out = <String, dynamic>{};
      if (idExpr == null) {
        out['_id'] = null;
      } else if (idExpr is String && idExpr.startsWith('\$')) {
        out['_id'] = _resolvePath(groupDocs.first.data, idExpr.substring(1));
      } else {
        out['_id'] = key;
      }

      content.forEach((field, accExpr) {
        if (field == '_id' || accExpr is! Map || accExpr.isEmpty) return;
        final accOp = accExpr.keys.first.toString();
        final exprVal = accExpr[accOp];
        final path = (exprVal is String && exprVal.startsWith('\$')) ? exprVal.substring(1) : '';

        switch (accOp) {
          case '\$sum':
            if (exprVal is num) {
              out[field.toString()] = groupDocs.length * exprVal;
            } else if (path.isNotEmpty) {
              out[field.toString()] =
                  groupDocs.fold<num>(0, (acc, d) => acc + _asNum(_resolvePath(d.data, path)));
            }
            break;
          case '\$avg':
            if (path.isNotEmpty) {
              final total =
                  groupDocs.fold<num>(0, (acc, d) => acc + _asNum(_resolvePath(d.data, path)));
              out[field.toString()] = groupDocs.isEmpty ? 0 : total / groupDocs.length;
            }
            break;
          case '\$min':
          case '\$max':
            final vals =
                groupDocs.map((d) => _resolvePath(d.data, path)).where((v) => v != null).toList();
            if (vals.isNotEmpty) {
              vals.sort((a, b) => _compare(a, b) ?? 0);
              out[field.toString()] = accOp == '\$min' ? vals.first : vals.last;
            }
            break;
          case '\$push':
            out[field.toString()] = groupDocs.map((d) => _resolvePath(d.data, path)).toList();
            break;
          case '\$first':
            out[field.toString()] = groupDocs.isEmpty ? null : _resolvePath(groupDocs.first.data, path);
            break;
        }
      });

      result.add(MongoDocument.fromMap(out));
    });
    return result;
  }

  bool _matchesFilter(Map<String, dynamic> doc, Map filter) {
    if (filter.isEmpty) return true;

    for (final entry in filter.entries) {
      final key = entry.key.toString();
      final expected = entry.value;

      if (key == '\$and') {
        if (expected is List && !expected.every((s) => s is Map && _matchesFilter(doc, s))) {
          return false;
        }
        continue;
      }
      if (key == '\$or') {
        if (expected is List && !expected.any((s) => s is Map && _matchesFilter(doc, s))) {
          return false;
        }
        continue;
      }
      if (key == '\$nor') {
        if (expected is List && expected.any((s) => s is Map && _matchesFilter(doc, s))) {
          return false;
        }
        continue;
      }

      final val = _resolvePath(doc, key);

      if (expected is Map) {
        for (final opEntry in expected.entries) {
          final op = opEntry.key.toString();
          final opVal = opEntry.value;
          switch (op) {
            case '\$eq':
              if (!_sameValue(val, opVal, looseId: key == '_id')) return false;
              break;
            case '\$ne':
              if (_sameValue(val, opVal, looseId: key == '_id')) return false;
              break;
            case '\$gt':
              final c = _compare(val, opVal);
              if (c == null || c <= 0) return false;
              break;
            case '\$gte':
              final c = _compare(val, opVal);
              if (c == null || c < 0) return false;
              break;
            case '\$lt':
              final c = _compare(val, opVal);
              if (c == null || c >= 0) return false;
              break;
            case '\$lte':
              final c = _compare(val, opVal);
              if (c == null || c > 0) return false;
              break;
            case '\$in':
              if (opVal is List) {
                if (val is List) {
                  if (!val.any((item) =>
                      _anySameValue(opVal, item, looseId: key == '_id'))) {
                    return false;
                  }
                } else if (!_anySameValue(opVal, val, looseId: key == '_id')) {
                  return false;
                }
              }
              break;
            case '\$nin':
              if (opVal is List) {
                if (val is List) {
                  if (val.any((item) =>
                      _anySameValue(opVal, item, looseId: key == '_id'))) {
                    return false;
                  }
                } else if (_anySameValue(opVal, val, looseId: key == '_id')) {
                  return false;
                }
              }
              break;
            case '\$exists':
              final exists = val != null;
              if (exists != (opVal == true)) return false;
              break;
            case '\$regex':
              final options = expected['\$options']?.toString() ?? 'i';
              final regex = RegExp(opVal.toString(), caseSensitive: options != 'i');
              if (!regex.hasMatch('${val ?? ''}')) return false;
              break;
            case '\$size':
              if (val is! List || val.length != _asNum(opVal).toInt()) return false;
              break;
          }
        }
      } else {
        if (val is List) {
          if (!val.any((item) => _sameValue(item, expected, looseId: key == '_id'))) {
            return false;
          }
        } else if (!_sameValue(val, expected, looseId: key == '_id')) {
          return false;
        }
      }
    }
    return true;
  }

  Map<String, dynamic> _applyProjection(MongoDocument doc, Map proj) {
    final isExclusive = proj.values.any((v) => v == 0);
    final result = isExclusive ? Map<String, dynamic>.from(doc.data) : <String, dynamic>{};

    if (proj['_id'] == 0) {
      result.remove('_id');
    } else if (doc.data['_id'] != null) {
      result['_id'] = doc.data['_id'];
    }

    if (isExclusive) {
      proj.forEach((k, v) {
        if (v == 0) result.remove(k.toString());
      });
    } else {
      proj.forEach((k, v) {
        if (v == 1 && k.toString() != '_id') {
          result[k.toString()] = _resolvePath(doc.data, k.toString());
        }
      });
    }
    return result;
  }

  List<MongoDocument> _sortDocs(List<MongoDocument> docs, Map sortSpec) {
    final keys = sortSpec.keys.map((k) => k.toString()).toList();
    final sorted = List<MongoDocument>.from(docs);
    sorted.sort((a, b) {
      for (final key in keys) {
        final order = _asNum(sortSpec[key]);
        final valA = _resolvePath(a.data, key);
        final valB = _resolvePath(b.data, key);
        if (valA == valB) continue;
        if (valA == null) return 1;
        if (valB == null) return -1;
        final c = _compare(valA, valB) ?? 0;
        if (c != 0) return order < 0 ? -c : c;
      }
      return 0;
    });
    return sorted;
  }

  // ---------------------------------------------------------------------------
  // Internal utilities
  // ---------------------------------------------------------------------------

  num _asNum(dynamic value) {
    if (value is num) return value;
    if (value is bool) return value ? 1 : 0;
    return num.tryParse('$value') ?? 0;
  }

  int? _compare(dynamic a, dynamic b) {
    if (a is num && b is num) return a.compareTo(b);
    if (a is String && b is String) return a.compareTo(b);
    if (a is Comparable) {
      try {
        return a.compareTo(b);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Equality used by the filter matcher.
  ///
  /// For `_id`, a hex string and an [MongoObjectId] with the same value compare
  /// equal, so the app's string-based id lookups keep working. For every other
  /// field the types must match, which is what keeps a string field distinct
  /// from an ObjectId field.
  bool _sameValue(dynamic a, dynamic b, {required bool looseId}) {
    if (a == b) return true;
    if (looseId) {
      final sa = a?.toString();
      final sb = b?.toString();
      if (sa != null && sb != null && sa == sb) return true;
    }
    return false;
  }

  bool _anySameValue(List candidates, dynamic value, {required bool looseId}) =>
      candidates.any((candidate) => _sameValue(candidate, value, looseId: looseId));

  dynamic _resolvePath(dynamic obj, String path) {
    if (obj == null || path.isEmpty) return null;
    dynamic cur = obj;
    for (final part in path.split('.')) {
      if (cur == null) return null;
      if (cur is Map) {
        cur = cur[part];
      } else if (cur is List) {
        final i = int.tryParse(part);
        cur = (i != null && i >= 0 && i < cur.length) ? cur[i] : null;
      } else {
        return null;
      }
    }
    return cur;
  }

  void _setPath(Map<String, dynamic> obj, String path, dynamic val) {
    final parts = path.split('.');
    dynamic cur = obj;
    for (var i = 0; i < parts.length - 1; i++) {
      final p = parts[i];
      if (cur[p] is! Map) cur[p] = <String, dynamic>{};
      cur = cur[p];
    }
    cur[parts.last] = val;
  }

  void _unsetPath(Map<String, dynamic> obj, String path) {
    final parts = path.split('.');
    dynamic cur = obj;
    for (var i = 0; i < parts.length - 1; i++) {
      if (cur[parts[i]] is! Map) return;
      cur = cur[parts[i]];
    }
    cur.remove(parts.last);
  }
}
