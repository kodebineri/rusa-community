import 'dart:convert';

import '../models/mongo_models.dart';

/// Pretty-prints a document the way the mongosh-flavoured editors expect:
/// BSON values keep their type as constructors instead of collapsing to JSON
/// scalars, so the editor shows the *real* datatype and the parser can read it
/// back:
///
/// ```text
/// {
///   "_id": ObjectId("60c72b2f9b1d8b0015f8a031"),
///   "created_at": ISODate("2023-10-01T10:15:00.000Z")
/// }
/// ```
///
/// * [MongoObjectId] (and `{"$oid": ...}` wrappers) render as `ObjectId("...")`.
/// * `DateTime` and ISO-8601 strings render as `ISODate("...")`.
/// * Plain 24-hex strings are left as strings, so a string field that happens
///   to look like an ObjectId is not silently retyped.
String encodeMongoJson(dynamic value, {String indentUnit = '  '}) {
  final buffer = StringBuffer();
  _write(value, buffer, 0, indentUnit);
  return buffer.toString();
}

final RegExp _iso8601 = RegExp(
  r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:?\d{2})?$',
);

void _write(dynamic value, StringBuffer b, int depth, String unit) {
  final pad = unit * depth;
  final innerPad = unit * (depth + 1);

  if (value is MongoObjectId) {
    b.write('ObjectId("${value.hex}")');
    return;
  }
  if (value is DateTime) {
    b.write('ISODate("${value.toIso8601String()}")');
    return;
  }

  if (value is Map) {
    // Extended JSON wrappers produced by `tolerantParse`.
    if (value.length == 1 &&
        value.containsKey(r'$oid') &&
        value[r'$oid'] is String) {
      b.write('ObjectId("${value[r'$oid']}")');
      return;
    }
    if (value.length == 1 && value.containsKey(r'$date')) {
      final date = value[r'$date'];
      final iso = date is int
          ? DateTime.fromMillisecondsSinceEpoch(date).toIso8601String()
          : date;
      b.write('ISODate("$iso")');
      return;
    }
    if (value.isEmpty) {
      b.write('{}');
      return;
    }
    b.write('{\n');
    final entries = value.entries.toList();
    for (var i = 0; i < entries.length; i++) {
      b.write(innerPad);
      b.write(jsonEncode(entries[i].key.toString()));
      b.write(': ');
      _write(entries[i].value, b, depth + 1, unit);
      if (i < entries.length - 1) b.write(',');
      b.write('\n');
    }
    b.write(pad);
    b.write('}');
    return;
  }

  if (value is List) {
    if (value.isEmpty) {
      b.write('[]');
      return;
    }
    b.write('[\n');
    for (var i = 0; i < value.length; i++) {
      b.write(innerPad);
      _write(value[i], b, depth + 1, unit);
      if (i < value.length - 1) b.write(',');
      b.write('\n');
    }
    b.write(pad);
    b.write(']');
    return;
  }

  if (value is String) {
    if (_iso8601.hasMatch(value)) {
      b.write('ISODate("$value")');
      return;
    }
    b.write(jsonEncode(value));
    return;
  }

  if (value == null || value is num || value is bool) {
    b.write(jsonEncode(value));
    return;
  }

  // Unknown type: serialise it the same way `jsonEncode` would.
  b.write(jsonEncode(value.toString()));
}
