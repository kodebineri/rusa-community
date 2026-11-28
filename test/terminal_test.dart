import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rusa/services/local_mongo_engine.dart';
import 'package:rusa/services/mongo_engine.dart';
import 'package:rusa/widgets/compass_selectable_text.dart';
import 'package:rusa/widgets/compass_terminal.dart';
import 'package:rusa/widgets/compass_text_menu.dart';
import 'package:rusa/widgets/modals/mongosh_confirmation_modal.dart';

/// Pumps the docked shell on its own (no app shell, no connection popup).
///
/// The `Overlay` is required: `EditableText` builds its selection overlay from
/// the nearest one (the real app provides it at the root).
Widget shellHarness({
  String dbName = 'library',
  void Function(RiskyOperationDetails operation, VoidCallback onConfirm)?
      onRequestConfirmation,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Overlay(
      initialEntries: [
        OverlayEntry(
          builder: (context) => MediaQuery(
            data: const MediaQueryData(size: Size(900.0, 400.0)),
            child: CompassTerminal(
              isOpen: true,
              onClose: () {},
              activeDbName: dbName,
              onRequestConfirmation: onRequestConfirmation,
            ),
          ),
        ),
      ],
    ),
  );
}

/// The writable prompt, not the read-only selectable log rows.
Finder shellInput() => find.byWidgetPredicate(
      (widget) => widget is EditableText && !widget.readOnly,
    );

/// Opens a text field's context menu through Flutter's gesture arena.
Future<void> rightClickOn(WidgetTester tester, Finder finder) async {
  final gesture = await tester.startGesture(
    tester.getCenter(finder),
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryButton,
  );
  await gesture.up();
  await tester.pump();
}

void main() {
  setUp(() {
    mongoEngine = LocalMongoEngine.instance;
    mongoEngine.resetToDefaults();
  });

  tearDown(() {
    mongoEngine.resetToDefaults();
  });

  String inputText(WidgetTester tester) =>
      tester.widget<EditableText>(shellInput()).controller.text;

  testWidgets('Enter runs the command and logs its output', (tester) async {
    await tester.pumpWidget(shellHarness());
    await tester.enterText(shellInput(), 'show dbs');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(find.textContaining('social_networks'), findsOneWidget);
    expect(inputText(tester), isEmpty);
  });

  testWidgets('shell log text is selectable and opens the context menu',
      (tester) async {
    await tester.pumpWidget(shellHarness());
    await tester.enterText(shellInput(), 'show dbs');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    final command = find.ancestor(
      of: find.textContaining('show dbs'),
      matching: find.byType(CompassSelectableText),
    );
    final output = find.ancestor(
      of: find.textContaining('social_networks'),
      matching: find.byType(CompassSelectableText),
    );
    expect(command, findsOneWidget, reason: 'the command line must be selectable');
    expect(output, findsOneWidget, reason: 'the command output must be selectable');

    for (final row in <Finder>[command, output]) {
      final editable =
          find.descendant(of: row, matching: find.byType(EditableText));
      expect(editable, findsOneWidget);
      final field = tester.widget<EditableText>(editable);
      expect(field.readOnly, isTrue);
      expect(field.selectionColor!.a, greaterThanOrEqualTo(0.3),
          reason: 'selected shell text must be visibly highlighted');
    }

    await rightClickOn(
      tester,
      find.descendant(of: output, matching: find.byType(EditableText)),
    );
    expect(find.byType(CompassTextContextMenu), findsOneWidget);
  });

  testWidgets('arrow up recalls the previous command', (tester) async {
    await tester.pumpWidget(shellHarness());
    await tester.enterText(shellInput(), 'show dbs');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(inputText(tester), 'show dbs');

    // Down returns to the (empty) draft.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(inputText(tester), isEmpty);
  });

  testWidgets('Tab completes a database name', (tester) async {
    await tester.pumpWidget(shellHarness());
    await tester.enterText(shellInput(), 'use lib');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(inputText(tester), 'use library ');
  });

  testWidgets('Enter continues on a new line while brackets are open',
      (tester) async {
    await tester.pumpWidget(shellHarness());
    await tester.enterText(shellInput(), 'db.books.find({');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(inputText(tester), 'db.books.find({\n');
    // Nothing was executed.
    expect(find.textContaining('[0 docs]'), findsNothing);
  });

  testWidgets('Ctrl+L clears the log', (tester) async {
    await tester.pumpWidget(shellHarness());
    expect(find.textContaining('Connecting to:'), findsOneWidget);

    // The prompt only receives keys while it has focus.
    await tester.tap(shellInput());
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(find.textContaining('Connecting to:'), findsNothing);
  });

  testWidgets('find renders ObjectId(...) and a doc count', (tester) async {
    await tester.pumpWidget(shellHarness());
    await tester.enterText(shellInput(), 'db.books.find({})');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(find.textContaining('ObjectId("'), findsOneWidget);
    expect(find.textContaining('docs]'), findsOneWidget);
  });

  testWidgets('a risky command asks for confirmation before running',
      (tester) async {
    RiskyOperationDetails? requested;
    await tester.pumpWidget(shellHarness(
      onRequestConfirmation: (operation, onConfirm) {
        requested = operation;
      },
    ));

    await tester.enterText(
        shellInput(), 'db.books.deleteMany({})');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(requested, isNotNull);
    expect(requested!.type, 'deleteMany');
    // Nothing ran yet: the documents are still there.
    expect(
      mongoEngine.getCollection('library', 'books')!.documents,
      isNotEmpty,
    );
  });

  testWidgets('replaceOne is gated as a risky operation', (tester) async {
    RiskyOperationDetails? requested;
    await tester.pumpWidget(shellHarness(
      onRequestConfirmation: (operation, onConfirm) {
        requested = operation;
      },
    ));

    await tester.enterText(
        shellInput(), 'db.books.replaceOne({}, { title: "x" })');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(requested, isNotNull);
    expect(requested!.type, 'replaceOne');
  });
}
