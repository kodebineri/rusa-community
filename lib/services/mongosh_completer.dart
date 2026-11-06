import 'local_mongo_engine.dart';
import 'mongo_engine.dart';
import 'mongosh_interpreter.dart';

/// One Tab-completion result.
class MongoshCompletion {
  const MongoshCompletion({
    required this.token,
    required this.candidates,
    this.appendSpace = false,
  });

  /// The partial word being completed (the trailing run of non-space chars).
  final String token;

  /// Every candidate that starts with [token], sorted.
  final List<String> candidates;

  /// Whether a unique match should be followed by a space (word contexts such
  /// as `use` / `show` / `help`, but not `db.<coll>.` method names).
  final bool appendSpace;

  /// The only candidate, when the match is unambiguous.
  String? get single => candidates.length == 1 ? candidates.first : null;

  /// Longest common prefix of [candidates] (bash-style partial completion).
  String get commonPrefix {
    if (candidates.isEmpty) return '';
    var prefix = candidates.first;
    for (final candidate in candidates.skip(1)) {
      var i = 0;
      while (i < prefix.length &&
          i < candidate.length &&
          prefix[i] == candidate[i]) {
        i++;
      }
      prefix = prefix.substring(0, i);
      if (prefix.isEmpty) break;
    }
    return prefix;
  }
}

/// Tab completion for the shell prompt.
///
/// Pure Dart (no widgets) so it can be unit-tested; it reads the same command
/// table as [MongoshInterpreter], so method completion cannot drift from the
/// commands the shell actually supports.
class MongoshCompleter {
  MongoshCompleter({LocalMongoEngine? engine}) : _engineOverride = engine;

  /// Test seam; production reads the global [mongoEngine] at call time.
  final LocalMongoEngine? _engineOverride;

  LocalMongoEngine get _engine => _engineOverride ?? mongoEngine;

  /// Completes the word at the end of [input], or returns `null` when the
  /// cursor is not in a completable position.
  MongoshCompletion? complete(String input, {required String dbName}) {
    final useMatch = RegExp(r'^use\s+(\S*)$').firstMatch(input);
    if (useMatch != null) {
      return _build(useMatch.group(1)!, _databaseNames(), appendSpace: true);
    }

    final showMatch = RegExp(r'^show\s+(\S*)$').firstMatch(input);
    if (showMatch != null) {
      return _build(showMatch.group(1)!, const ['dbs', 'collections'],
          appendSpace: true);
    }

    final helpMatch = RegExp(r'^help\s+(\S*)$').firstMatch(input);
    if (helpMatch != null) {
      return _build(helpMatch.group(1)!, _helpTopics(), appendSpace: true);
    }

    final methodMatch =
        RegExp(r'^db\.([A-Za-z0-9_]+)\.(\w*)$').firstMatch(input);
    if (methodMatch != null) {
      return _build(methodMatch.group(2)!, _methodNames());
    }

    final collectionMatch = RegExp(r'^db\.(\w*)$').firstMatch(input);
    if (collectionMatch != null) {
      return _build(collectionMatch.group(1)!, _collectionNames(dbName));
    }

    return null;
  }

  MongoshCompletion? _build(
    String token,
    Iterable<String> all, {
    bool appendSpace = false,
  }) {
    final matches = all.where((candidate) => candidate.startsWith(token)).toList()
      ..sort();
    if (matches.isEmpty) return null;
    // Already complete: nothing to insert (Tab is a no-op).
    if (matches.length == 1 && matches.first == token) return null;
    return MongoshCompletion(
      token: token,
      candidates: matches,
      appendSpace: appendSpace,
    );
  }

  Iterable<String> _databaseNames() =>
      _engine.getDatabases().map((db) => db.name);

  Iterable<String> _collectionNames(String dbName) =>
      _engine.getDatabase(dbName)?.collections.keys ?? const <String>[];

  /// Method names from the interpreter's collection-command table.
  Iterable<String> _methodNames() =>
      MongoshInterpreter.collectionCommands.map((command) => command.method);

  /// First word of every command name, for `help <topic>`.
  Iterable<String> _helpTopics() => {
        ...MongoshInterpreter.commands
            .map((command) => command.name.split(' ').first),
        ...MongoshInterpreter.collectionCommands
            .map((command) => command.method),
      };
}

/// Whether [text] has more opening brackets than closing ones, ignoring
/// brackets inside quoted strings.
///
/// The prompt uses this to decide whether Enter should submit the command or
/// continue on a new line (mongosh-style multi-line input).
bool hasUnbalancedBrackets(String text) {
  var depth = 0;
  var inSingle = false;
  var inDouble = false;
  var escaped = false;
  for (var i = 0; i < text.length; i++) {
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
    if (ch == '{' || ch == '[' || ch == '(') depth++;
    if (ch == '}' || ch == ']' || ch == ')') depth--;
  }
  return depth > 0;
}
