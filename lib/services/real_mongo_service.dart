import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:mongo_dart/mongo_dart.dart' as mdb;

import '../models/mongo_models.dart';
import 'local_mongo_engine.dart';

/// A [LocalMongoEngine] backed by an actual MongoDB server.
///
/// The widgets read state synchronously (during `build`), so on connect this
/// service mirrors the server into the inherited in-memory [`databases`] list
/// (databases → collections → documents/indexes). All reads then run against
/// that mirror, while every mutation is additionally replayed against the
/// server (fire-and-forget).
///
/// Documents are normalised into JSON-friendly values (`ObjectId` → hex string,
/// `DateTime` → ISO string, binaries → base64) so the existing views can render
/// them with `jsonEncode`.
class RealMongoService extends LocalMongoEngine {
  RealMongoService._(this.uri, this._primary) {
    final primaryDb = _primary.databaseName;
    if (primaryDb != null && primaryDb.isNotEmpty) {
      _handles[primaryDb] = _primary;
    }
  }

  /// Maximum number of documents mirrored per collection during the eager
  /// background load, to keep very large collections from freezing the UI.
  /// When the user opens a collection, up to [maxDocsWhenOpened] are loaded.
  static const int maxDocsPerCollection = 5000;

  /// Cap for the on-demand load performed when the user opens a collection.
  static const int maxDocsWhenOpened = 50000;

  final String uri;
  final mdb.Db _primary;

  /// One connection handle per (non-system) database.
  final Map<String, mdb.Db> _handles = {};

  /// Invoked when the mirror changes after the initial load (e.g. after a
  /// server-side reload) so the UI can `setState`.
  void Function()? onDataChanged;

  /// Invoked with a human-readable message when a background server operation
  /// fails.
  void Function(String message)? onError;

  /// The most recent background error, if any.
  String? lastError;

  bool _disposed = false;

  /// Quick connectivity test without mirroring all collections/documents.
  static Future<void> test(String uri) async {
    final trimmed = uri.trim();
    final safeUri = _ensureDbPath(trimmed);
    final primary = await mdb.Db.create(safeUri);
    try {
      await primary.open().timeout(const Duration(seconds: 15));
      try {
        await primary.pingCommand().timeout(const Duration(seconds: 5));
      } catch (_) {
        await primary.listDatabases().timeout(const Duration(seconds: 5));
      }
    } finally {
      try {
        await primary.close();
      } catch (_) {}
    }
  }

  /// Connects to [uri], verifies the server is reachable, then mirrors it.
  ///
  /// Throws (with the driver error) when the URI is invalid, the server is
  /// unreachable, or authentication fails.
  static Future<RealMongoService> connect(String uri) async {
    final trimmed = uri.trim();
    final safeUri = _ensureDbPath(trimmed);
    final primary = await mdb.Db.create(safeUri);
    try {
      await primary.open().timeout(const Duration(seconds: 20));
    } catch (e) {
      try {
        await primary.close();
      } catch (_) {}
      rethrow;
    }

    final service = RealMongoService._(trimmed, primary);
    try {
      await service.reloadFast().timeout(const Duration(seconds: 20));
    } catch (e) {
      try {
        await service.dispose();
      } catch (_) {}
      rethrow;
    }
    return service;
  }

