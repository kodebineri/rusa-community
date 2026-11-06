import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rusa/services/local_mongo_engine.dart';
import 'package:rusa/services/mongo_engine.dart';
import 'package:rusa/widgets/compass_terminal.dart';
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

void main() {
  setUp(() {
    mongoEngine = LocalMongoEngine.instance;
    mongoEngine.resetToDefaults();
  });

  tearDown(() {
    mongoEngine.resetToDefaults();
  });

  String inputText(WidgetTester tester) =>
      tester.widget<EditableText>(find.byType(EditableText)).controller.text;

  testWidgets('Enter runs the command and logs its output', (tester) async {
    await tester.pumpWidget(shellHarness());
    await tester.enterText(find.byType(EditableText), 'show dbs');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(find.textContaining('social_networks'), findsOneWidget);
    expect(inputText(tester), isEmpty);
  });

  testWidgets('arrow up recalls the previous command', (tester) async {
    await tester.pumpWidget(shellHarness());
    await tester.enterText(find.byType(EditableText), 'show dbs');
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
    await tester.enterText(find.byType(EditableText), 'use lib');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(inputText(tester), 'use library ');
  });

  testWidgets('Enter continues on a new line while brackets are open',
      (tester) async {
    await tester.pumpWidget(shellHarness());
    await tester.enterText(find.byType(EditableText), 'db.books.find({');
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
    await tester.tap(find.byType(EditableText));
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(find.textContaining('Connecting to:'), findsNothing);
  });

  testWidgets('find renders ObjectId(...) and a doc count', (tester) async {
    await tester.pumpWidget(shellHarness());
    await tester.enterText(find.byType(EditableText), 'db.books.find({})');
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
        find.byType(EditableText), 'db.books.deleteMany({})');
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
        find.byType(EditableText), 'db.books.replaceOne({}, { title: "x" })');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(requested, isNotNull);
    expect(requested!.type, 'replaceOne');
  });
}
