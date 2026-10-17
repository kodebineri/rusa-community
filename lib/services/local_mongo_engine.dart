import 'dart:convert';
import 'dart:math';

import '../models/mongo_models.dart';

/// Dart implementation of sample data and Mongo engine service
/// Mirrors src/services/sampleData.ts and mongoEngine.ts.
/// Local, in-memory implementation of the Mongo engine: the bundled sample
/// data plus all of the query, aggregation and mutation logic. It intentionally
/// mirrors the synchronous API of the React `mongoEngine` so the widgets can
/// read state during `build`; [RealMongoService] extends it to serve data from
/// an actual MongoDB server.
class LocalMongoEngine {
  /// The default engine, preloaded with the bundled sample datasets
  /// (`sample_mflix`, `sample_analytics`, `sample_supplies`).
  static final LocalMongoEngine instance = LocalMongoEngine.seeded();

  static final Random _random = Random();

  /// In-memory representation of the databases this engine serves.
  List<MongoDatabase> databases = [];

  LocalMongoEngine();

  /// Creates an engine preloaded with the bundled sample data.
  factory LocalMongoEngine.seeded() => LocalMongoEngine()..seedSampleData();

  void seedSampleData() {
    final movies = [
      MongoDocument.fromMap({
        '_id': '573a1390f29313caabcd42e8',
        'title': 'The Shawshank Redemption',
        'year': 1994,
        'rated': 'R',
        'runtime': 142,
        'genres': ['Drama', 'Crime'],
        'directors': ['Frank Darabont'],
        'imdb': {'rating': 9.3, 'votes': 2345890, 'id': 111161},
        'plot': 'Two imprisoned men bond over a number of years, finding solace and eventual redemption through acts of common decency.',
      }),
      MongoDocument.fromMap({
        '_id': '573a1390f29313caabcd43f1',
        'title': 'The Godfather',
        'year': 1972,
        'rated': 'R',
        'runtime': 175,
        'genres': ['Crime', 'Drama'],
        'directors': ['Francis Ford Coppola'],
        'imdb': {'rating': 9.2, 'votes': 1620384, 'id': 68646},
        'plot': 'The aging patriarch of an organized crime dynasty transfers control of his clandestine empire to his reluctant son.',
      }),
      MongoDocument.fromMap({
        '_id': '573a1390f29313caabcd44a2',
        'title': 'The Dark Knight',
        'year': 2008,
        'rated': 'PG-13',
        'runtime': 152,
        'genres': ['Action', 'Crime', 'Drama'],
        'directors': ['Christopher Nolan'],
        'imdb': {'rating': 9.0, 'votes': 2303232, 'id': 468569},
        'plot': 'When the menace known as the Joker wreaks havoc and chaos on the people of Gotham, Batman must accept one of the greatest psychological and physical tests of his ability to fight injustice.',
      }),
      MongoDocument.fromMap({
        '_id': '573a1390f29313caabcd45b9',
        'title': 'Pulp Fiction',
        'year': 1994,
        'rated': 'R',
        'runtime': 154,
        'genres': ['Crime', 'Drama'],
        'directors': ['Quentin Tarantino'],
        'imdb': {'rating': 8.9, 'votes': 1826188, 'id': 110912},
        'plot': 'The lives of two mob hitmen, a boxer, a gangster and his wife, and a pair of diner bandits intertwine in four tales of violence and redemption.',
      }),
      MongoDocument.fromMap({
        '_id': '573a1390f29313caabcd46cc',
        'title': 'Inception',
        'year': 2010,
        'rated': 'PG-13',
        'runtime': 148,
        'genres': ['Action', 'Adventure', 'Sci-Fi'],
        'directors': ['Christopher Nolan'],
        'imdb': {'rating': 8.8, 'votes': 2067042, 'id': 1375666},
        'plot': 'A thief who steals corporate secrets through the use of dream-sharing technology is given the inverse task of planting an idea into the mind of a C.E.O.',
      }),
    ];

    final comments = [
      MongoDocument.fromMap({
        '_id': '5a8d8c6b79da1eee4204d88a',
        'name': 'Mercedes Tyler',
        'email': 'mercedes_tyler@fakegmail.com',
        'movie_id': '573a1390f29313caabcd42e8',
        'text': 'One of the best cinematic experiences of all time!',
        'date': '2012-03-26T23:20:16.000Z',
      }),
      MongoDocument.fromMap({
        '_id': '5a8d8c6b79da1eee4204d88b',
        'name': 'John Doe',
        'email': 'john_doe@fakegmail.com',
        'movie_id': '573a1390f29313caabcd43f1',
        'text': 'A masterpiece of Italian-American cinema.',
        'date': '2015-08-14T11:05:42.000Z',
      }),
    ];

    final users = [
      MongoDocument.fromMap({
        '_id': '60b8d295f1d2c20015f8e001',
        'username': 'alex_smith',
        'email': 'alex@example.com',
        'role': 'admin',
        'active': true,
        'loginCount': 142,
      }),
      MongoDocument.fromMap({
        '_id': '60b8d295f1d2c20015f8e002',
        'username': 'sarah_connor',
        'email': 'sarah@example.com',
        'role': 'user',
        'active': true,
        'loginCount': 35,
      }),
    ];

    final supplies = [
      MongoDocument.fromMap({
        '_id': '5bd761dcae323e45a93ccfe8',
        'saleDate': '2015-03-23T21:06:49.506Z',
        'items': [
          {'name': 'binder', 'tags': ['school', 'general'], 'price': 14.15, 'quantity': 3},
          {'name': 'notepad', 'tags': ['office', 'writing'], 'price': 8.99, 'quantity': 5},
        ],
        'storeLocation': 'Denver',
        'customer': {'gender': 'M', 'age': 42, 'email': 'customer1@example.com', 'satisfaction': 4},
      }),
    ];

    databases = [
      MongoDatabase(
        name: 'sample_mflix',
        collections: {
          'movies': MongoCollection(
            name: 'movies',
            documents: movies,
            indexes: [
              MongoIndex(name: '_id_', keys: {'_id': 1}, unique: true),
              MongoIndex(name: 'title_text', keys: {'title': 'text'}),
              MongoIndex(name: 'year_1', keys: {'year': 1}),
            ],
          ),
          'comments': MongoCollection(
            name: 'comments',
            documents: comments,
            indexes: [
              MongoIndex(name: '_id_', keys: {'_id': 1}, unique: true),
              MongoIndex(name: 'movie_id_1', keys: {'movie_id': 1}),
            ],
          ),
        },
      ),
      MongoDatabase(
        name: 'sample_analytics',
        collections: {
          'users': MongoCollection(
            name: 'users',
            documents: users,
            indexes: [
              MongoIndex(name: '_id_', keys: {'_id': 1}, unique: true),
              MongoIndex(name: 'email_1', keys: {'email': 1}, unique: true),
            ],
          ),
        },
      ),
      MongoDatabase(
        name: 'sample_supplies',
        collections: {
          'sales': MongoCollection(
            name: 'sales',
            documents: supplies,
            indexes: [
              MongoIndex(name: '_id_', keys: {'_id': 1}, unique: true),
              MongoIndex(name: 'storeLocation_1', keys: {'storeLocation': 1}),
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
        if (parsed is Map) parsedFilter = parsed;
      }
      if (options.project.trim().isNotEmpty) {
        final parsed = tolerantParse(options.project);
        if (parsed is Map) parsedProject = parsed;
      }
      if (options.sort.trim().isNotEmpty) {
        final parsed = tolerantParse(options.sort);
        if (parsed is Map) parsedSort = parsed;
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

  List<SchemaFieldStat> analyzeSchema(String dbName, String collName) {
    final coll = getCollection(dbName, collName);
    if (coll == null || coll.documents.isEmpty) return [];

    final result = <SchemaFieldStat>[
      SchemaFieldStat(
        name: '_id',
        path: '_id',
        types: [SchemaFieldTypeStat(type: 'ObjectId', count: coll.documents.length, percentage: 100)],
        totalValues: coll.documents.length,
        missingCount: 0,
        missingPercentage: 0,
        distinctCount: coll.documents.length,
        sampleValues: coll.documents.take(3).map((d) => d.id).toList(),
      ),
      SchemaFieldStat(
        name: 'title',
        path: 'title',
        types: [SchemaFieldTypeStat(type: 'String', count: coll.documents.length, percentage: 100)],
        totalValues: coll.documents.length,
        missingCount: 0,
        missingPercentage: 0,
        distinctCount: coll.documents.length,
        sampleValues: coll.documents.take(3).map((d) => d['title']).toList(),
      ),
      SchemaFieldStat(
        name: 'year',
        path: 'year',
        types: [SchemaFieldTypeStat(type: 'Int32', count: coll.documents.length, percentage: 100)],
        totalValues: coll.documents.length,
        missingCount: 0,
        missingPercentage: 0,
        distinctCount: 4,
        sampleValues: [1972, 1994, 2008],
        min: 1972,
        max: 2010,
      ),
      SchemaFieldStat(
        name: 'genres',
        path: 'genres',
        types: [SchemaFieldTypeStat(type: 'Array', count: coll.documents.length, percentage: 100)],
        totalValues: coll.documents.length,
        missingCount: 0,
        missingPercentage: 0,
        distinctCount: 5,
        sampleValues: ['Drama', 'Crime', 'Action'],
      ),
    ];
    return result;
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
                '_id': generateObjectId(),
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

    final docs = _runPipeline(source.documents, pipeline, dbName);
    db.collections[clean] = MongoCollection(
      name: clean,
      documents: docs,
      indexes: [MongoIndex(name: '_id_', keys: {'_id': 1}, sizeKb: 0)],
      isView: true,
      viewOn: sourceCollName,
      pipeline: pipeline,
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

    final newMap = <String, dynamic>{...doc};
    newMap['_id'] = doc['_id'] ?? generateObjectId();

    for (final index in coll.indexes) {
      if (index.unique) {
        for (final existing in coll.documents) {
          final conflict = index.keys.keys.every((key) {
            final v1 = _resolvePath(existing.data, key);
            final v2 = _resolvePath(newMap, key);
            return v1 != null && v2 != null && v1 == v2;
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

    var finalMap = Map<String, dynamic>.from(coll.documents[index].data);
    if (updatedFields.containsKey('\$set')) {
      final setObj = updatedFields['\$set'] as Map;
      setObj.forEach((k, v) => _setPath(finalMap, k.toString(), v));
    } else if (updatedFields.containsKey('\$inc')) {
      final incObj = updatedFields['\$inc'] as Map;
      incObj.forEach((k, v) {
        final current = _asNum(_resolvePath(finalMap, k.toString()));
        _setPath(finalMap, k.toString(), current + _asNum(v));
      });
    } else if (updatedFields.containsKey('\$unset')) {
      final unsetObj = updatedFields['\$unset'] as Map;
      for (final k in unsetObj.keys) {
        _unsetPath(finalMap, k.toString());
      }
    } else {
      finalMap = {...finalMap, ...updatedFields, '_id': docId};
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
    final before = coll.documents.length;
    coll.documents.removeWhere((d) => _matchesFilter(d.data, filter));
    return before - coll.documents.length;
  }

  bool deleteOne(String dbName, String collName, Map filter) {
    final coll = getCollection(dbName, collName);
    if (coll == null || coll.isView) return false;
    final index = coll.documents.indexWhere((d) => _matchesFilter(d.data, filter));
    if (index == -1) return false;
    coll.documents.removeAt(index);
    return true;
  }

  int updateMany(String dbName, String collName, Map filter, Map update) {
    final coll = getCollection(dbName, collName);
    if (coll == null || coll.isView) return 0;
    var count = 0;
    for (var i = 0; i < coll.documents.length; i++) {
      final d = coll.documents[i];
      if (!_matchesFilter(d.data, filter)) continue;
      final map = Map<String, dynamic>.from(d.data);
      if (update.containsKey('\$set') && update['\$set'] is Map) {
        (update['\$set'] as Map).forEach((k, v) => _setPath(map, k.toString(), v));
      } else if (update.containsKey('\$inc') && update['\$inc'] is Map) {
        (update['\$inc'] as Map).forEach((k, v) {
          _setPath(map, k.toString(), _asNum(_resolvePath(map, k.toString())) + _asNum(v));
        });
      } else {
        for (final entry in update.entries) {
          if (!entry.key.toString().startsWith('\$')) {
            map[entry.key.toString()] = entry.value;
          }
        }
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
  /// unquoted keys and single-quoted strings).
  dynamic tolerantParse(String jsonStr) {
    if (jsonStr.trim().isEmpty) return {};
    final trimmed = jsonStr.trim();
    final cleaned = trimmed
        .replaceAllMapped(
          RegExp(r'([{,]\s*)([a-zA-Z0-9_$.]+)\s*:'),
          (m) => '${m[1]}"${m[2]}":',
        )
        .replaceAll("'", '"');
    try {
      return jsonDecode(cleaned);
    } catch (_) {
      return jsonDecode(trimmed);
    }
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
      final results = _runPipeline(coll.documents, pipeline, dbName);
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
              if (val != opVal) return false;
              break;
            case '\$ne':
              if (val == opVal) return false;
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
                  if (!val.any((item) => opVal.contains(item))) return false;
                } else if (!opVal.contains(val)) {
                  return false;
                }
              }
              break;
            case '\$nin':
              if (opVal is List) {
                if (val is List) {
                  if (val.any((item) => opVal.contains(item))) return false;
                } else if (opVal.contains(val)) {
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
          if (!val.contains(expected)) return false;
        } else if (val != expected) {
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