  /// Fast reload: list databases and collection names immediately so the UI
  /// tree is accurate right away. Documents are **not** preloaded (that was
  /// memory-heavy); they load only when the user opens a collection. A cheap
  /// per-collection `count()` is fetched so the sidebar can show real counts.
  Future<void> reloadFast() async {
    try {
      final names = await _primary.listDatabases().timeout(const Duration(seconds: 10));
      final result = <MongoDatabase>[];
      final dbNames = <String>[];

      for (final raw in names) {
        String dbName = '';
        if (raw is Map) {
          dbName = raw['name']?.toString() ?? raw.toString();
        } else if (raw is String) {
          dbName = raw;
        } else {
          dbName = raw.toString();
        }
        if (dbName.isEmpty || dbName.startsWith('{')) {
          // Fallback attempt to extract name from string representation
          final match = RegExp(r'name\s*:\s*([^\s,}]+)').firstMatch(dbName);
          if (match != null) {
            dbName = match.group(1)!;
          } else {
            continue;
          }
        }
        if (dbName.isEmpty) continue;
        dbNames.add(dbName);
      }

      // Create DB entries immediately with empty collections; names and counts
      // are filled in the background.
      for (final dbName in dbNames) {
        result.add(MongoDatabase(name: dbName, collections: const {}));
      }

      databases = result;
      if (!_disposed) onDataChanged?.call();

      // List collection names in the background. Counts are fetched lazily,
      // only for a database the user expands (or the collection they open), so
      // connecting never pre-counts or pre-loads every collection.
      unawaited(_loadCollectionsFast(dbNames));
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _loadCollectionsFast(List<String> dbNames) async {
    if (_disposed) return;
    for (final dbName in dbNames) {
      if (_disposed) break;
      try {
        final infos = await _getCollectionInfos(dbName).timeout(const Duration(seconds: 5));
        final colls = <String, MongoCollection>{};
        for (final info in infos) {
          final collName = info['name']?.toString() ?? '';
          if (collName.isEmpty || collName.startsWith('system.')) continue;
          final isView = info['type']?.toString() == 'view';
          final options = info['options'];
          final optionsMap = options is Map
              ? options.map((k, v) => MapEntry(k.toString(), v))
              : const <String, dynamic>{};
          colls[collName] = MongoCollection(
            name: collName,
            documents: const [],
            indexes: [MongoIndex(name: '_id_', keys: const {'_id': 1})],
            isView: isView,
            viewOn: isView ? optionsMap['viewOn']?.toString() : null,
            pipeline: isView ? (optionsMap['pipeline'] as List?)?.toList() : null,
          );
        }
        final idx = databases.indexWhere((d) => d.name == dbName);
        if (idx >= 0 && !_disposed && databases[idx].collections.isEmpty) {
          databases[idx] = MongoDatabase(name: dbName, collections: colls);
          onDataChanged?.call();
        }
      } catch (_) {
        continue;
      }
    }
  }

  /// Retrieves collection metadata for [dbName].
  ///
  /// Uses `modernListCollections` targeting `$db: dbName` on the existing
  /// primary connection if possible (fastest: 0 extra connection overhead),
  /// falling back to a dedicated database handle.
  Future<List<Map<String, dynamic>>> _getCollectionInfos(String dbName) async {
    try {
      if (_primary.masterConnection.serverCapabilities.supportsOpMsg) {
        final stream = _primary.modernListCollections(rawOptions: {'dbName': dbName});
        return await stream.toList().timeout(const Duration(seconds: 6));
      }
    } catch (_) {
      // Fallback below
    }

    final dbHandle = await _openDb(dbName);
    return await dbHandle.getCollectionInfos().timeout(const Duration(seconds: 8));
  }

  /// Fetches the server's document count for every collection in [dbName].
  ///
  /// Called when the user expands a database (and after opening a collection),
  /// so counts are never pre-fetched for the whole server at connect time.
  Future<void> loadCollectionCounts(String dbName) async {
    if (_disposed) return;
    // Skip system databases to prevent slow scans or permission errors
    if (dbName == 'admin' || dbName == 'config' || dbName == 'local') return;

    final db = getDatabase(dbName);
    if (db == null) return;

    mdb.Db dbHandle;
    try {
      dbHandle = await _openDb(dbName);
    } catch (_) {
      return;
    }
    if (_disposed) return;

    var changed = false;
    for (final coll in List<MongoCollection>.from(db.collections.values)) {
      if (_disposed) break;
      try {
        final count = await dbHandle
            .collection(coll.name)
            .count()
            .timeout(const Duration(seconds: 15));
        coll.documentCount = count;
        changed = true;
      } catch (_) {
        // Leave the count unknown; the sidebar shows a placeholder.
      }
    }
    if (changed && !_disposed) onDataChanged?.call();
  }

  /// Loads documents and indexes for a specific collection on-demand.
  Future<void> loadCollectionData(String dbName, String collName) async {
    final coll = getCollection(dbName, collName);
    if (coll == null) return;
    final showSpinner = coll.documents.isEmpty;
    if (showSpinner && !coll.isLoading) {
      coll.isLoading = true;
      if (!_disposed) onDataChanged?.call();
    }
    try {
      final dbHandle = await _openDb(dbName);
      final c = dbHandle.collection(collName);
      final docs = await _loadDocuments(c, limit: maxDocsWhenOpened)
          .timeout(const Duration(seconds: 30));
      final indexes = coll.isView
          ? [MongoIndex(name: '_id_', keys: const {'_id': 1})]
          : await _loadIndexes(c).timeout(const Duration(seconds: 8));
      final count = await _loadDocumentCount(c);

      coll.documents = docs;
      coll.indexes = indexes;
      coll.documentCount = count ?? coll.documentCount;
      coll.isLoading = false;
      if (!_disposed) onDataChanged?.call();
    } catch (_) {
      coll.isLoading = false;
      if (!_disposed) onDataChanged?.call();
    }
  }

  /// Re-reads every database, collection, document and index from the server.
  Future<void> reload() async {
    final names = await _primary.listDatabases().timeout(const Duration(seconds: 15));
    final result = <MongoDatabase>[];

    for (final raw in names) {
      String dbName = '';
      if (raw is Map) {
        dbName = raw['name']?.toString() ?? raw.toString();
      } else if (raw is String) {
        dbName = raw;
      } else {
        dbName = raw.toString();
      }
      if (dbName.isEmpty || dbName.startsWith('{')) {
        final match = RegExp(r'name\s*:\s*([^\s,}]+)').firstMatch(dbName);
        if (match != null) {
          dbName = match.group(1)!;
        } else {
          continue;
        }
      }
      if (dbName.isEmpty) continue;
      try {
        final db = await _openDb(dbName);
        final infos = await _getCollectionInfos(dbName).timeout(const Duration(seconds: 15));
        final colls = <String, MongoCollection>{};

        for (final info in infos) {
          final collName = info['name']?.toString() ?? '';
          if (collName.isEmpty || collName.startsWith('system.')) continue;

          final isView = info['type']?.toString() == 'view';
          final options = info['options'];
          final optionsMap = options is Map
              ? options.map((k, v) => MapEntry(k.toString(), v))
              : const <String, dynamic>{};

          try {
            final coll = db.collection(collName);
            final docs = await _loadDocuments(coll);
            final indexes = isView
                ? [MongoIndex(name: '_id_', keys: const {'_id': 1})]
                : await _loadIndexes(coll);
            final count = await _loadDocumentCount(coll);

            colls[collName] = MongoCollection(
              name: collName,
              documents: docs,
              indexes: indexes,
              isView: isView,
              viewOn: isView ? optionsMap['viewOn']?.toString() : null,
              pipeline: isView ? (optionsMap['pipeline'] as List?)?.toList() : null,
              documentCount: count,
            );
          } catch (_) {
            colls[collName] = MongoCollection(
              name: collName,
              documents: const [],
              indexes: [MongoIndex(name: '_id_', keys: const {'_id': 1})],
              isView: isView,
              viewOn: isView ? optionsMap['viewOn']?.toString() : null,
              pipeline: isView ? (optionsMap['pipeline'] as List?)?.toList() : null,
            );
          }
        }

        result.add(MongoDatabase(name: dbName, collections: colls));
      } catch (_) {
        result.add(MongoDatabase(name: dbName, collections: const {}));
      }
    }

    databases = result;
  }

  /// Closes every server connection.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final db in _handles.values) {
      if (!identical(db, _primary)) {
        try {
          await db.close();
        } catch (_) {/* ignore */}
      }
    }
    _handles.clear();
    try {
      await _primary.close();
    } catch (_) {/* ignore */}
  }

