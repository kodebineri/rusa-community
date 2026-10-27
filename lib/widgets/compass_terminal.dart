import 'dart:convert';
import 'package:flutter/widgets.dart';
import '../theme/compass_colors.dart';
import '../theme/compass_density.dart';
import '../theme/compass_typography.dart';
import '../icons/compass_svg_icons.dart';
import '../services/mongo_engine.dart';
import '../models/mongo_models.dart';
import 'compass_icon_button.dart';
import 'compass_text_menu.dart';
import 'modals/mongosh_confirmation_modal.dart';

/// Converted from src/components/MongoshTerminal.tsx
/// Adheres strictly to:
/// 1. Layout & Flexbox (docked bottom drawer, header row, scrollable log, prompt row)
/// 2. Color & Styling (Color(0xFF080B0E), Color(0xFF11161B), Color(0xFF21313C))
/// 3. Typography (CompassTypography.terminal with JetBrains Mono)
/// 4. Platform Agnosticism (desktop dockable bottom terminal)
/// 5. Icons (CompassSvg instead of generic Icon)
class CompassTerminal extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final String activeDbName;
  final Function(String command)? onExecuteCommand;
  final void Function(RiskyOperationDetails operation, VoidCallback onConfirm)? onRequestConfirmation;

  const CompassTerminal({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.activeDbName,
    this.onExecuteCommand,
    this.onRequestConfirmation,
  });

  @override
  State<CompassTerminal> createState() => _CompassTerminalState();
}

class _CompassTerminalState extends State<CompassTerminal> {
  bool _isExpanded = false;
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocus = FocusNode(debugLabel: 'mongosh-input');

  /// Anchors the text context menu to the prompt row.
  late final LayerLink _menuAnchor = LayerLink();

  final List<Map<String, String>> _history = [
    {
      'prompt': 'mongosh',
      'command': '',
      'output': 'Connecting to: mongodb://127.0.0.1:27017/?directConnection=true\nUsing MongoDB: 7.0.8\nUsing Mongosh: 2.2.0\nType "help" for a list of available commands.',
    },
  ];

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _submitInput() {
    final command = _inputController.text.trim();
    if (command.isEmpty) return;
    _inputController.text = '';
    final risky = _detectRisky(command);
    if (risky != null && widget.onRequestConfirmation != null) {
      widget.onRequestConfirmation!(risky, () => _runCommand(command));
    } else {
      _runCommand(command);
    }
  }

  void _runCommand(String command) {
    widget.onExecuteCommand?.call(command);
    if (!mounted) return;
    setState(() {
      _history.add({
        'prompt': widget.activeDbName.isEmpty ? 'test' : widget.activeDbName,
        'command': command,
        'output': _executeReal(command),
      });
    });
  }

