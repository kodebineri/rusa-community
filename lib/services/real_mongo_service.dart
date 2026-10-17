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
  RealMongoService._(this.uri, this._primary);

  /// Maximum number of documents mirrored per collection, to keep very large
  /// collections (e.g. an oplog) from freezing the UI.
  static const int maxDocsPerCollection = 20000;

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

  /// Connects to [uri], verifies the server is reachable, then mirrors it.
  ///
  /// Throws (with the driver error) when the URI is invalid, the server is
  /// unreachable, or authentication fails.
  static Future<RealMongoService> connect(String uri) async {
    final safeUri = _ensureDbPath(uri);
    final primary = await mdb.Db.create(safeUri);
    await primary.open();
    await primary.pingCommand();

    final service = RealMongoService._(uri, primary);
    await service.reload();
    return service;
  }

  /// Re-reads every database, collection, document and index from the server.
  Future<void> reload() async {
    final names = await _primary.listDatabases();
    final result = <MongoDatabase>[];

    for (final raw in names) {
      final dbName = raw.toString();

      final db = await _openDb(dbName);
      final infos = await db.getCollectionInfos();
      final colls = <String, MongoCollection>{};

      for (final info in infos) {
        final collName = info['name']?.toString() ?? '';
        if (collName.isEmpty || collName.startsWith('system.')) continue;

        final isView = info['type']?.toString() == 'view';
        final options = info['options'];
        final optionsMap =
            options is Map ? options.map((k, v) => MapEntry(k.toString(), v)) : const <String, dynamic>{};

        final coll = db.collection(collName);
        final docs = await _loadDocuments(coll);
        final indexes = isView
            ? [MongoIndex(name: '_id_', keys: const {'_id': 1})]
            : await _loadIndexes(coll);

        colls[collName] = MongoCollection(
          name: collName,
          documents: docs,
          indexes: indexes,
          isView: isView,
          viewOn: isView ? optionsMap['viewOn']?.toString() : null,
          pipeline: isView ? (optionsMap['pipeline'] as List?)?.toList() : null,
        );
      }

      result.add(MongoDatabase(name: dbName, collections: colls));
    }

    databases = result;
  }

  /// Closes every server connection.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final db in _handles.values) {
      try {
        await db.close();
      } catch (_) {/* ignore */}
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

    // Re-use the (possibly SRV-resolved) host list of the primary connection.
    final uris = _primary.uriList.map((u) => _withDatabase(u, dbName)).toList();
    final db = uris.length > 1
        ? mdb.Db.pool(uris)
        : mdb.Db(uris.isEmpty ? _withDatabase(uri, dbName) : uris.first);
    await db.open();
    _handles[dbName] = db;
    return db;
  }

  Future<List<MongoDocument>> _loadDocuments(mdb.DbCollection coll) async {
    final docs = <MongoDocument>[];
    final stream = coll.find();
    await for (final raw in stream) {
      docs.add(MongoDocument.fromMap(_normalizeMap(raw)));
      if (docs.length >= maxDocsPerCollection) break;
    }
    return docs;
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
    _fireCollection(dbName, collName, (c) => c.insertOne(_denormalizeDoc(inserted.data)));
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
    _fireCollection(
      dbName,
      collName,
      (c) => c.updateOne({'_id': _toObjectId(docId)}, _toServerUpdate(updatedFields)),
    );
    return true;
  }

  @override
  bool deleteDocument(String dbName, String collName, String docId) {
    final ok = super.deleteDocument(dbName, collName, docId);
    if (ok) {
      _fireCollection(dbName, collName, (c) => c.deleteOne({'_id': _toObjectId(docId)}));
    }
    return ok;
  }

  @override
  bool deleteOne(String dbName, String collName, Map filter) {
    final ok = super.deleteOne(dbName, collName, filter);
    if (ok) _fireCollection(dbName, collName, (c) => c.deleteOne(_denormalizeFilter(filter)));
    return ok;
  }

  @override
  int deleteMany(String dbName, String collName, Map filter) {
    final removed = super.deleteMany(dbName, collName, filter);
    if (removed > 0) {
      _fireCollection(dbName, collName, (c) => c.deleteMany(_denormalizeFilter(filter)));
    }
    return removed;
  }

  @override
  int updateMany(String dbName, String collName, Map filter, Map update) {
    final count = super.updateMany(dbName, collName, filter, update);
    if (count > 0) {
      _fireCollection(
        dbName,
        collName,
        (c) => c.updateMany(_denormalizeFilter(filter), _toServerUpdate(update)),
      );
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
        _fireCollection(
          dbName,
          initialCollName,
          (c) => c.insertOne(_denormalizeDoc(coll.documents.first.data)),
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
      final target = handle ?? _primary;
      _fire(() => target.drop());
    }
    return ok;
  }

  @override
  bool renameCollection(String dbName, String oldName, String newName) {
    final ok = super.renameCollection(dbName, oldName, newName);
    if (ok) {
      _fireDb(
        dbName,
        (db) => db.runCommand({
          'renameCollection': '$dbName.$oldName',
          'to': '$dbName.${newName.trim()}',
          'dropTarget': false,
        }),
      );
    }
    return ok;
  }

  @override
  bool renameDatabase(String oldName, String newName) {
    final oldDb = getDatabase(oldName);
    final ok = super.renameDatabase(oldName, newName);
    if (ok && oldDb != null) {
      final clean = newName.trim();
      for (final collName in oldDb.collections.keys) {
        _fireDb(
          oldName,
          (db) => db.runCommand({
            'renameCollection': '$oldName.$collName',
            'to': '$clean.$collName',
            'dropTarget': false,
          }),
        );
      }
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
        (db) => db.createView(viewName.trim(), sourceCollName, pipeline),
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
    final parsed = Uri.parse(uri.trim());
    if (parsed.path.isEmpty || parsed.path == '/') {
      return parsed.replace(path: '/test').toString();
    }
    return uri.trim();
  }

  static String _withDatabase(String uri, String dbName) {
    try {
      return Uri.parse(uri).replace(path: '/$dbName').toString();
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
    if (value is mdb.ObjectId) return value.oid;
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
    final out = Map<String, dynamic>.from(doc);
    final id = out['_id'];
    if (id is String) out['_id'] = _toObjectId(id);
    return out;
  }

  Map<String, dynamic> _denormalizeFilter(Map filter) {
    final out = <String, dynamic>{};
    filter.forEach((k, v) {
      final key = k.toString();
      out[key] = key == '_id' && v is String ? _toObjectId(v) : v;
    });
    return out;
  }

  Map<String, dynamic> _toServerUpdate(Map fields) {
    final hasOperator = fields.keys.any((k) => k.toString().startsWith('\$'));
    if (hasOperator) return fields.map((k, v) => MapEntry(k.toString(), v));
    return {
      '\$set': fields.map((k, v) => MapEntry(k.toString(), v)),
    };
  }

  Object _toObjectId(String hex) => mdb.ObjectId.tryParse(hex) ?? hex;

  String _bsonTypeName(dynamic value) {
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