  // ---------------------------------------------------------------------------
  // Loading helpers
  // ---------------------------------------------------------------------------

  Future<mdb.Db> _openDb(String dbName) async {
    final existing = _handles[dbName];
    if (existing != null) return existing;

    if (_primary.databaseName == dbName) {
      _handles[dbName] = _primary;
      return _primary;
    }

    // Try opening via primary's resolved URIs with target database path.
    // _primary.uriList already contains resolved 'mongodb://' URIs (even for mongodb+srv),
    // so no DNS seedlist lookup is needed again.
    final uris = _primary.uriList.map((u) => _withDatabase(u, dbName)).toList();
    if (uris.isNotEmpty) {
      try {
        final db = uris.length > 1 ? mdb.Db.pool(uris) : mdb.Db(uris.first);
        await db.open().timeout(const Duration(seconds: 15));
        _handles[dbName] = db;
        return db;
      } catch (_) {
        // Fallback below
      }
    }

    // Fallback: If uri is SRV or standard, create and open
    final dbUri = _withDatabase(uri, dbName);
    final db = await mdb.Db.create(dbUri);
    await db.open().timeout(const Duration(seconds: 15));
    _handles[dbName] = db;
    return db;
  }

  Future<List<MongoDocument>> _loadDocuments(
    mdb.DbCollection coll, {
    int limit = maxDocsPerCollection,
  }) async {
    final docs = <MongoDocument>[];
    final stream = coll.find(mdb.where.limit(limit));
    await for (final raw in stream) {
      docs.add(MongoDocument.fromMap(_normalizeMap(raw)));
      if (docs.length >= limit) break;
    }
    return docs;
  }

