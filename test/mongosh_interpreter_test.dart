import 'package:flutter_test/flutter_test.dart';

import 'package:rusa/services/local_mongo_engine.dart';
import 'package:rusa/services/mongo_engine.dart';
import 'package:rusa/services/mongosh_interpreter.dart';

/// Unit tests for the mongosh command table. The interpreter is pure Dart, so
/// these run without pumping a widget.
void main() {
  late MongoshInterpreter shell;

  setUp(() {
    mongoEngine = LocalMongoEngine.instance;
    mongoEngine.resetToDefaults();
    shell = MongoshInterpreter();
  });

  tearDown(() {
    mongoEngine.resetToDefaults();
  });

  int bookCount() =>
      mongoEngine.getCollection('library', 'books')!.documents.length;

  group('help', () {
    test('lists every command in the table', () {
      final out = shell.execute('help', dbName: 'library').output;
      for (final command in MongoshInterpreter.commands) {
        expect(out, contains(command.usage),
            reason: '${command.name} is missing from help');
      }
      for (final command in MongoshInterpreter.collectionCommands) {
        expect(out, contains(command.usage),
            reason: '${command.method} is missing from help');
      }
    });

    test('explains a single command', () {
      final out = shell.execute('help find', dbName: 'library').output;
      expect(out, contains('db.<coll>.find(filter)'));
      expect(out, contains('query a collection'));
    });

    test('marks the risky commands', () {
      final out = shell.execute('help', dbName: 'library').output;
      expect(out, contains('[risky]'));
    });

    test('an unknown topic is reported honestly', () {
      final result = shell.execute('help nope', dbName: 'library');
      expect(result.output, contains('No help for "nope"'));
    });
  });

  group('honest errors', () {
    test('an unsupported db method is reported, not acknowledged', () {
      final result = shell.execute(
        'db.books.bulkWrite([])',
        dbName: 'library',
      );
      expect(result.isError, isTrue);
      expect(result.output, contains('not supported'));
      expect(result.output, isNot(contains('acknowledged')));
    });

    test('an unknown command is reported', () {
      final result = shell.execute('frobnicate', dbName: 'library');
      expect(result.isError, isTrue);
      expect(result.output, contains('Unrecognized command'));
    });

    test('use of a missing database does not claim success', () {
      final result = shell.execute('use nope', dbName: 'library');
      expect(result.isError, isTrue);
      expect(result.sideEffect, isNull);
      expect(result.output, contains('does not exist'));
    });
  });

  group('reads', () {
    test('show dbs lists the sample databases', () {
      final out = shell.execute('show dbs', dbName: 'library').output;
      expect(out, contains('library'));
      expect(out, contains('social_networks'));
    });

    test('show collections lists the current database', () {
      final out = shell.execute('show collections', dbName: 'library').output;
      expect(out, contains('books'));
      expect(out, contains('publishers'));
    });

    test('find returns documents', () {
      final out = shell.execute('db.books.find({})', dbName: 'library').output;
      expect(out, contains('"title"'));
    });

    test('find applies a filter', () {
      final all = shell.execute('db.books.find({})', dbName: 'library').output;
      final filtered = shell.execute(
        r'db.books.find({ published_year: { $gte: 2020 } })',
        dbName: 'library',
      ).output;
      expect(filtered.length, lessThan(all.length));
      expect(filtered, contains('2022'));
      expect(filtered, isNot(contains('2019')));
    });

    test('findOne returns the first document', () {
      final out =
          shell.execute('db.books.findOne({})', dbName: 'library').output;
      expect(out, contains('"title"'));
      expect(out, isNot(contains('[1 docs]')));
    });

    test('findOne returns null when nothing matches', () {
      final out = shell
          .execute('db.books.findOne({ title: "nope" })', dbName: 'library')
          .output;
      expect(out, 'null');
    });

    test('countDocuments counts the matches', () {
      final all = shell
          .execute('db.books.countDocuments({})', dbName: 'library')
          .output;
      final recent = shell
          .execute(
            r'db.books.countDocuments({ published_year: { $gte: 2020 } })',
            dbName: 'library',
          )
          .output;
      expect(int.parse(all), greaterThan(0));
      expect(int.parse(recent), 1);
    });

    test('count is an alias for countDocuments', () {
      final out = shell.execute('db.books.count({})', dbName: 'library').output;
      expect(int.parse(out), greaterThan(0));
    });

    test('distinct lists unique field values', () {
      final out = shell
          .execute('db.books.distinct("published_year")', dbName: 'library')
          .output;
      expect(out, contains('2019'));
      expect(out, contains('2022'));
    });

    test('aggregate runs a pipeline', () {
      final out = shell.execute(
        r'db.books.aggregate([{ $match: { published_year: { $gte: 2020 } } }])',
        dbName: 'library',
      ).output;
      expect(out, contains('[1 docs]'));
      expect(out, contains('2022'));
    });

    test('db.getName and db.getCollectionNames', () {
      expect(shell.execute('db.getName()', dbName: 'library').output, 'library');
      final names =
          shell.execute('db.getCollectionNames()', dbName: 'library').output;
      expect(names, contains('books'));
    });

    test('print and JSON.stringify', () {
      expect(shell.execute('print("hello")', dbName: 'library').output,
          'hello');
      expect(shell.execute('JSON.stringify({ a: 1 })', dbName: 'library').output,
          '{"a":1}');
    });
  });

  group('cursor chains', () {
    test('limit caps the result', () {
      final out = shell
          .execute('db.books.find({}).limit(1)', dbName: 'library')
          .output;
      expect(out, contains('[1 docs]'));
    });

    test('sort orders the result', () {
      final out = shell.execute(
        'db.books.find({}).sort({ published_year: -1 }).limit(1)',
        dbName: 'library',
      ).output;
      expect(out, contains('2022'));
      expect(out, isNot(contains('2019')));
    });

    test('skip offsets the result', () {
      final out = shell
          .execute('db.books.find({}).skip(1).limit(1)', dbName: 'library')
          .output;
      expect(out, contains('[1 docs]'));
    });

    test('count returns the total, ignoring limit', () {
      final total =
          shell.execute('db.books.find({}).count()', dbName: 'library').output;
      final limited = shell
          .execute('db.books.find({}).limit(1).count()', dbName: 'library')
          .output;
      expect(int.parse(total), greaterThan(1));
      expect(limited, total);
    });

    test('pretty is accepted as a no-op', () {
      final out = shell
          .execute('db.books.find({}).pretty()', dbName: 'library')
          .output;
      expect(out, contains('"title"'));
    });

    test('an unsupported chain method is reported', () {
      final result = shell
          .execute('db.books.find({}).explain()', dbName: 'library');
      expect(result.isError, isTrue);
      expect(result.output, contains('not supported'));
    });

    test('chaining a non-cursor command is rejected', () {
      final result = shell
          .execute('db.books.findOne({}).sort({})', dbName: 'library');
      expect(result.isError, isTrue);
      expect(result.output, contains('does not support chaining'));
    });
  });

  group('writes', () {
    test('insertOne adds a document and reports the id', () {
      final before = bookCount();
      final result = shell.execute(
        'db.books.insertOne({ title: "New" })',
        dbName: 'library',
      );
      expect(result.isError, isFalse);
      expect(result.output, contains('insertedId'));
      expect(bookCount(), before + 1);
    });

    test('updateOne updates exactly one document', () {
      final result = shell.execute(
        r'db.books.updateOne({}, { $set: { copies_available: 99 } })',
        dbName: 'library',
      );
      expect(result.output, contains('"modifiedCount": 1'));
      final updated = mongoEngine
          .getCollection('library', 'books')!
          .documents
          .where((doc) => doc.data['copies_available'] == 99)
          .length;
      expect(updated, 1, reason: 'updateOne must not behave like updateMany');
    });

    test('deleteOne deletes exactly one document', () {
      final before = bookCount();
      final result = shell.execute('db.books.deleteOne({})', dbName: 'library');
      expect(result.output, contains('"deletedCount": 1'));
      expect(bookCount(), before - 1,
          reason: 'the command must run once, not twice');
    });

    test('deleteMany deletes every match', () {
      final result = shell.execute('db.books.deleteMany({})', dbName: 'library');
      expect(result.output, contains('"deletedCount":'));
      expect(bookCount(), 0);
    });
  });

  group('writes & indexes', () {
    test('insertMany inserts every document', () {
      final before = bookCount();
      final result = shell.execute(
        'db.books.insertMany([{ title: "A" }, { title: "B" }])',
        dbName: 'library',
      );
      expect(result.isError, isFalse);
      expect(result.output, contains('insertedIds'));
      expect(bookCount(), before + 2);
    });

    test('replaceOne replaces the first match', () {
      final result = shell.execute(
        'db.books.replaceOne({}, { title: "Replaced" })',
        dbName: 'library',
      );
      expect(result.output, contains('"modifiedCount": 1'));
      final docs = mongoEngine.getCollection('library', 'books')!.documents;
      final replaced = docs.where((doc) => doc.data['title'] == 'Replaced');
      expect(replaced.length, 1);
      // Replacement semantics: fields not in the replacement are gone.
      expect(replaced.first.data.keys.toSet(), {'title', '_id'});
    });

    test('createIndex adds an index and rejects duplicates', () {
      final created = shell.execute(
        'db.books.createIndex({ title: 1 })',
        dbName: 'library',
      );
      expect(created.isError, isFalse);
      expect(created.output, contains('"numIndexesAfter"'));
      final indexes = mongoEngine.getCollection('library', 'books')!.indexes;
      expect(indexes.any((index) => index.name == 'title_1'), isTrue);

      final duplicate = shell.execute(
        'db.books.createIndex({ title: 1 })',
        dbName: 'library',
      );
      expect(duplicate.isError, isTrue);
      expect(duplicate.output, contains('already exists'));
    });

    test('getIndexes lists the indexes', () {
      final out =
          shell.execute('db.books.getIndexes()', dbName: 'library').output;
      expect(out, contains('_id_'));
      expect(out, contains('isbn_1'));
    });

    test('dropIndex removes an index', () {
      final result =
          shell.execute('db.books.dropIndex("isbn_1")', dbName: 'library');
      expect(result.isError, isFalse);
      final indexes = mongoEngine.getCollection('library', 'books')!.indexes;
      expect(indexes.any((index) => index.name == 'isbn_1'), isFalse);
    });

    test('dropIndex reports an unknown index', () {
      final result =
          shell.execute('db.books.dropIndex("nope")', dbName: 'library');
      expect(result.isError, isTrue);
      expect(result.output, contains('does not exist'));
    });

    test('stats reports the collection shape', () {
      final out = shell.execute('db.books.stats()', dbName: 'library').output;
      expect(out, contains('"ns": "library.books"'));
      expect(out, contains('"count"'));
      expect(out, contains('"nindexes"'));
    });

    test(r'$push appends to an array', () {
      final result = shell.execute(
        r'db.posts.updateOne({}, { $push: { tags: "shell" } })',
        dbName: 'social_networks',
      );
      expect(result.isError, isFalse);
      final doc = mongoEngine
          .getCollection('social_networks', 'posts')!
          .documents
          .first;
      expect(doc.data['tags'] as List, contains('shell'));
    });

    test(r'$pull removes from an array', () {
      shell.execute(
        r'db.posts.updateOne({}, { $push: { tags: "shell" } })',
        dbName: 'social_networks',
      );
      shell.execute(
        r'db.posts.updateOne({}, { $pull: { tags: "shell" } })',
        dbName: 'social_networks',
      );
      final doc = mongoEngine
          .getCollection('social_networks', 'posts')!
          .documents
          .first;
      expect(doc.data['tags'] as List, isNot(contains('shell')));
    });

    test(r'$unset works through updateMany', () {
      shell.execute(
        r'db.books.updateMany({}, { $unset: { rating: "" } })',
        dbName: 'library',
      );
      final docs = mongoEngine.getCollection('library', 'books')!.documents;
      expect(docs.every((doc) => !doc.data.containsKey('rating')), isTrue);
    });
  });

  group('side effects', () {
    test('use switches database', () {
      final result = shell.execute('use social_networks', dbName: 'library');
      expect(result.isError, isFalse);
      expect(result.sideEffect?.kind, MongoshSideEffectKind.switchDatabase);
      expect(result.sideEffect?.database, 'social_networks');
    });

    test('dropDatabase reports the drop', () {
      final result = shell.execute('db.dropDatabase()', dbName: 'library');
      expect(result.sideEffect?.kind, MongoshSideEffectKind.dropDatabase);
      expect(mongoEngine.getDatabase('library'), isNull);
    });

    test('drop reports the collection', () {
      final result = shell.execute('db.books.drop()', dbName: 'library');
      expect(result.sideEffect?.kind, MongoshSideEffectKind.dropCollection);
      expect(result.sideEffect?.collection, 'books');
      expect(mongoEngine.getCollection('library', 'books'), isNull);
    });
  });

  group('risky detection', () {
    test('destructive commands are risky', () {
      for (final command in [
        'db.books.deleteMany({})',
        'db.books.deleteOne({})',
        r'db.books.updateMany({}, { $set: { a: 1 } })',
        r'db.books.updateOne({}, { $set: { a: 1 } })',
        r'db.books.replaceOne({}, { title: "x" })',
        'db.books.drop()',
        'db.dropDatabase()',
      ]) {
        expect(shell.isRisky(command), isTrue, reason: command);
      }
    });

    test('reads are not risky', () {
      expect(shell.isRisky('db.books.find({})'), isFalse);
      expect(shell.isRisky('db.books.findOne({})'), isFalse);
      expect(shell.isRisky('db.books.aggregate([])'), isFalse);
      expect(shell.isRisky('show dbs'), isFalse);
      expect(shell.isRisky('help'), isFalse);
    });
  });
}
