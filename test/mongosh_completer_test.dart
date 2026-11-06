import 'package:flutter_test/flutter_test.dart';

import 'package:rusa/services/local_mongo_engine.dart';
import 'package:rusa/services/mongo_engine.dart';
import 'package:rusa/services/mongosh_completer.dart';

void main() {
  late MongoshCompleter completer;

  setUp(() {
    mongoEngine = LocalMongoEngine.instance;
    mongoEngine.resetToDefaults();
    completer = MongoshCompleter();
  });

  tearDown(() {
    mongoEngine.resetToDefaults();
  });

  group('completion contexts', () {
    test('completes a database name after use', () {
      final completion = completer.complete('use lib', dbName: 'library')!;
      expect(completion.token, 'lib');
      expect(completion.single, 'library');
      expect(completion.appendSpace, isTrue);
    });

    test('lists every database for an empty use token', () {
      final completion = completer.complete('use ', dbName: 'library')!;
      expect(completion.candidates,
          containsAll(['library', 'social_networks']));
      expect(completion.single, isNull);
    });

    test('completes a collection name after db.', () {
      final completion = completer.complete('db.bo', dbName: 'library')!;
      expect(completion.single, 'books');
      expect(completion.appendSpace, isFalse);
    });

    test('completes a method name after db.<coll>.', () {
      final completion = completer.complete('db.books.findO', dbName: 'library')!;
      expect(completion.single, 'findOne');
    });

    test('an ambiguous method prefix extends to the common prefix', () {
      final completion = completer.complete('db.books.fi', dbName: 'library')!;
      expect(completion.single, isNull);
      expect(completion.commonPrefix, 'find');
    });

    test('lists the shell methods from the command table', () {
      final completion = completer.complete('db.books.', dbName: 'library')!;
      expect(
        completion.candidates,
        containsAll(['find', 'insertOne', 'deleteMany', 'drop']),
      );
    });

    test('completes show targets', () {
      final completion = completer.complete('show ', dbName: 'library')!;
      expect(completion.candidates, ['collections', 'dbs']);
    });

    test('completes help topics', () {
      final completion = completer.complete('help findO', dbName: 'library')!;
      expect(completion.single, 'findOne');
    });

    test('returns null outside a completion context', () {
      expect(completer.complete('db.books.find({})', dbName: 'library'), isNull);
      expect(completer.complete('', dbName: 'library'), isNull);
      expect(completer.complete('use library', dbName: 'library'), isNull);
    });

    test('no common prefix when the candidates diverge', () {
      final completion = completer.complete('db.', dbName: 'library')!;
      expect(completion.commonPrefix, '');
    });

    test('common prefix narrows ambiguous candidates', () {
      // `social_networks` has users/posts/comments; `p` matches only posts.
      final completion =
          completer.complete('db.p', dbName: 'social_networks')!;
      expect(completion.single, 'posts');
    });
  });

  group('hasUnbalancedBrackets', () {
    test('detects open brackets', () {
      expect(hasUnbalancedBrackets('db.books.find({'), isTrue);
      expect(hasUnbalancedBrackets('db.books.find([{'), isTrue);
      expect(hasUnbalancedBrackets('db.books.find('), isTrue);
    });

    test('balanced input is complete', () {
      expect(hasUnbalancedBrackets('db.books.find({})'), isFalse);
      expect(hasUnbalancedBrackets('show dbs'), isFalse);
      expect(hasUnbalancedBrackets(''), isFalse);
    });

    test('ignores brackets inside quoted strings', () {
      expect(hasUnbalancedBrackets('db.books.find({ title: "a(b" })'), isFalse);
      expect(hasUnbalancedBrackets("db.books.find({ title: 'a(b' })"), isFalse);
    });
  });
}
