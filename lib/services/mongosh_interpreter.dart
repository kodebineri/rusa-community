import 'dart:convert';

import '../models/mongo_models.dart';
import 'local_mongo_engine.dart';
import 'mongo_engine.dart';

/// A UI-level side effect a command asks the app shell to apply.
///
/// The interpreter never touches app state itself (selected database, open
/// tabs), so it stays a pure, unit-testable service; `main.dart` applies these.
enum MongoshSideEffectKind { switchDatabase, dropDatabase, dropCollection }

class MongoshSideEffect {
  const MongoshSideEffect(
    this.kind, {
    required this.database,
    this.collection,
  });

  final MongoshSideEffectKind kind;
  final String database;
  final String? collection;
}

/// What one command produced: the text to print, plus an optional side effect.
class MongoshResult {
  const MongoshResult(this.output, {this.sideEffect, this.isError = false});

  final String output;
  final MongoshSideEffect? sideEffect;

  /// True when the command failed or is not supported, so the shell can style
  /// the output as an error instead of pretending it succeeded.
  final bool isError;
}

/// A parsed `db.<coll>.<method>(args).<chain>(args)…` call.
class MongoshCollectionCall {
  const MongoshCollectionCall({
    required this.collection,
    required this.method,
    required this.args,
    required this.chain,
  });

  final String collection;
  final String method;
  final String args;

  /// Trailing cursor methods, e.g. `.sort({…}).limit(5)`.
  final List<MongoshChainSegment> chain;
}

/// One trailing cursor method and its raw arguments.
class MongoshChainSegment {
  const MongoshChainSegment(this.method, this.args);

  final String method;
  final String args;
}

/// Everything a top-level command handler needs.
class MongoshCommandContext {
  const MongoshCommandContext({
    required this.engine,
    required this.dbName,
    required this.command,
    required this.match,
  });

  final LocalMongoEngine engine;
  final String dbName;
  final String command;
  final RegExpMatch match;
}

/// Everything a `db.<coll>.<method>` handler needs.
class MongoshCollectionContext {
  const MongoshCollectionContext({
    required this.engine,
    required this.dbName,
    required this.call,
  });

  final LocalMongoEngine engine;
  final String dbName;
  final MongoshCollectionCall call;
}

/// One row of the shell's top-level command table (`help`, `show`, `use`, …).
class MongoshCommand {
  const MongoshCommand({
    required this.name,
    required this.usage,
    required this.summary,
    required this.pattern,
    required this.run,
    this.risky = false,
  });

  /// Short name used by `help <name>` (e.g. `show dbs`).
  final String name;

  /// How the command is written, shown in `help`.
  final String usage;

  /// One-line description, shown in `help`.
  final String summary;

  /// Matches the whole (normalised) command line.
  final RegExp pattern;

  /// Whether the UI must ask for confirmation before running it.
  final bool risky;

  final MongoshResult Function(MongoshCommandContext ctx) run;
}

/// One row of the collection-method table (`db.<coll>.<method>`).
class MongoshCollectionCommand {
  const MongoshCollectionCommand({
    required this.method,
    required this.usage,
    required this.summary,
    required this.run,
    this.risky = false,
    this.supportsChain = false,
  });

  /// The method name, e.g. `find`.
  final String method;

  /// How the command is written, shown in `help`.
  final String usage;

  /// One-line description, shown in `help`.
  final String summary;

  /// Whether the UI must ask for confirmation before running it.
  final bool risky;

  /// Whether trailing cursor methods (`.sort()`, `.limit()`, …) are allowed.
  final bool supportsChain;

  final MongoshResult Function(MongoshCollectionContext ctx) run;
}

/// A deliberately small, honest shell (a mongosh-compatible command subset).
///
/// It is **not** a JavaScript REPL: it recognises a fixed command table and
/// says so when a command is not supported, instead of pretending success.
/// See `docs/ui.md` → "Shell".
class MongoshInterpreter {
  MongoshInterpreter({LocalMongoEngine? engine}) : _engineOverride = engine;