  /// The server's total document count for [coll], or null if it can't be read.
  Future<int?> _loadDocumentCount(mdb.DbCollection coll) async {
    try {
      return await coll.count().timeout(const Duration(seconds: 10));
    } catch (_) {
      return null;
    }
  }

  Future<List<MongoIndex>> _loadIndexes(mdb.DbCollection coll) async {
    try {
      final raw = await coll.getIndexes();
      return raw.map((m) {
        final key = m['key'];
        final keys = key is Map
            ? key.map((k, v) => MapEntry(k.toString(), v))
            : <String, dynamic>{};
        return MongoIndex(
          name: m['name']?.toString() ?? '',
          keys: keys,
          unique: m['unique'] == true,
          sparse: m['sparse'] == true,
        );
      }).toList();
    } catch (_) {
      return [MongoIndex(name: '_id_', keys: const {'_id': 1})];
    }
  }

  // ---------------------------------------------------------------------------
  // Mutations → also applied to the server
  // ---------------------------------------------------------------------------

  @override
  MongoDocument insertDocument(String dbName, String collName, Map<String, dynamic> doc) {
    final inserted = super.insertDocument(dbName, collName, doc);
    // Send the *original* values (including `{"$oid": ...}` wrappers) so the
    // server stores real ObjectIds; a string `_id` is left as a string.
    final serverDoc = _denormalizeDoc(<String, dynamic>{
      ...doc,
      '_id': doc['_id'] ?? inserted.data['_id'],
    });
    _fireCollection(dbName, collName, (c) => c.insertOne(serverDoc));
    return inserted;
  }

  @override
  bool updateDocument(
    String dbName,
    String collName,
    String docId,
    Map<String, dynamic> updatedFields,
  ) {
    final ok = super.updateDocument(dbName, collName, docId, updatedFields);
    if (!ok) return false;
    // Preserve the `_id` type of the stored document: a string `_id` stays a
    // string even if it looks like a 24-char hex ObjectId.
    final serverId = _serverId(dbName, collName, docId);
    final hasOperator =
        updatedFields.keys.any((k) => k.toString().startsWith(r'$'));
    if (hasOperator) {
      _fireCollection(
        dbName,
        collName,
        (c) => c.updateOne({'_id': serverId}, _toServerUpdate(updatedFields)),
      );
    } else {
      // A plain map is a full replacement, so fields omitted from it are
      // removed on the server too (matching the local mirror).
      final replacement = _denormalizeDoc({...updatedFields, '_id': serverId});
      replacement['_id'] = serverId;
      _fireCollection(
        dbName,
        collName,
        (c) => c.replaceOne({'_id': serverId}, replacement),
      );
    }
    return true;
  }

  @override
  bool deleteDocument(String dbName, String collName, String docId) {
    // Resolve the server id *before* the mirror document is removed.
    final serverId = _serverId(dbName, collName, docId);
    final ok = super.deleteDocument(dbName, collName, docId);
    if (ok) {
      _fireCollection(dbName, collName, (c) => c.deleteOne({'_id': serverId}));
    }
    return ok;
  }

