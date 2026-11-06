import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../theme/compass_colors.dart';
import '../theme/compass_density.dart';
import '../theme/compass_typography.dart';
import '../icons/compass_svg_icons.dart';
import '../services/mongosh_completer.dart';
import '../services/mongosh_interpreter.dart';
import 'compass_icon_button.dart';
import 'compass_text_menu.dart';
import 'modals/mongosh_confirmation_modal.dart';

/// One line of the terminal log: the prompt + command that was typed, and the
/// output it produced.
class _TerminalEntry {
  const _TerminalEntry({
    required this.prompt,
    required this.command,
    required this.output,
    this.isError = false,
  });

  final String prompt;
  final String command;
  final String output;
  final bool isError;
}

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

  /// Called after a command has run, so the shell can apply its UI side effects
  /// (switch database, close tabs) and refresh the tree. The command itself has
  /// already been executed by [MongoshInterpreter] — do not run it again.
  final void Function(MongoshResult result)? onCommandExecuted;
  final void Function(RiskyOperationDetails operation, VoidCallback onConfirm)?
      onRequestConfirmation;

  const CompassTerminal({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.activeDbName,
    this.onCommandExecuted,
    this.onRequestConfirmation,
  });

  @override
  State<CompassTerminal> createState() => _CompassTerminalState();
}

class _CompassTerminalState extends State<CompassTerminal> {
  bool _isExpanded = false;
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocus = FocusNode(debugLabel: 'shell-input');

  /// Anchors the text context menu to the prompt row.
  late final LayerLink _menuAnchor = LayerLink();

  /// The shell's command table + executor (pure Dart, unit-tested separately).
  final MongoshInterpreter _interpreter = MongoshInterpreter();

  /// Tab completion (pure Dart, unit-tested separately).
  final MongoshCompleter _completer = MongoshCompleter();

  /// Commands typed this session, for ↑/↓ recall.
  final List<String> _commandHistory = [];

  /// Index into [_commandHistory]; `-1` means "editing the draft".
  int _historyCursor = -1;

  /// The line being edited before the user started browsing history.
  String _draft = '';