  /// Test seam; production reads the global [mongoEngine] at call time so the
  /// shell follows connect / disconnect.
  final LocalMongoEngine? _engineOverride;

  LocalMongoEngine get _engine => _engineOverride ?? mongoEngine;

  /// Top-level commands, in `help` order.
  static final List<MongoshCommand> commands = _buildCommands();

  /// `db.<coll>.<method>` commands, in `help` order.
  static final List<MongoshCollectionCommand> collectionCommands =
      _buildCollectionCommands();

  /// Runs [command] against [dbName]. Never throws: failures come back as a
  /// [MongoshResult] with [MongoshResult.isError] set.
  MongoshResult execute(String command, {required String dbName}) {
    final normalised = _normalise(command);
    if (normalised.isEmpty) return const MongoshResult('');

    final call = _parseCollectionCall(normalised);
    if (call != null) {
      final spec = _collectionCommand(call.method);
      if (spec == null) {
        return MongoshResult(_unsupportedMethod(call.method), isError: true);
      }
      if (call.chain.isNotEmpty && !spec.supportsChain) {
        return MongoshResult(
          'db.<coll>.${call.method}(...) does not support chaining.',
          isError: true,
        );
      }
      try {
        return spec.run(MongoshCollectionContext(
          engine: _engine,
          dbName: dbName,
          call: call,
        ));
      } catch (error) {
        return MongoshResult(_formatError(error), isError: true);
      }
    }

    for (final cmd in commands) {
      final match = cmd.pattern.firstMatch(normalised);
      if (match == null) continue;
      try {
        return cmd.run(MongoshCommandContext(
          engine: _engine,
          dbName: dbName,
          command: normalised,
          match: match,
        ));
      } catch (error) {
        return MongoshResult(_formatError(error), isError: true);
      }
    }
    return MongoshResult(_unsupportedMessage(normalised), isError: true);
  }

  /// Whether [command] needs the risky-operation confirmation.
  bool isRisky(String command) {
    final normalised = _normalise(command);
    final call = _parseCollectionCall(normalised);
    if (call != null) {
      return _collectionCommand(call.method)?.risky ?? false;
    }
    for (final cmd in commands) {
      if (cmd.pattern.hasMatch(normalised)) return cmd.risky;
    }
    return false;
  }

  // --- Help ------------------------------------------------------------------

  /// The `help` listing, generated from the command tables so it cannot go
  /// stale.
  static String helpText() {
    final buffer = StringBuffer('Supported commands:\n');
    for (final cmd in commands) {
      buffer.writeln(_helpLine(cmd.usage, cmd.summary, cmd.risky));
    }
    for (final cmd in collectionCommands) {
      buffer.writeln(_helpLine(cmd.usage, cmd.summary, cmd.risky));
    }
    buffer.write('\nType "help <command>" for details.');
    return buffer.toString();
  }

  /// `help <command>`: usage + summary for one command.
  static String helpFor(String topic) {
    final wanted = topic.trim().toLowerCase();
    for (final cmd in commands) {
      if (cmd.name.toLowerCase() == wanted) {
        return _helpEntry(cmd.usage, cmd.summary, cmd.risky);
      }
    }
    for (final cmd in collectionCommands) {
      if (cmd.method.toLowerCase() == wanted) {
        return _helpEntry(cmd.usage, cmd.summary, cmd.risky);
      }
    }
    return 'No help for "$topic". Type "help" for the list of supported commands.';
  }

  static String _helpLine(String usage, String summary, bool risky) =>
      '  ${usage.padRight(38)}$summary${risky ? '  [risky]' : ''}';

  static String _helpEntry(String usage, String summary, bool risky) {
    final buffer = StringBuffer(usage)
      ..writeln()
      ..write('  $summary');
    if (risky) buffer.write('\n  Requires confirmation before it runs.');
    return buffer.toString();
  }

  // --- Parsing ---------------------------------------------------------------

  static String _normalise(String command) {
    var text = command.trim();
    while (text.endsWith(';')) {
      text = text.substring(0, text.length - 1).trimRight();
    }
    return text;
  }