  @override
  bool deleteOne(String dbName, String collName, Map filter) {
    // Resolve the filter against the mirror *before* it is mutated.
    final serverFilter = _denormalizeFilter(dbName, collName, filter);
    final ok = super.deleteOne(dbName, collName, filter);
    if (ok) {
      _fireCollection(dbName, collName, (c) => c.deleteOne(serverFilter));
    }
    return ok;
  }

  @override
  int deleteMany(String dbName, String collName, Map filter) {
    final serverFilter = _denormalizeFilter(dbName, collName, filter);
    final removed = super.deleteMany(dbName, collName, filter);
    if (removed > 0) {
      _fireCollection(dbName, collName, (c) => c.deleteMany(serverFilter));
    }
    return removed;
  }

  @override
  int updateMany(String dbName, String collName, Map filter, Map update) {
    final hasOperator = update.keys.any((k) => k.toString().startsWith(r'$'));

    // Resolve everything that depends on the mirror *before* it is mutated.
    final serverFilter = _denormalizeFilter(dbName, collName, filter);

    // For a replacement update, capture the matching ids *before* the mirror is
    // mutated: replacing can change the field the filter matched on, so a later
    // re-query could otherwise miss documents.
    final targetIds = hasOperator
        ? const <String>[]
        : findDocuments(
                dbName,
                collName,
                QueryFilterOptions(
                  filter: jsonEncode(filter),
                  limit: 1000000000,
                ),
              )
            .documents
            .map((d) => d.id)
            .toList(growable: false);
    // Resolve each id's server representation now, while the mirror still holds
    // the original `_id` type.
    final serverIdByTarget = <String, Object>{
      for (final id in targetIds) id: _serverId(dbName, collName, id),
    };

    final count = super.updateMany(dbName, collName, filter, update);
    if (count == 0) return count;

    if (hasOperator) {
      _fireCollection(
        dbName,
        collName,
        (c) => c.updateMany(serverFilter, _toServerUpdate(update)),
      );
    } else {
      // A plain map is a full replacement: replay one `replaceOne` per matched
      // document so fields omitted from the replacement are removed on the
      // server too (matching the local mirror).
      for (final id in targetIds) {
        final serverId = serverIdByTarget[id] ?? _toObjectId(id);
        final replacement = _denormalizeDoc(<String, dynamic>{
          for (final entry in update.entries) entry.key.toString(): entry.value,
          '_id': serverId,
        });
        replacement['_id'] = serverId;
        _fireCollection(
          dbName,
          collName,
          (c) => c.replaceOne({'_id': serverId}, replacement),
        );
      }
    }
    return count;
  }

  @override
  bool createIndex(String dbName, String collName, MongoIndex index) {
    final ok = super.createIndex(dbName, collName, index);
    if (ok) {
      _fireCollection(
        dbName,
        collName,
        (c) => c.createIndex(
          keys: Map<String, dynamic>.from(index.keys),
          name: index.name,
          unique: index.unique,
          sparse: index.sparse,
        ),
      );
    }
    return ok;
  }

  @override
  bool dropIndex(String dbName, String collName, String indexName) {
    final ok = super.dropIndex(dbName, collName, indexName);
    if (ok) _fireCollection(dbName, collName, (c) => c.dropIndexes(indexName));
    return ok;
  }

  @override
  bool createDatabase(String dbName, [String initialCollName = 'users']) {
    final ok = super.createDatabase(dbName, initialCollName);
    if (ok) {
      _fireDb(dbName, (db) => db.createCollection(initialCollName));
      // Mirror the seed document the local engine just added.
      final db = getDatabase(dbName);
      final coll = db?.collections[initialCollName];
      if (coll != null && coll.documents.isNotEmpty) {
        final seed = coll.documents.first.data;
        _fireCollection(
          dbName,
          initialCollName,
          (c) => c.insertOne(_denormalizeDoc(<String, dynamic>{
            ...seed,
            '_id': _toObjectId(seed['_id'].toString()),
          })),
        );
      }
    }
    return ok;
  }

  @override
  bool createCollection(String dbName, String collName) {
    final ok = super.createCollection(dbName, collName);
    if (ok) _fireDb(dbName, (db) => db.createCollection(collName));
    return ok;
  }

  @override
  bool dropCollection(String dbName, String collName) {
    final ok = super.dropCollection(dbName, collName);
    if (ok) _fireDb(dbName, (db) => db.dropCollection(collName));
    return ok;
  }

