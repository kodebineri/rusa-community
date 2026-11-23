// Authentication Database (`authSource`) handling for the connect dialog.

import 'package:flutter_test/flutter_test.dart';

import 'package:rusa/utils/mongo_uri.dart';

void main() {
  group('appendAuthSource', () {
    test('adds the parameter to a credential URI with no query', () {
      expect(
        appendAuthSource('mongodb://user:pass@db.example.com:27017/app', 'admin'),
        'mongodb://user:pass@db.example.com:27017/app?authSource=admin',
      );
    });

    test('appends to an existing query string', () {
      expect(
        appendAuthSource(
          'mongodb://user:pass@db.example.com/app?retryWrites=true',
          'admin',
        ),
        'mongodb://user:pass@db.example.com/app?retryWrites=true'
        '&authSource=admin',
      );
    });

    test('handles an empty query and a trailing ampersand', () {
      expect(
        appendAuthSource('mongodb://u:p@host/app?', 'admin'),
        'mongodb://u:p@host/app?authSource=admin',
      );
      expect(
        appendAuthSource('mongodb://u:p@host/app?retryWrites=true&', 'admin'),
        'mongodb://u:p@host/app?retryWrites=true&authSource=admin',
      );
    });

    test('keeps a fragment at the end', () {
      expect(
        appendAuthSource('mongodb://u:p@host/app#section', 'admin'),
        'mongodb://u:p@host/app?authSource=admin#section',
      );
    });

    test('works for SRV URIs', () {
      expect(
        appendAuthSource('mongodb+srv://u:p@cluster.example.net/app', 'admin'),
        'mongodb+srv://u:p@cluster.example.net/app?authSource=admin',
      );
    });

    test('does nothing without credentials', () {
      const uri = 'mongodb://localhost:27017';
      expect(appendAuthSource(uri, 'admin'), uri);
    });

    test('never overrides an explicit authSource', () {
      const uri = 'mongodb://u:p@host/app?authSource=users';
      expect(appendAuthSource(uri, 'admin'), uri);
      const upper = 'mongodb://u:p@host/app?AUTHSOURCE=users';
      expect(appendAuthSource(upper, 'admin'), upper);
    });

    test('a blank database leaves the URI untouched', () {
      const uri = 'mongodb://u:p@host/app';
      expect(appendAuthSource(uri, ''), uri);
      expect(appendAuthSource(uri, '   '), uri);
    });

    test('is idempotent', () {
      final once = appendAuthSource('mongodb://u:p@host/app', 'admin');
      expect(appendAuthSource(once, 'admin'), once);
    });

    test('percent-encodes the database name', () {
      expect(
        appendAuthSource('mongodb://u:p@host/app', 'my db'),
        'mongodb://u:p@host/app?authSource=my%20db',
      );
    });
  });

  group('authSourceFromUri', () {
    test('reads the value case-insensitively', () {
      expect(
        authSourceFromUri('mongodb://u:p@host/app?retryWrites=true&authSource=admin'),
        'admin',
      );
      expect(
        authSourceFromUri('mongodb://u:p@host/app?AUTHSOURCE=users'),
        'users',
      );
    });

    test('decodes the value', () {
      expect(
        authSourceFromUri('mongodb://u:p@host/app?authSource=my%20db'),
        'my db',
      );
    });

    test('returns null when absent or empty', () {
      expect(authSourceFromUri('mongodb://u:p@host/app'), isNull);
      expect(authSourceFromUri('mongodb://u:p@host/app?authSource='), isNull);
      expect(authSourceFromUri('mongodb://u:p@host/app?retryWrites=true'), isNull);
    });
  });
}