  static String _formatError(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  /// Honest failure for anything outside the command tables.
  static String _unsupportedMessage(String command) {
    final method =
        RegExp(r'^db\.[A-Za-z0-9_]+\.([A-Za-z0-9_]+)\s*\(').firstMatch(command);
    if (method != null) return _unsupportedMethod(method.group(1)!);
    return 'Unrecognized command: $command\n'
        'Type "help" for the list of supported commands.';
  }

  static String _unsupportedMethod(String method) =>
      'db.<coll>.$method(...) is not supported by this shell yet.\n'
      'Type "help" for the list of supported commands.';

  static MongoshCollectionCommand? _collectionCommand(String method) {
    for (final cmd in collectionCommands) {
      if (cmd.method == method) return cmd;
    }
    return null;
  }

  /// Parses `db.<coll>.<method>(args)` plus any trailing `.method(args)`
  /// segments. Returns `null` when the text is not a well-formed call.
  static MongoshCollectionCall? _parseCollectionCall(String command) {
    final head =
        RegExp(r'^db\.([A-Za-z0-9_]+)\.([A-Za-z0-9_]+)\s*\(').firstMatch(command);
    if (head == null) return null;

    final open = head.end - 1;
    final close = _matchingParen(command, open);
    if (close == null) return null;

    final args = command.substring(open + 1, close);
    var index = close + 1;
    final chain = <MongoshChainSegment>[];
    while (index < command.length) {
      final rest = command.substring(index);
      final segment = RegExp(r'^\s*\.\s*([A-Za-z0-9_]+)\s*\(').firstMatch(rest);
      if (segment == null) return null;
      final segmentOpen = index + segment.end - 1;
      final segmentClose = _matchingParen(command, segmentOpen);
      if (segmentClose == null) return null;
      chain.add(MongoshChainSegment(
        segment.group(1)!,
        command.substring(segmentOpen + 1, segmentClose),
      ));
      index = segmentClose + 1;
    }

    return MongoshCollectionCall(
      collection: head.group(1)!,
      method: head.group(2)!,
      args: args,
      chain: chain,
    );
  }

  /// Index of the `)` matching the `(` at [openIndex], skipping quoted strings.
  static int? _matchingParen(String text, int openIndex) {
    var depth = 0;
    var inSingle = false;
    var inDouble = false;
    var escaped = false;
    for (var i = openIndex; i < text.length; i++) {
      final ch = text[i];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (ch == r'\') {
        escaped = true;
        continue;
      }
      if (inSingle) {
        if (ch == "'") inSingle = false;
        continue;
      }
      if (inDouble) {
        if (ch == '"') inDouble = false;
        continue;
      }
      if (ch == "'") {
        inSingle = true;
        continue;
      }
      if (ch == '"') {
        inDouble = true;
        continue;
      }
      if (ch == '(') depth++;
      if (ch == ')') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return null;
  }

  // --- Value helpers ---------------------------------------------------------

  static Map<String, dynamic> _parseMap(LocalMongoEngine engine, String text) {
    try {
      final parsed = engine.tolerantParse(text);
      return parsed is Map
          ? Map<String, dynamic>.from(parsed)
          : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  /// Splits a two-argument call such as `{...}, { $set: {...} }` at the top
  /// level (commas inside braces/brackets/parens are ignored).
  static (String, String) _splitArgs(String args) {
    var depth = 0;
    for (var i = 0; i < args.length; i++) {
      final ch = args[i];
      if (ch == '{' || ch == '[' || ch == '(') depth++;
      if (ch == '}' || ch == ']' || ch == ')') depth--;
      if (ch == ',' && depth == 0) {
        return (args.substring(0, i), args.substring(i + 1));
      }
    }
    return (args, '{}');
  }

  static String _filterJson(Map<String, dynamic> filter) =>
      filter.isEmpty ? '' : jsonEncode(filter);

  static List<MongoDocument> _matching(
    LocalMongoEngine engine,
    String dbName,
    String collName,
    Map<String, dynamic> filter,
  ) {
    return engine
        .findDocuments(dbName, collName, QueryFilterOptions(
          filter: _filterJson(filter),
        ))
        .documents;
  }

  /// Renders documents the way mongosh does: `ObjectId("…")` for BSON ids and
  /// a `[n docs]` footer (with a hint when the page is truncated).
  static String _formatDocuments(List<MongoDocument> docs, {int? totalCount}) {
    final buffer = StringBuffer(
        _formatValue(docs.map((doc) => doc.data).toList(), 0));
    buffer.write('\n[${docs.length} docs]');
    if (totalCount != null && totalCount > docs.length) {
      buffer.write(' (of $totalCount — add .limit(n) to see more)');
    }
    return buffer.toString();
  }

  static String _formatValue(dynamic value, int indent) {
    final pad = '  ' * indent;
    final childPad = '  ' * (indent + 1);
    if (value is MongoObjectId) return 'ObjectId("${value.hex}")';
    if (value is Map) {
      if (value.isEmpty) return '{}';
      final entries = value.entries.map((entry) =>
          '$childPad${jsonEncode(entry.key.toString())}: '
          '${_formatValue(entry.value, indent + 1)}');
      return '{\n${entries.join(',\n')}\n$pad}';
    }
    if (value is List) {
      if (value.isEmpty) return '[]';
      final items =
          value.map((item) => '$childPad${_formatValue(item, indent + 1)}');
      return '[\n${items.join(',\n')}\n$pad]';
    }
    return jsonEncode(value);
  }

  // --- Top-level command table ----------------------------------------------

  static List<MongoshCommand> _buildCommands() {
    return [
      MongoshCommand(
        name: 'help',
        usage: 'help [command]',
        summary: 'list the supported commands, or explain one',
        pattern: RegExp(r'^help(?:\s+(.+))?$'),
        run: (ctx) {
          final topic = ctx.match.group(1);
          return MongoshResult(topic == null ? helpText() : helpFor(topic));
        },
      ),
      MongoshCommand(
        name: 'show dbs',
        usage: 'show dbs',
        summary: 'list database names',
        pattern: RegExp(r'^show\s+dbs$'),
        run: (ctx) {
          final dbs = ctx.engine.getDatabases();
          if (dbs.isEmpty) return const MongoshResult('[]');
          return MongoshResult(dbs.map((db) => db.name).join('\n'));
        },
      ),
      MongoshCommand(
        name: 'show collections',
        usage: 'show collections',
        summary: 'list collections in the current database',
        pattern: RegExp(r'^show\s+collections$'),
        run: (ctx) {
          final db = ctx.engine.getDatabase(ctx.dbName);
          final names = db?.collections.keys.toList() ?? const <String>[];
          return MongoshResult(names.isEmpty ? '[]' : names.join('\n'));
        },
      ),
      MongoshCommand(
        name: 'use',
        usage: 'use <database>',
        summary: 'switch the current database',
        pattern: RegExp(r'^use\s+(\S+)$'),
        run: (ctx) {
          final name = ctx.match.group(1)!;
          if (ctx.engine.getDatabase(name) == null) {
            return MongoshResult(
              'Database "$name" does not exist.\n'
              'Create it from the sidebar (New Database) first.',
              isError: true,
            );
          }
          return MongoshResult(
            'switched to db $name',
            sideEffect: MongoshSideEffect(
              MongoshSideEffectKind.switchDatabase,
              database: name,
            ),
          );
        },
      ),
      MongoshCommand(
        name: 'db.getName',
        usage: 'db.getName()',
        summary: 'show the current database name',
        pattern: RegExp(r'^db\.getName\s*\(\s*\)$'),
        run: (ctx) => MongoshResult(ctx.dbName.isEmpty ? 'test' : ctx.dbName),
      ),
      MongoshCommand(
        name: 'db.getCollectionNames',
        usage: 'db.getCollectionNames()',
        summary: 'list the current database collections as an array',
        pattern: RegExp(r'^db\.getCollectionNames\s*\(\s*\)$'),
        run: (ctx) {
          final db = ctx.engine.getDatabase(ctx.dbName);
          final names = db?.collections.keys.toList() ?? const <String>[];
          return MongoshResult(_formatValue(names, 0));
        },
      ),
      MongoshCommand(
        name: 'print',
        usage: 'print(value)',
        summary: 'print a value',
        pattern: RegExp(r'^print\s*\((.*)\)$', dotAll: true),
        run: (ctx) {
          final raw = (ctx.match.group(1) ?? '').trim();
          return MongoshResult(_unquote(raw));
        },
      ),
      MongoshCommand(
        name: 'JSON.stringify',
        usage: 'JSON.stringify(value)',
        summary: 'render a value as compact JSON',
        pattern: RegExp(r'^JSON\.stringify\s*\((.*)\)$', dotAll: true),
        run: (ctx) {
          final raw = (ctx.match.group(1) ?? '').trim();
          try {
            return MongoshResult(jsonEncode(ctx.engine.tolerantParse(raw)));
          } catch (_) {
            return MongoshResult(_unquote(raw));
          }
        },
      ),
      MongoshCommand(
        name: 'dropDatabase',
        usage: 'db.dropDatabase()',
        summary: 'drop the current database',
        risky: true,
        pattern: RegExp(r'^db\.dropDatabase\s*\(\s*\)$'),
        run: (ctx) {
          ctx.engine.dropDatabase(ctx.dbName);
          return MongoshResult(
            '{ "dropped": "${ctx.dbName}", "ok": 1 }',
            sideEffect: MongoshSideEffect(
              MongoshSideEffectKind.dropDatabase,
              database: ctx.dbName,
            ),
          );
        },
      ),
    ];
  }

  /// Default index name for a key spec, e.g. `{ title: 1 }` → `title_1`.
  static String _defaultIndexName(Map<String, dynamic> keys) =>
      keys.entries.map((entry) => '${entry.key}_${entry.value}').join('_');

  static String _unquote(String text) {
    if (text.length >= 2) {
      final first = text[0];
      final last = text[text.length - 1];
      if ((first == '"' && last == '"') || (first == "'" && last == "'")) {
        return text.substring(1, text.length - 1);
      }
    }
    return text;
  }

  // --- Collection-method table ----------------------------------------------

  static List<MongoshCollectionCommand> _buildCollectionCommands() {
    return [
      MongoshCollectionCommand(
        method: 'find',
        usage: 'db.<coll>.find(filter)',
        summary: 'query a collection (chain .sort/.limit/.skip/.count)',
        supportsChain: true,
        run: (ctx) {
          final options = QueryFilterOptions(filter: ctx.call.args.trim());
          var countOnly = false;
          for (final segment in ctx.call.chain) {
            switch (segment.method) {
              case 'sort':
                options.sort = segment.args.trim();
              case 'limit':
                final value = int.tryParse(segment.args.trim());
                if (value == null) {
                  return const MongoshResult('limit() expects a number.',
                      isError: true);
                }
                options.limit = value;
              case 'skip':
                final value = int.tryParse(segment.args.trim());
                if (value == null) {
                  return const MongoshResult('skip() expects a number.',
                      isError: true);
                }
                options.skip = value;
              case 'count':
                countOnly = true;
              case 'pretty':
              case 'toArray':
                break; // no-ops, accepted for mongosh compatibility
              default:
                return MongoshResult(
                  'db.<coll>.find().${segment.method}(...) is not supported by '
                  'this shell yet.',
                  isError: true,
                );
            }
          }
          final result = ctx.engine.findDocuments(
              ctx.dbName, ctx.call.collection, options);
          if (countOnly) return MongoshResult('${result.totalCount}');
          return MongoshResult(_formatDocuments(
            result.documents,
            totalCount: result.totalCount,
          ));
        },
      ),
      MongoshCollectionCommand(
        method: 'findOne',
        usage: 'db.<coll>.findOne(filter)',
        summary: 'return the first matching document',
        run: (ctx) {
          final result = ctx.engine.findDocuments(
            ctx.dbName,
            ctx.call.collection,
            QueryFilterOptions(filter: ctx.call.args.trim(), limit: 1),
          );
          if (result.documents.isEmpty) return const MongoshResult('null');
          return MongoshResult(_formatValue(result.documents.first.data, 0));
        },
      ),
      MongoshCollectionCommand(
        method: 'countDocuments',
        usage: 'db.<coll>.countDocuments(filter)',
        summary: 'count the matching documents',
        run: (ctx) {
          final result = ctx.engine.findDocuments(
            ctx.dbName,
            ctx.call.collection,
            QueryFilterOptions(filter: ctx.call.args.trim()),
          );
          return MongoshResult('${result.totalCount}');
        },
      ),
      MongoshCollectionCommand(
        method: 'count',
        usage: 'db.<coll>.count(filter)',
        summary: 'count the matching documents (legacy alias)',
        run: (ctx) {
          final result = ctx.engine.findDocuments(
            ctx.dbName,
            ctx.call.collection,
            QueryFilterOptions(filter: ctx.call.args.trim()),
          );
          return MongoshResult('${result.totalCount}');
        },
      ),
      MongoshCollectionCommand(
        method: 'distinct',
        usage: 'db.<coll>.distinct(field, filter)',
        summary: 'list the distinct values of a field',
        run: (ctx) {
          final split = _splitArgs(ctx.call.args);
          final field = _unquote(split.$1.trim());
          if (field.isEmpty) {
            return const MongoshResult(
                'distinct() expects a field name, e.g. distinct("genre").',
                isError: true);
          }
          final filter = _parseMap(ctx.engine, split.$2);
          final values = ctx.engine.distinct(
              ctx.dbName, ctx.call.collection, field, filter);
          return MongoshResult(_formatValue(values, 0));
        },
      ),
      MongoshCollectionCommand(
        method: 'aggregate',
        usage: 'db.<coll>.aggregate([...])',
        summary: 'run an aggregation pipeline',
        run: (ctx) {
          final parsed = ctx.engine.tolerantParse(ctx.call.args);
          if (parsed is! List) {
            return const MongoshResult(
                'aggregate() expects a pipeline array, e.g. aggregate([{ \$match: {} }]).',
                isError: true);
          }
          final result = ctx.engine.runAggregation(
              ctx.dbName, ctx.call.collection, parsed);
          return MongoshResult(_formatDocuments(
            result.documents,
            totalCount: result.totalCount,
          ));
        },
      ),
      MongoshCollectionCommand(
        method: 'insertOne',
        usage: 'db.<coll>.insertOne(doc)',
        summary: 'insert a document',
        run: (ctx) {
          final doc = _parseMap(ctx.engine, ctx.call.args);
          final inserted = ctx.engine.insertDocument(
              ctx.dbName, ctx.call.collection, doc);
          return MongoshResult(
              '{ "acknowledged": true, "insertedId": "${inserted.id}" }');
        },
      ),
      MongoshCollectionCommand(
        method: 'insertMany',
        usage: 'db.<coll>.insertMany([...])',
        summary: 'insert several documents',
        run: (ctx) {
          final parsed = ctx.engine.tolerantParse(ctx.call.args);
          if (parsed is! List) {
            return const MongoshResult(
                'insertMany() expects an array of documents.',
                isError: true);
          }
          final ids = <String>[];
          for (final doc in parsed) {
            if (doc is! Map) {
              return const MongoshResult(
                  'insertMany() expects an array of documents.',
                  isError: true);
            }
            final inserted = ctx.engine.insertDocument(
              ctx.dbName,
              ctx.call.collection,
              Map<String, dynamic>.from(doc),
            );
            ids.add(inserted.id);
          }
          return MongoshResult(
              '{ "acknowledged": true, "insertedIds": ${jsonEncode(ids)} }');
        },
      ),
      MongoshCollectionCommand(
        method: 'updateOne',
        usage: 'db.<coll>.updateOne(filter, update)',
        summary: 'update the first matching document',
        risky: true,
        run: (ctx) {
          final split = _splitArgs(ctx.call.args);
          final filter = _parseMap(ctx.engine, split.$1);
          final update = _parseMap(ctx.engine, split.$2);
          final docs = _matching(
              ctx.engine, ctx.dbName, ctx.call.collection, filter);
          if (docs.isEmpty) {
            return const MongoshResult(
                '{ "acknowledged": true, "matchedCount": 0, "modifiedCount": 0, "upsertedId": null }');
          }
          ctx.engine.updateDocument(
              ctx.dbName, ctx.call.collection, docs.first.id, update);
          return const MongoshResult(
              '{ "acknowledged": true, "matchedCount": 1, "modifiedCount": 1, "upsertedId": null }');
        },
      ),
      MongoshCollectionCommand(
        method: 'updateMany',
        usage: 'db.<coll>.updateMany(filter, update)',
        summary: 'update every matching document',
        risky: true,
        run: (ctx) {
          final split = _splitArgs(ctx.call.args);
          final filter = _parseMap(ctx.engine, split.$1);
          final update = _parseMap(ctx.engine, split.$2);
          final matched = _matching(
                  ctx.engine, ctx.dbName, ctx.call.collection, filter)
              .length;
          final modified = ctx.engine.updateMany(
              ctx.dbName, ctx.call.collection, filter, update);
          return MongoshResult(
              '{ "acknowledged": true, "matchedCount": $matched, "modifiedCount": $modified, "upsertedId": null }');
        },
      ),
      MongoshCollectionCommand(
        method: 'replaceOne',
        usage: 'db.<coll>.replaceOne(filter, doc)',
        summary: 'replace the first matching document',
        risky: true,
        run: (ctx) {
          final split = _splitArgs(ctx.call.args);
          final filter = _parseMap(ctx.engine, split.$1);
          final replacement = _parseMap(ctx.engine, split.$2);
          final docs = _matching(
              ctx.engine, ctx.dbName, ctx.call.collection, filter);
          if (docs.isEmpty) {
            return const MongoshResult(
                '{ "acknowledged": true, "matchedCount": 0, "modifiedCount": 0, "upsertedId": null }');
          }
          ctx.engine.updateDocument(
              ctx.dbName, ctx.call.collection, docs.first.id, replacement);
          return const MongoshResult(
              '{ "acknowledged": true, "matchedCount": 1, "modifiedCount": 1, "upsertedId": null }');
        },
      ),
      MongoshCollectionCommand(
        method: 'deleteOne',
        usage: 'db.<coll>.deleteOne(filter)',
        summary: 'delete the first matching document',
        risky: true,
        run: (ctx) {
          final filter = _parseMap(ctx.engine, ctx.call.args);
          final deleted = ctx.engine.deleteOne(
              ctx.dbName, ctx.call.collection, filter);
          return MongoshResult(
              '{ "acknowledged": true, "deletedCount": ${deleted ? 1 : 0} }');
        },
      ),
      MongoshCollectionCommand(
        method: 'deleteMany',
        usage: 'db.<coll>.deleteMany(filter)',
        summary: 'delete every matching document',
        risky: true,
        run: (ctx) {
          final filter = _parseMap(ctx.engine, ctx.call.args);
          final deleted = ctx.engine.deleteMany(
              ctx.dbName, ctx.call.collection, filter);
          return MongoshResult(
              '{ "acknowledged": true, "deletedCount": $deleted }');
        },
      ),
      MongoshCollectionCommand(
        method: 'remove',
        usage: 'db.<coll>.remove(filter)',
        summary: 'delete every matching document (legacy alias)',
        risky: true,
        run: (ctx) {
          final filter = _parseMap(ctx.engine, ctx.call.args);
          final deleted = ctx.engine.deleteMany(
              ctx.dbName, ctx.call.collection, filter);
          return MongoshResult(
              '{ "acknowledged": true, "deletedCount": $deleted }');
        },
      ),
      MongoshCollectionCommand(
        method: 'createIndex',
        usage: 'db.<coll>.createIndex(keys, options)',
        summary: 'create an index',
        run: (ctx) {
          final split = _splitArgs(ctx.call.args);
          final keys = _parseMap(ctx.engine, split.$1);
          if (keys.isEmpty) {
            return const MongoshResult(
                'createIndex() expects a key spec, e.g. createIndex({ title: 1 }).',
                isError: true);
          }
          final options = _parseMap(ctx.engine, split.$2);
          final name = (options['name'] as String?) ?? _defaultIndexName(keys);
          final coll = ctx.engine.getCollection(ctx.dbName, ctx.call.collection);
          final before = coll?.indexes.length ?? 0;
          final created = ctx.engine.createIndex(
            ctx.dbName,
            ctx.call.collection,
            MongoIndex(
              name: name,
              keys: keys,
              unique: options['unique'] == true,
              sparse: options['sparse'] == true,
            ),
          );
          if (!created) {
            return MongoshResult('Index "$name" already exists.', isError: true);
          }
          return MongoshResult(
              '{ "createdCollectionAutomatically": false, "numIndexesBefore": $before, "numIndexesAfter": ${before + 1}, "ok": 1 }');
        },
      ),
      MongoshCollectionCommand(
        method: 'getIndexes',
        usage: 'db.<coll>.getIndexes()',
        summary: 'list the collection indexes',
        run: (ctx) {
          final coll = ctx.engine.getCollection(ctx.dbName, ctx.call.collection);
          final indexes = coll?.indexes ?? const <MongoIndex>[];
          final list = indexes
              .map((index) => <String, dynamic>{
                    'name': index.name,
                    'key': index.keys,
                    'unique': index.unique,
                    'sparse': index.sparse,
                  })
              .toList();
          return MongoshResult(_formatValue(list, 0));
        },
      ),
      MongoshCollectionCommand(
        method: 'dropIndex',
        usage: 'db.<coll>.dropIndex(name)',
        summary: 'drop an index (or "*" for all but _id_)',
        run: (ctx) {
          final name = _unquote(ctx.call.args.trim());
          if (name.isEmpty) {
            return const MongoshResult(
                'dropIndex() expects an index name, e.g. dropIndex("title_1").',
                isError: true);
          }
          final coll = ctx.engine.getCollection(ctx.dbName, ctx.call.collection);
          final before = coll?.indexes.length ?? 0;
          if (name == '*') {
            final names = coll?.indexes
                    .where((index) => index.name != '_id_')
                    .map((index) => index.name)
                    .toList() ??
                const <String>[];
            for (final indexName in names) {
              ctx.engine.dropIndex(
                  ctx.dbName, ctx.call.collection, indexName);
            }
            return MongoshResult('{ "nIndexesWas": $before, "ok": 1 }');
          }
          final dropped =
              ctx.engine.dropIndex(ctx.dbName, ctx.call.collection, name);
          if (!dropped) {
            return MongoshResult('Index "$name" does not exist.', isError: true);
          }
          return MongoshResult('{ "nIndexesWas": $before, "ok": 1 }');
        },
      ),
      MongoshCollectionCommand(
        method: 'stats',
        usage: 'db.<coll>.stats()',
        summary: 'show collection statistics',
        run: (ctx) {
          final coll = ctx.engine.getCollection(ctx.dbName, ctx.call.collection);
          if (coll == null) {
            return MongoshResult(
                'Collection "${ctx.call.collection}" does not exist.',
                isError: true);
          }
          final count = coll.documents.length;
          final size = coll.documents.fold<int>(
              0, (sum, doc) => sum + jsonEncode(doc.data).length);
          return MongoshResult(_formatValue(<String, dynamic>{
            'ns': '${ctx.dbName}.${ctx.call.collection}',
            'count': count,
            'size': size,
            'avgObjSize': count == 0 ? 0 : (size / count).round(),
            'nindexes': coll.indexes.length,
            'indexes': coll.indexes.map((index) => index.name).toList(),
          }, 0));
        },
      ),
      MongoshCollectionCommand(
        method: 'drop',
        usage: 'db.<coll>.drop()',
        summary: 'drop the collection',
        risky: true,
        run: (ctx) {
          ctx.engine.dropCollection(ctx.dbName, ctx.call.collection);
          return MongoshResult(
            'true',
            sideEffect: MongoshSideEffect(
              MongoshSideEffectKind.dropCollection,
              database: ctx.dbName,
              collection: ctx.call.collection,
            ),
          );
        },
      ),
    ];
  }
}