  @override
  bool dropDatabase(String dbName) {
    final ok = super.dropDatabase(dbName);
    if (ok) {
      final handle = _handles.remove(dbName);
      if (handle != null) {
        _fire(() => handle.drop());
      } else {
        _fire(() async {
          final db = await _openDb(dbName);
          _handles.remove(dbName);
          await db.drop();
        });
      }
    }
    return ok;
  }

  @override
  bool renameCollection(String dbName, String oldName, String newName) {
    final ok = super.renameCollection(dbName, oldName, newName);
    if (ok) {
      // In MongoDB, renameCollection command must be run against admin database
      _fire(() async {
        final adminDb = await _openDb('admin');
        await adminDb.runCommand({
          'renameCollection': '$dbName.$oldName',
          'to': '$dbName.${newName.trim()}',
          'dropTarget': false,
        });
      });
    }
    return ok;
  }

  @override
  bool renameDatabase(String oldName, String newName) {
    final oldDb = getDatabase(oldName);
    final ok = super.renameDatabase(oldName, newName);
    if (ok && oldDb != null) {
      final clean = newName.trim();
      _fire(() async {
        final adminDb = await _openDb('admin');
        for (final collName in oldDb.collections.keys) {
          try {
            await adminDb.runCommand({
              'renameCollection': '$oldName.$collName',
              'to': '$clean.$collName',
              'dropTarget': false,
            });
          } catch (_) {}
        }
      });
    }
    return ok;
  }

  @override
  bool createView(
    String dbName,
    String viewName,
    String sourceCollName,
    List<dynamic> pipeline,
  ) {
    final ok = super.createView(dbName, viewName, sourceCollName, pipeline);
    if (ok) {
      _fireDb(
        dbName,
        (db) => db.createView(
          viewName.trim(),
          sourceCollName,
          _denormalizeValue(pipeline) as List,
        ),
      );
    }
    return ok;
  }

  @override
  bool saveValidator(
    String dbName,
    String collName,
    Map<String, dynamic>? validator,
    String level,
    String action,
  ) {
    final ok = super.saveValidator(dbName, collName, validator, level, action);
    if (ok) {
      _fireDb(
        dbName,
        (db) => db.runCommand({
          'collMod': collName,
          if (validator != null) 'validator': validator,
          'validationLevel': level,
          'validationAction': action,
        }),
      );
    }
    return ok;
  }

  @override
  void resetToDefaults() {
    unawaited(_reloadFromServer());
  }

  Future<void> _reloadFromServer() async {
    try {
      await reload();
      if (!_disposed) onDataChanged?.call();
    } catch (err) {
      _report(err);
    }
  }

  // ---------------------------------------------------------------------------
  // Schema analysis (generic, for arbitrary collections)
  // ---------------------------------------------------------------------------