  final List<_TerminalEntry> _history = [
    const _TerminalEntry(
      prompt: 'Shell',
      command: '',
      output:
          'Connecting to: mongodb://127.0.0.1:27017/?directConnection=true\nUsing Shell: 1.0.0\nType "help" for a list of available commands.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // The prompt owns Enter / ↑ / ↓ / Tab / Ctrl+L / Ctrl+C / Esc. Handling
    // them on the focus node runs before the text field's own shortcuts, so
    // Enter can submit instead of inserting a newline.
    _inputFocus.onKeyEvent = _handleKeyEvent;
  }

  @override
  void dispose() {
    _inputFocus.onKeyEvent = null;
    _inputController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _submitInput() {
    final command = _inputController.text.trim();
    if (command.isEmpty) return;
    _inputController.clear();
    _historyCursor = -1;
    _draft = '';
    if (_commandHistory.isEmpty || _commandHistory.last != command) {
      _commandHistory.add(command);
    }
    final risky = _detectRisky(command);
    if (risky != null && widget.onRequestConfirmation != null) {
      widget.onRequestConfirmation!(risky, () => _runCommand(command));
    } else {
      _runCommand(command);
    }
  }

  // --- Prompt keyboard handling ---------------------------------------------

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final keyboard = HardwareKeyboard.instance;
    final control = keyboard.isControlPressed;
    final shift = keyboard.isShiftPressed;

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (shift) return KeyEventResult.ignored; // Shift+Enter = newline
      if (hasUnbalancedBrackets(_inputController.text)) {
        _insertNewline();
      } else {
        _submitInput();
      }
      return KeyEventResult.handled;
    }

    // ↑/↓ recall history on a single line; on a multi-line command they move
    // the caret, except at the very start/end.
    final text = _inputController.text;
    final selection = _inputController.selection;
    final atStart = !selection.isValid || selection.baseOffset <= 0;
    final atEnd = !selection.isValid || selection.baseOffset >= text.length;
    final singleLine = !text.contains('\n');
    if (key == LogicalKeyboardKey.arrowUp && !shift && (singleLine || atStart)) {
      _recallHistory(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown && !shift && (singleLine || atEnd)) {
      _recallHistory(1);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.tab) {
      _complete();
      return KeyEventResult.handled;
    }
    if (control && key == LogicalKeyboardKey.keyL) {
      _clearLog();
      return KeyEventResult.handled;
    }
    if (control && key == LogicalKeyboardKey.keyC) {
      // With a selection, Ctrl+C is a copy — let the text field handle it.
      final inputSelection = _inputController.selection;
      if (inputSelection.isValid && !inputSelection.isCollapsed) {
        return KeyEventResult.ignored;
      }
      _clearInput();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      _clearInput();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _insertNewline() {
    final value = _inputController.value;
    final text = value.text;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final updated = text.replaceRange(start, end, '\n');
    _inputController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: start + 1),
    );
  }

  void _recallHistory(int delta) {
    if (_commandHistory.isEmpty) return;
    if (_historyCursor == -1) {
      _draft = _inputController.text;
      _historyCursor = _commandHistory.length;
    }
    final next = _historyCursor + delta;
    if (next < 0) return;
    if (next >= _commandHistory.length) {
      _historyCursor = -1;
      _setInput(_draft);
      return;
    }
    _historyCursor = next;
    _setInput(_commandHistory[next]);
  }

  void _complete() {
    final completion = _completer.complete(
      _inputController.text,
      dbName: widget.activeDbName,
    );
    if (completion == null) return;

    final text = _inputController.text;
    final base = text.substring(0, text.length - completion.token.length);
    final single = completion.single;
    if (single != null) {
      _setInput('$base$single${completion.appendSpace ? ' ' : ''}');
      return;
    }
    // Ambiguous: extend to the common prefix, and list the candidates when
    // that does not narrow anything down (bash-style).
    final prefix = completion.commonPrefix;
    if (prefix.length > completion.token.length) {
      _setInput('$base$prefix');
      return;
    }
    setState(() {
      _history.add(_TerminalEntry(
        prompt: widget.activeDbName.isEmpty ? 'test' : widget.activeDbName,
        command: '',
        output: completion.candidates.join('  '),
      ));
    });
  }

  void _setInput(String text) {
    _inputController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _clearInput() {
    _inputController.clear();
    _historyCursor = -1;
    _draft = '';
  }

  void _clearLog() {
    setState(() => _history.clear());
  }

  void _runCommand(String command) {
    // The interpreter is the single executor: it runs the command once and
    // reports any UI side effect. `main.dart` only applies that side effect.
    final result = _interpreter.execute(command, dbName: widget.activeDbName);
    widget.onCommandExecuted?.call(result);
    if (!mounted) return;
    setState(() {
      _history.add(_TerminalEntry(
        prompt: widget.activeDbName.isEmpty ? 'test' : widget.activeDbName,
        command: command,
        output: result.output,
        isError: result.isError,
      ));
    });
  }

  /// Detects destructive/risky commands so the UI can require confirmation.
  ///
  /// Whether a command is risky is decided by the interpreter's command table
  /// (`MongoshCommand.risky`); this method only builds the confirmation copy.
  RiskyOperationDetails? _detectRisky(String command) {
    final cmd = command.trim();
    if (!_interpreter.isRisky(cmd)) return null;

    if (RegExp(r'db\.dropDatabase\s*\(\s*\)').hasMatch(cmd)) {
      return RiskyOperationDetails(
        type: 'dropDatabase',
        title: 'Drop Database',
        command: cmd,
        dbName: widget.activeDbName,
        description: 'This will permanently drop the entire database.',
        impact:
            'All collections, documents and indexes in "${widget.activeDbName}" will be destroyed.',
      );
    }

    final collMatch =
        RegExp(r'db\.([A-Za-z0-9_]+)\.(\w+)\s*\(').firstMatch(cmd);
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
        impact:
            'All documents and indexes in "${widget.activeDbName}.$collName" will be removed.',
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
        impact:
            'Documents in "${widget.activeDbName}.$collName" matching the filter will be permanently removed.',
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
        impact:
            'The first matching document in "${widget.activeDbName}.$collName" will be permanently removed.',
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
        impact:
            'Documents in "${widget.activeDbName}.$collName" matching the filter will be modified.',
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
        impact:
            'The first matching document in "${widget.activeDbName}.$collName" will be modified.',
      );
    }
    if (method == 'replaceOne') {
      return RiskyOperationDetails(
        type: 'replaceOne',
        title: 'Replace Document',
        command: cmd,
        dbName: widget.activeDbName,
        collName: collName,
        description: 'This will replace a single matching document.',
        impact:
            'The first matching document in "${widget.activeDbName}.$collName" will be replaced; fields not in the replacement are removed.',
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
                      'Shell',
                      style: CompassTypography.monoBold(
                          color: const Color(0xFFF1F5F9), size: 12.0),
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      'mongodb://127.0.0.1:27017 (${widget.activeDbName})',
                      style: CompassTypography.monoSmall(
                          color: CompassColors.darkTextMuted),
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
                      svgString: _isExpanded
                          ? CompassSvgIcons.chevronDown
                          : CompassSvgIcons.chevronUp,
                      onTap: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                      size: 13.0,
                      padding: 4.0,
                      color: CompassColors.darkTextMuted,
                      hoverBackground: const Color(0x14FFFFFF),
                      semanticLabel:
                          _isExpanded ? 'Collapse terminal' : 'Expand terminal',
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
                    if (item.command.isNotEmpty)
                      Row(
                        children: [
                          Text(
                            '${item.prompt}> ',
                            style: CompassTypography.monoBold(
                                color: CompassColors.greenAccent, size: 12.0),
                          ),
                          Text(
                            item.command,
                            style: CompassTypography.monoMedium(
                                color: const Color(0xFFF1F5F9), size: 12.0),
                          ),
                        ],
                      ),
                    Text(
                      item.output,
                      style: item.isError
                          ? CompassTypography.terminal(
                              color: CompassColors.errorRed)
                          : CompassTypography.terminal(),
                    ),
                    const SizedBox(height: 6.0),
                  ],
                ],
              ),
            ),
          ),

          // Input Line (grows with multi-line commands, capped at ~5 lines)
          CompositedTransformTarget(
            link: _menuAnchor,
            child: Container(
              constraints: const BoxConstraints(
                minHeight: 38.0,
                maxHeight: 120.0,
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              decoration: const BoxDecoration(
                color: Color(0xFF080B0E),
                border: Border(
                  top: BorderSide(color: Color(0xFF21313C), width: 1.0),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      '${widget.activeDbName}> ',
                      style: CompassTypography.monoBold(
                          color: CompassColors.greenAccent, size: 12.0),
                    ),
                  ),
                  Expanded(
                    child: EditableText(
                      controller: _inputController,
                      focusNode: _inputFocus,
                      // Multi-line: Enter inserts a newline while brackets are
                      // open (see `_handleKeyEvent`).
                      maxLines: null,
                      minLines: 1,
                      style: CompassTypography.monoRegular(
                          color: const Color(0xFFF1F5F9), size: 12.0),
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
