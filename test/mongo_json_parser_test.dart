import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rusa/models/mongo_models.dart';
import 'package:rusa/services/local_mongo_engine.dart';
import 'package:rusa/utils/mongo_json_encoder.dart';
import 'package:rusa/utils/mongo_json_parser.dart';

void main() {
  group('preprocessMongoJson', () {
    test('rewrites ObjectId constructors to Extended JSON', () {
      expect(
        preprocessMongoJson('{ "ref": ObjectId("507f1f77bcf86cd799439011") }'),
        '{ "ref": {"\$oid": "507f1f77bcf86cd799439011"} }',
      );
      expect(
        preprocessMongoJson("{ 'ref': new ObjectId('507f1f77bcf86cd799439011') }"),
        "{ 'ref': {\"\$oid\": \"507f1f77bcf86cd799439011\"} }",
      );
    });

    test('rewrites ISODate constructors to Extended JSON', () {
      expect(
        preprocessMongoJson('{ "at": ISODate("2024-01-02T03:04:05Z") }'),
        '{ "at": {"\$date": "2024-01-02T03:04:05Z"} }',
      );
    });

    test('leaves plain strings untouched', () {
      expect(
        preprocessMongoJson('{ "ref": "507f1f77bcf86cd799439011" }'),
        '{ "ref": "507f1f77bcf86cd799439011" }',
      );
    });
  });

  group('LocalMongoEngine ObjectId handling', () {
    late LocalMongoEngine engine;

    setUp(() {
      engine = LocalMongoEngine.seeded();
      engine.createDatabase('testdb', 'things');
    });

    test('tolerantParse accepts ObjectId constructors', () {
      final parsed = engine.tolerantParse(
        '{ "ref": ObjectId("507f1f77bcf86cd799439011") }',
      );
      expect(parsed, isA<Map>());
      expect((parsed as Map)['ref'], {'\$oid': '507f1f77bcf86cd799439011'});
    });

    test('insert keeps the ObjectId type in the mirror and filters match it', () {
      engine.insertDocument(
        'testdb',
        'things',
        engine.tolerantParse(
          '{ "ref": ObjectId("507f1f77bcf86cd799439011") }',
        ) as Map<String, dynamic>,
      );

      final result = engine.findDocuments(
        'testdb',
        'things',
        QueryFilterOptions(
          filter: '{ "ref": ObjectId("507f1f77bcf86cd799439011") }',
        ),
      );

      expect(result.documents, hasLength(1));
      expect(
        result.documents.first.data['ref'],
        const MongoObjectId('507f1f77bcf86cd799439011'),
      );
    });

    test('aggregation stages accept ObjectId constructors', () {
      engine.insertDocument(
        'testdb',
        'things',
        engine.tolerantParse(
          '{ "ref": ObjectId("507f1f77bcf86cd799439011") }',
        ) as Map<String, dynamic>,
      );

      final result = engine.runAggregation('testdb', 'things', [
        {
          r'$match': engine.tolerantParse(
            '{ "ref": ObjectId("507f1f77bcf86cd799439011") }',
          ),
        },
      ]);

      expect(result.documents, hasLength(1));
    });
  });

  group('encodeMongoJson', () {
    test('renders BSON values as mongosh constructors', () {
      final text = encodeMongoJson(<String, dynamic>{
        '_id': const MongoObjectId('6aec4ca6cbe464cc17026e78'),
        'post_id': '60c72b2f9b1d8b0015f8a040',
        'author_id': const MongoObjectId('60c72b2f9b1d8b0015f8a031'),
        'text': 'hello',
        'created_at': '2023-10-01T10:15:00.000Z',
      });

      expect(text, contains('"_id": ObjectId("6aec4ca6cbe464cc17026e78")'));
      expect(text, contains('"author_id": ObjectId("60c72b2f9b1d8b0015f8a031")'));
      // A plain 24-hex string must stay a string.
      expect(text, contains('"post_id": "60c72b2f9b1d8b0015f8a040"'));
      expect(text, contains('"created_at": ISODate("2023-10-01T10:15:00.000Z")'));
    });

    test('round-trips through the tolerant parser', () {
      final engine = LocalMongoEngine.seeded();
      final text = encodeMongoJson(<String, dynamic>{
        '_id': const MongoObjectId('6aec4ca6cbe464cc17026e78'),
        'created_at': '2023-10-01T10:15:00.000Z',
      });

      final parsed = engine.tolerantParse(text) as Map;
      expect(parsed['_id'], {'\$oid': '6aec4ca6cbe464cc17026e78'});
      expect(parsed['created_at'], {'\$date': '2023-10-01T10:15:00.000Z'});
    });

    test('handles nested arrays and objects', () {
      final text = encodeMongoJson(<String, dynamic>{
        'tags': ['a', 'b'],
        'meta': {'ref': const MongoObjectId('60c72b2f9b1d8b0015f8a031')},
      });
      expect(text, contains('"tags": [\n    "a",\n    "b"\n  ]'));
      expect(text, contains('"ref": ObjectId("60c72b2f9b1d8b0015f8a031")'));
    });
  });

  group('MongoObjectId in the mirror', () {
    late LocalMongoEngine engine;

    setUp(() {
      engine = LocalMongoEngine.seeded();
      engine.createDatabase('testdb', 'things');
    });

    test('insert keeps an ObjectId as a distinct type', () {
      final inserted = engine.insertDocument(
        'testdb',
        'things',
        engine.tolerantParse(
          '{ "ref": ObjectId("507f1f77bcf86cd799439011") }',
        ) as Map<String, dynamic>,
      );

      expect(inserted.data['ref'], const MongoObjectId('507f1f77bcf86cd799439011'));
      expect(
        jsonEncode(inserted.data),
        contains('{"\$oid":"507f1f77bcf86cd799439011"}'),
      );
    });

    test('ObjectId filters match, plain string filters do not', () {
      engine.insertDocument(
        'testdb',
        'things',
        engine.tolerantParse(
          '{ "ref": ObjectId("507f1f77bcf86cd799439011") }',
        ) as Map<String, dynamic>,
      );

      final byObjectId = engine.findDocuments(
        'testdb',
        'things',
        QueryFilterOptions(
          filter: '{ "ref": ObjectId("507f1f77bcf86cd799439011") }',
        ),
      );
      final byString = engine.findDocuments(
        'testdb',
        'things',
        QueryFilterOptions(filter: '{ "ref": "507f1f77bcf86cd799439011" }'),
      );

      expect(byObjectId.documents, hasLength(1));
      expect(byString.documents, isEmpty);
    });

    test('an edit round-trips the ObjectId type', () {
      engine.insertDocument(
        'testdb',
        'things',
        engine.tolerantParse(
          '{ "ref": ObjectId("507f1f77bcf86cd799439011") }',
        ) as Map<String, dynamic>,
      );

      final doc = engine
          .findDocuments('testdb', 'things', QueryFilterOptions())
          .documents
          .firstWhere((d) => d.data['ref'] != null);

      // Mimic the JSON editor: encode, then parse the text back.
      final text = const JsonEncoder.withIndent('  ').convert(doc.data);
      expect(text, contains('"\$oid"'));

      engine.updateDocument(
        'testdb',
        'things',
        doc.id,
        engine.tolerantParse(text) as Map<String, dynamic>,
      );

      final updated = engine
          .findDocuments('testdb', 'things', QueryFilterOptions())
          .documents
          .firstWhere((d) => d.id == doc.id);
      expect(updated.data['ref'], isA<MongoObjectId>());
    });
  });

  group('string _id is not retyped', () {
    late LocalMongoEngine engine;

    setUp(() {
      engine = LocalMongoEngine.seeded();
      engine.createDatabase('testdb', 'things');
    });

    test('a user-supplied string _id stays a string', () {
      final doc = engine.insertDocument(
        'testdb',
        'things',
        {'_id': 'custom-id', 'x': 1},
      );
      expect(doc.data['_id'], 'custom-id');
      expect(doc.id, 'custom-id');
    });

    test('a 24-hex string _id stays a string', () {
      final doc = engine.insertDocument(
        'testdb',
        'things',
        {'_id': '60c72b2f9b1d8b0015f8a001', 'x': 1},
      );
      expect(doc.data['_id'], isA<String>());
      expect(doc.data['_id'], '60c72b2f9b1d8b0015f8a001');
    });

    test('a missing _id gets a generated ObjectId', () {
      final doc = engine.insertDocument('testdb', 'things', {'x': 1});
      expect(doc.data['_id'], isA<MongoObjectId>());
    });

    test('editing a string _id document keeps the string _id', () {
      final doc = engine.insertDocument(
        'testdb',
        'things',
        {'_id': 'custom-id', 'x': 1},
      );
      engine.updateDocument(
        'testdb',
        'things',
        doc.id,
        {'_id': 'custom-id', 'x': 2},
      );
      final updated = engine
          .findDocuments('testdb', 'things', QueryFilterOptions())
          .documents
          .firstWhere((d) => d.id == 'custom-id');
      expect(updated.data['_id'], isA<String>());
      expect(updated.data['x'], 2);
    });
  });
}