  (String, String) _splitArgsTerminal(String args) {
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

  Map<String, dynamic> _parseMapTerminal(String text) {
    try {
      final parsed = mongoEngine.tolerantParse(text);
      return parsed is Map ? Map<String, dynamic>.from(parsed) : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  String _executeReal(String command) {
    final c = command.trim();
    if (c == 'help') {
      return '  show dbs                     show database names\n'
          '  show collections             show collections in current database\n'
          '  db.<coll>.find(filter)       query a collection\n'
          '  db.<coll>.insertOne(doc)     insert a document\n'
          '  db.<coll>.updateOne(filter, update)\n'
          '  db.<coll>.updateMany(filter, update)\n'
          '  db.<coll>.deleteOne(filter)\n'
          '  db.<coll>.deleteMany(filter) delete matching documents [Risky Confirmation]\n'
          '  db.dropDatabase()            drop current database [Risky Confirmation]';
    }
    if (c == 'show dbs') {
      try {
        final dbs = mongoEngine.getDatabases();
        if (dbs.isEmpty) return '[]';
        return dbs.map((d) => d.name).join('\n');
      } catch (e) {
        return '$e';
      }
    }
    if (c == 'show collections') {
      try {
        final dbName = widget.activeDbName;
        if (dbName.isEmpty) return '[]';
        final db = mongoEngine.getDatabase(dbName);
        if (db == null) return '[]';
        final cols = db.collections.keys.toList();
        if (cols.isEmpty) return '[]';
        return cols.join('\n');
      } catch (e) {
        return '$e';
      }
    }
    if (c.startsWith('use ')) {
      return 'switched to db ${c.substring(4).trim().replaceAll(RegExp(r';$'), '').trim()}';
    }
    // db.<coll>.find({...})
    final findMatch = RegExp(r'db\.([A-Za-z0-9_]+)\.find\s*\((.*)\)\s*;?\s*$', dotAll: true).firstMatch(c);
    if (findMatch != null) {
      try {
        final collName = findMatch.group(1)!;
        final args = findMatch.group(2) ?? '';
        Map<String, dynamic> filter = {};
        if (args.trim().isNotEmpty) {
          try {
            final parsed = mongoEngine.tolerantParse(args);
            if (parsed is Map) {
              filter = Map<String, dynamic>.from(parsed);
            }
          } catch (_) {}
        }
        final res2 = mongoEngine.findDocuments(widget.activeDbName, collName, QueryFilterOptions(filter: filter.isEmpty ? '' : jsonEncode(filter)));
        final docs = res2.documents;
        final list = docs.map((d) => d.data).toList();
        const encoder = JsonEncoder.withIndent('  ');
        return encoder.convert(list);
      } catch (e) {
        return '$e';
      }
    }
    // db.<coll>.updateOne(filter, update)
    final updateOneMatch = RegExp(r'db\.([A-Za-z0-9_]+)\.updateOne\s*\((.*)\)\s*;?\s*$', dotAll: true).firstMatch(c);
    if (updateOneMatch != null) {
      try {
        final collName = updateOneMatch.group(1)!;
        final args = updateOneMatch.group(2) ?? '';
        final split = _splitArgsTerminal(args);
        final filter = _parseMapTerminal(split.$1);
        final update = _parseMapTerminal(split.$2);
        // Try to update first matching document
        final res = mongoEngine.findDocuments(widget.activeDbName, collName, QueryFilterOptions(filter: filter.isEmpty ? '' : jsonEncode(filter)));
        if (res.documents.isEmpty) {
          return '{ "acknowledged": true, "matchedCount": 0, "modifiedCount": 0, "upsertedId": null }';
        }
        final docId = res.documents.first.id;
        mongoEngine.updateDocument(widget.activeDbName, collName, docId, update);
        return '{ "acknowledged": true, "matchedCount": 1, "modifiedCount": 1, "upsertedId": null }';
      } catch (e) {
        return '$e';
      }
    }
    // db.<coll>.updateMany(filter, update)
    final updateManyMatch = RegExp(r'db\.([A-Za-z0-9_]+)\.updateMany\s*\((.*)\)\s*;?\s*$', dotAll: true).firstMatch(c);
    if (updateManyMatch != null) {
      try {
        final collName = updateManyMatch.group(1)!;
        final args = updateManyMatch.group(2) ?? '';
        final split = _splitArgsTerminal(args);
        final filter = _parseMapTerminal(split.$1);
        final update = _parseMapTerminal(split.$2);
        final res = mongoEngine.findDocuments(widget.activeDbName, collName, QueryFilterOptions(filter: filter.isEmpty ? '' : jsonEncode(filter)));
        int modified = 0;
        for (final d in res.documents) {
          try {
            mongoEngine.updateDocument(widget.activeDbName, collName, d.id, update);
            modified++;
          } catch (_) {}
        }
        return '{ "acknowledged": true, "matchedCount": ${res.documents.length}, "modifiedCount": $modified, "upsertedId": null }';
      } catch (e) {
        return '$e';
      }
    }
    // db.<coll>.deleteOne(filter)
    final deleteOneMatch = RegExp(r'db\.([A-Za-z0-9_]+)\.deleteOne\s*\((.*)\)\s*;?\s*$', dotAll: true).firstMatch(c);
    if (deleteOneMatch != null) {
      try {
        final collName = deleteOneMatch.group(1)!;
        final args = deleteOneMatch.group(2) ?? '';
        final filter = _parseMapTerminal(args);
        final res = mongoEngine.findDocuments(widget.activeDbName, collName, QueryFilterOptions(filter: filter.isEmpty ? '' : jsonEncode(filter)));
        if (res.documents.isEmpty) {
          return '{ "acknowledged": true, "deletedCount": 0 }';
        }
        mongoEngine.deleteDocument(widget.activeDbName, collName, res.documents.first.id);
        return '{ "acknowledged": true, "deletedCount": 1 }';
      } catch (e) {
        return '$e';
      }
    }
    // db.<coll>.deleteMany(filter)
    final deleteManyMatch = RegExp(r'db\.([A-Za-z0-9_]+)\.deleteMany\s*\((.*)\)\s*;?\s*$', dotAll: true).firstMatch(c);
    if (deleteManyMatch != null) {
      try {
        final collName = deleteManyMatch.group(1)!;
        final args = deleteManyMatch.group(2) ?? '';
        final filter = _parseMapTerminal(args);
        final res = mongoEngine.findDocuments(widget.activeDbName, collName, QueryFilterOptions(filter: filter.isEmpty ? '' : jsonEncode(filter)));
        int deleted = 0;
        for (final d in res.documents) {
          try {
            mongoEngine.deleteDocument(widget.activeDbName, collName, d.id);
            deleted++;
          } catch (_) {}
        }
        return '{ "acknowledged": true, "deletedCount": $deleted }';
      } catch (e) {
        return '$e';
      }
    }
    if (c.startsWith('db.') || c.startsWith('show ') || c.startsWith('use ')) {
      return 'Command acknowledged.';
    }
    return 'Unrecognized command. Type "help" for a list of commands.';
  }

  /// Detects destructive/risky commands so the UI can require confirmation.
  RiskyOperationDetails? _detectRisky(String command) {
    final cmd = command.trim();

    if (RegExp(r'db\.dropDatabase\s*\(\s*\)').hasMatch(cmd)) {
      return RiskyOperationDetails(
        type: 'dropDatabase',
        title: 'Drop Database',
        command: cmd,
        dbName: widget.activeDbName,
        description: 'This will permanently drop the entire database.',
        impact: 'All collections, documents and indexes in "${widget.activeDbName}" will be destroyed.',
      );
    }

    final collMatch = RegExp(r'db\.([A-Za-z0-9_]+)\.(\w+)\s*\(').firstMatch(cmd);
    if (collMatch == null) return null;
    final collName = collMatch.group(1)!;
    final method = collMatch.group(2)!;

    if (method == 'drop') {
      return RiskyOperationDetails(
        type: 'dropCollection',
        title: 'Drop Collection',
        command: cmd,
        dbName: widget.activeDbName,
        collName: collName,
        description: 'This will permanently drop the collection.',
        impact: 'All documents and indexes in "${widget.activeDbName}.$collName" will be removed.',
      );
    }
    if (method == 'deleteMany' || method == 'remove') {
      return RiskyOperationDetails(
        type: 'deleteMany',
        title: 'Delete Many Documents',
        command: cmd,
        dbName: widget.activeDbName,
        collName: collName,
        description: 'This will delete all documents matching the filter.',
        impact: 'Documents in "${widget.activeDbName}.$collName" matching the filter will be permanently removed.',
      );
    }
    if (method == 'deleteOne') {
      return RiskyOperationDetails(
        type: 'deleteOne',
        title: 'Delete Document',
        command: cmd,
        dbName: widget.activeDbName,
        collName: collName,
        description: 'This will delete a single matching document.',
        impact: 'The first matching document in "${widget.activeDbName}.$collName" will be permanently removed.',
      );
    }
    if (method == 'updateMany') {
      return RiskyOperationDetails(
        type: 'updateMany',
        title: 'Update Many Documents',
        command: cmd,
        dbName: widget.activeDbName,
        collName: collName,
        description: 'This will modify all documents matching the filter.',
        impact: 'Documents in "${widget.activeDbName}.$collName" matching the filter will be modified.',
      );
    }
    if (method == 'updateOne') {
      return RiskyOperationDetails(
        type: 'updateOne',
        title: 'Update Document',
        command: cmd,
        dbName: widget.activeDbName,
        collName: collName,
        description: 'This will modify a single matching document.',
        impact: 'The first matching document in "${widget.activeDbName}.$collName" will be modified.',
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOpen) return const SizedBox.shrink();

    final CompassDensity density = CompassDensity.of(context);

    return Container(
      height: _isExpanded ? 380.0 : 220.0,
      decoration: const BoxDecoration(
        color: Color(0xFF080B0E),
        border: Border(
          top: BorderSide(color: Color(0xFF21313C), width: 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 16.0,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Container(
            height: 36.0,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            decoration: const BoxDecoration(
              color: Color(0xFF11161B),
              border: Border(
                bottom: BorderSide(color: Color(0xFF21313C), width: 1.0),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const CompassSvg(
                      svgString: CompassSvgIcons.terminal,
                      size: 14.0,
                      color: CompassColors.greenAccent,
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      '_mongosh',
                      style: CompassTypography.monoBold(color: const Color(0xFFF1F5F9), size: 12.0),
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      'mongodb://127.0.0.1:27017 (${widget.activeDbName})',
                      style: CompassTypography.monoSmall(color: CompassColors.darkTextMuted),
                    ),
                  ],
                ),
                // Terminal Header Controls
                Row(
                  children: [
                    CompassIconButton(
                      svgString: CompassSvgIcons.trash,
                      onTap: () {
                        setState(() {
                          _history.clear();
                        });
                      },
                      size: 13.0,
                      padding: 4.0,
                      color: CompassColors.darkTextMuted,
                      hoverBackground: const Color(0x14FFFFFF),
                      semanticLabel: 'Clear terminal history',
                    ),
                    const SizedBox(width: 6.0),
                    CompassIconButton(
                      svgString: _isExpanded ? CompassSvgIcons.chevronDown : CompassSvgIcons.chevronUp,
                      onTap: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                      size: 13.0,
                      padding: 4.0,
                      color: CompassColors.darkTextMuted,
                      hoverBackground: const Color(0x14FFFFFF),
                      semanticLabel: _isExpanded ? 'Collapse terminal' : 'Expand terminal',
                    ),
                    const SizedBox(width: 6.0),
                    CompassIconButton(
                      svgString: CompassSvgIcons.close,
                      onTap: widget.onClose,
                      size: 13.0,
                      padding: 4.0,
                      color: CompassColors.darkTextMuted,
                      hoverBackground: const Color(0x14FFFFFF),
                      semanticLabel: 'Close terminal',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Output History Scroll Area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final item in _history) ...[
                    if (item['command']!.isNotEmpty)
                      Row(
                        children: [
                          Text(
                            '${widget.activeDbName}> ',
                            style: CompassTypography.monoBold(color: CompassColors.greenAccent, size: 12.0),
                          ),
                          Text(
                            item['command']!,
                            style: CompassTypography.monoMedium(color: const Color(0xFFF1F5F9), size: 12.0),
                          ),
                        ],
                      ),
                    Text(
                      item['output']!,
                      style: CompassTypography.terminal(),
                    ),
                    const SizedBox(height: 6.0),
                  ],
                ],
              ),
            ),
          ),

          // Input Line
          CompositedTransformTarget(
            link: _menuAnchor,
            child: Container(
              height: 38.0,
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              decoration: const BoxDecoration(
                color: Color(0xFF080B0E),
                border: Border(
                  top: BorderSide(color: Color(0xFF21313C), width: 1.0),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '${widget.activeDbName}> ',
                    style: CompassTypography.monoBold(color: CompassColors.greenAccent, size: 12.0),
                  ),
                  Expanded(
                    child: EditableText(
                      controller: _inputController,
                      focusNode: _inputFocus,
                      style: CompassTypography.monoRegular(color: const Color(0xFFF1F5F9), size: 12.0),
                      cursorColor: CompassColors.greenAccent,
                      backgroundCursorColor: const Color(0xFF080B0E),
                      selectionColor: CompassColors.greenBadgeBg,
                      onSubmitted: (_) => _submitInput(),
                      onTapOutside: (event) =>
                          compassHandleTapOutside(event, _inputFocus),
                      contextMenuBuilder: compassTextContextMenuBuilderFor(
                        _menuAnchor,
                        density: density,
                      ),
                    ),
                  ),
                  CompassIconButton(
                    svgString: CompassSvgIcons.play,
                    onTap: _submitInput,
                    size: 12.0,
                    padding: 4.0,
                    color: CompassColors.greenAccent,
                    hoverBackground: const Color(0x14FFFFFF),
                    semanticLabel: 'Run command',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