  @override
  List<SchemaFieldStat> analyzeSchema(String dbName, String collName) {
    final coll = getCollection(dbName, collName);
    if (coll == null || coll.documents.isEmpty) return const [];

    final docs = coll.documents;
    final total = docs.length;

    final keys = <String>[];
    for (final doc in docs) {
      for (final key in doc.data.keys) {
        if (!keys.contains(key)) keys.add(key);
      }
    }

    return keys.map((key) {
      final typeCounts = <String, int>{};
      final distinct = <String>{};
      final samples = <dynamic>[];
      var missing = 0;
      num? minValue;
      num? maxValue;

      for (final doc in docs) {
        final value = doc.data[key];
        if (!doc.data.containsKey(key) || value == null) {
          missing++;
          continue;
        }
        final type = _bsonTypeName(value);
        typeCounts[type] = (typeCounts[type] ?? 0) + 1;
        distinct.add(value is Map || value is List ? jsonEncode(value) : '$value');
        if (samples.length < 4 && !samples.any((s) => s == value)) samples.add(value);
        if (value is num) {
          if (minValue == null || value < minValue) minValue = value;
          if (maxValue == null || value > maxValue) maxValue = value;
        }
      }

      final present = total - missing;
      return SchemaFieldStat(
        name: key,
        path: key,
        types: typeCounts.entries
            .map((e) => SchemaFieldTypeStat(
                  type: e.key,
                  count: e.value,
                  percentage: present == 0 ? 0 : ((e.value / present) * 100).round(),
                ))
            .toList(),
        totalValues: present,
        missingCount: missing,
        missingPercentage: total == 0 ? 0 : ((missing / total) * 100).round(),
        distinctCount: distinct.length,
        sampleValues: samples,
        min: minValue,
        max: maxValue,
      );
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Server plumbing
  // ---------------------------------------------------------------------------

  void _fireCollection(
    String dbName,
    String collName,
    Future<void> Function(mdb.DbCollection collection) op,
  ) {
    final handle = _handles[dbName];
    if (handle != null) {
      _fire(() => op(handle.collection(collName)));
      return;
    }
    _fire(() async {
      final db = await _openDb(dbName);
      await op(db.collection(collName));
    });
  }

  void _fireDb(String dbName, Future<void> Function(mdb.Db db) op) {
    final handle = _handles[dbName];
    if (handle != null) {
      _fire(() => op(handle));
      return;
    }
    _fire(() async {
      final db = await _openDb(dbName);
      await op(db);
    });
  }

  void _fire(Future Function() action) {
    unawaited(Future(() async {
      try {
        await action();
      } catch (err) {
        _report(err);
      }
    }));
  }

  void _report(Object error) {
    lastError = '$error';
    onError?.call(lastError!);
  }

  // ---------------------------------------------------------------------------
  // Value conversion between the server and the JSON-friendly mirror
  // ---------------------------------------------------------------------------

  static String _ensureDbPath(String uri) {
    final trimmed = uri.trim();
    try {
      final questionMarkIndex = trimmed.indexOf('?');
      final pathEnd = questionMarkIndex == -1 ? trimmed.length : questionMarkIndex;
      final schemeEnd = trimmed.indexOf('://');
      if (schemeEnd == -1) return trimmed;
      final slashAfterHost = trimmed.indexOf('/', schemeEnd + 3);

      if (slashAfterHost == -1 || slashAfterHost >= pathEnd - 1) {
        return _withDatabase(trimmed, 'test');
      }
      return trimmed;
    } catch (_) {
      return trimmed;
    }
  }

  static String _withDatabase(String uri, String dbName) {
    try {
      final cleanDb = Uri.encodeComponent(dbName.trim());
      final questionMarkIndex = uri.indexOf('?');
      final pathEnd = questionMarkIndex == -1 ? uri.length : questionMarkIndex;
      final schemeEnd = uri.indexOf('://');
      if (schemeEnd == -1) return uri;
      final slashAfterHost = uri.indexOf('/', schemeEnd + 3);

      final query = questionMarkIndex != -1 ? uri.substring(questionMarkIndex) : '';

      if (slashAfterHost == -1 || slashAfterHost > pathEnd) {
        final prefix = questionMarkIndex != -1 ? uri.substring(0, questionMarkIndex) : uri;
        return '$prefix/$cleanDb$query';
      } else {
        final prefix = uri.substring(0, slashAfterHost);
        return '$prefix/$cleanDb$query';
      }
    } catch (_) {
      return uri;
    }
  }

  Map<String, dynamic> _normalizeMap(Map<dynamic, dynamic> raw) {
    final out = <String, dynamic>{};
    raw.forEach((k, v) => out[k.toString()] = _normalizeValue(v));
    return out;
  }

  dynamic _normalizeValue(dynamic value) {
    if (value == null) return null;
    if (value is mdb.ObjectId) return MongoObjectId(value.oid);
    if (value is DateTime) return value.toIso8601String();
    if (value is Uint8List) return base64Encode(value);
    if (value is Map) return _normalizeMap(value);
    if (value is List) return value.map(_normalizeValue).toList();
    if (value is String || value is num || value is bool) return value;
    // Int64 / Decimal / Timestamp / etc.
    final asInt = int.tryParse(value.toString());
    return asInt ?? value.toString();
  }

  Map<String, dynamic> _denormalizeDoc(Map<String, dynamic> doc) {
    final out = _denormalizeValue(Map<String, dynamic>.from(doc));
    if (out is! Map<String, dynamic>) return <String, dynamic>{};
    return out;
  }

  dynamic _denormalizeValue(dynamic value) {
    if (value == null) return null;
    if (value is MongoObjectId) return _toObjectId(value.hex);
    if (value is String) {
      // Try to detect ISO date strings that should become DateTime for server
      if (RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:?\d{2})?$').hasMatch(value)) {
        try {
          return DateTime.parse(value);
        } catch (_) {
          return value;
        }
      }
      return value;
    }
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      // Extended JSON support
      if (map.length == 1) {
        if (map.containsKey('\$oid')) {
          final oid = map['\$oid'];
          if (oid is String) return _toObjectId(oid);
        }
        if (map.containsKey('\$date')) {
          final date = map['\$date'];
          if (date is String) {
            try {
              return DateTime.parse(date);
            } catch (_) {
              return date;
            }
          }
          if (date is int) {
            try {
              return DateTime.fromMillisecondsSinceEpoch(date);
            } catch (_) {
              return date;
            }
          }
        }
        if (map.containsKey('\$timestamp')) {
          final ts = map['\$timestamp'];
          if (ts is Map && ts['t'] is int) {
            try {
              return DateTime.fromMillisecondsSinceEpoch((ts['t'] as int) * 1000);
            } catch (_) {}
          }
        }
      }
      final out = <String, dynamic>{};
      map.forEach((k, v) {
        out[k.toString()] = _denormalizeValue(v);
      });
      return out;
    }
    if (value is List) {
      return value.map(_denormalizeValue).toList();
    }
    if (value is int || value is double || value is bool) return value;
    return value;
  }

  /// Resolves the server-side `_id` for a mirrored document: it becomes a BSON
  /// ObjectId only when the mirror actually holds a [MongoObjectId]. A document
  /// stored with a string `_id` (even a 24-char hex one) is sent back as a
  /// string.
  Object _serverId(String dbName, String collName, String docId) {
    final coll = getCollection(dbName, collName);
    if (coll != null) {
      for (final doc in coll.documents) {
        if (doc.id == docId) {
          final raw = doc.data['_id'];
          if (raw is MongoObjectId) return _toObjectId(raw.hex);
          if (raw is String) return raw;
          break;
        }
      }
    }
    // Unknown document: keep a valid ObjectId-shaped id as an ObjectId.
    return _toObjectId(docId);
  }

  /// Same as [_serverId] but for a filter value, and without the ObjectId
  /// fallback: a string `_id` filter stays a string unless the mirror shows the
  /// document's `_id` is an ObjectId.
  Object _serverIdValue(String dbName, String collName, String id) {
    final coll = getCollection(dbName, collName);
    if (coll != null) {
      for (final doc in coll.documents) {
        if (doc.id == id) {
          final raw = doc.data['_id'];
          if (raw is MongoObjectId) return _toObjectId(raw.hex);
          break;
        }
      }
    }
    return id;
  }

  Map<String, dynamic> _denormalizeFilter(
    String dbName,
    String collName,
    Map filter,
  ) {
    final out = <String, dynamic>{};
    filter.forEach((k, v) {
      final key = k.toString();
      final denorm = _denormalizeValue(v);
      out[key] = key == '_id' && denorm is String
          ? _serverIdValue(dbName, collName, denorm)
          : denorm;
    });
    return out;
  }

  Map<String, dynamic> _toServerUpdate(Map fields) {
    final hasOperator = fields.keys.any((k) => k.toString().startsWith(r'$'));
    if (hasOperator) {
      return fields.map(
        (k, v) => MapEntry(k.toString(), _denormalizeValue(v)),
      );
    }
    return {
      r'$set': fields.map(
        (k, v) => MapEntry(k.toString(), _denormalizeValue(v)),
      ),
    };
  }

  Object _toObjectId(String hex) => mdb.ObjectId.tryParse(hex) ?? hex;

  String _bsonTypeName(dynamic value) {
    if (value is MongoObjectId) return 'ObjectId';
    if (value is String) return 'String';
    if (value is bool) return 'Boolean';
    if (value is int) return 'Int32';
    if (value is double) return 'Double';
    if (value is List) return 'Array';
    if (value is Map) return 'Object';
    if (value is DateTime) return 'Date';
    return value.runtimeType.toString();
  }
}
