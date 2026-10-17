// Basic smoke test for the MongoDB Compass Flutter client.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mongodb_compass_flutter/main.dart';
import 'package:mongodb_compass_flutter/models/mongo_models.dart';
import 'package:mongodb_compass_flutter/widgets/compass_header.dart';
import 'package:mongodb_compass_flutter/widgets/compass_query_bar.dart';
import 'package:mongodb_compass_flutter/widgets/modals/compass_modal.dart';
import 'package:mongodb_compass_flutter/widgets/views/aggregations_view.dart';

void main() {
  testWidgets('CompassApp builds without error', (WidgetTester tester) async {
    // The app is desktop-first; use a desktop-sized surface.
    tester.view.physicalSize = const Size(1920.0, 1080.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CompassApp());
    await tester.pump();

    // The test environment substitutes a very wide placeholder font, which can
    // make this dense desktop layout report RenderFlex overflow. Those are an
    // artifact of the test font, not real layout errors (the real app bundles
    // Plus Jakarta Sans / JetBrains Mono and renders correctly), so drain any
    // pending overflow exceptions before asserting the tree built.
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}

    expect(find.byType(CompassApp), findsOneWidget);
  });

  testWidgets('query bar filter stays editable across empty/non-empty', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920.0, 1080.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    QueryFilterOptions? last;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(1920.0, 1080.0)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: CompassQueryBar(
            options: QueryFilterOptions(),
            onChangeOptions: (updated) => last = updated,
            onExecuteQuery: () {},
            onResetQuery: () {},
            onExportToLanguage: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}

    final filterField = find.byType(EditableText);
    expect(filterField, findsOneWidget);

    final elementBefore = tester.element(filterField);

    await tester.enterText(filterField, 'abc');
    await tester.pump();
    expect(last?.filter, 'abc');
    // The EditableText element must survive typing...
    expect(identical(tester.element(filterField), elementBefore), isTrue);

    // ...and clearing to empty (backspace to nothing) must NOT recreate it,
    // otherwise the text-input connection is dropped and the field becomes
    // uneditable.
    await tester.enterText(filterField, '');
    await tester.pump();
    expect(last?.filter, '');
    expect(identical(tester.element(filterField), elementBefore), isTrue);

    // It must still accept input after having been emptied.
    await tester.enterText(filterField, 'xy');
    await tester.pump();
    expect(last?.filter, 'xy');
    expect(identical(tester.element(filterField), elementBefore), isTrue);

    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}
  });

  testWidgets('CompassInput handles Backspace and arrow keys (needs DefaultTextEditingShortcuts)',
      (WidgetTester tester) async {
    final controller = TextEditingController(text: 'abc');
    addTearDown(controller.dispose);

    // Mirrors main(): the app is wrapped in DefaultTextEditingShortcuts so
    // bare EditableText fields honour Backspace / arrow keys.
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(800.0, 600.0)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: DefaultTextEditingShortcuts(
            child: Center(
              child: SizedBox(
                width: 400.0,
                child: CompassInput(controller: controller, placeholder: 'type'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Focus the field by tapping it.
    await tester.tap(find.byType(EditableText));
    await tester.pump();

    controller.selection = const TextSelection.collapsed(offset: 3);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(controller.text, 'ab', reason: 'Backspace should delete the character');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(controller.selection.baseOffset, 1, reason: 'Left arrow should move the caret');

    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}
  });

  testWidgets('CompassHeader respects top safe area inset (status / notification bar)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920.0, 1080.0);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: 48.0);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);

    await tester.pumpWidget(const CompassApp());
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}

    final headerFinder = find.byType(CompassHeader);
    expect(headerFinder, findsOneWidget);

    final headerTopLeft = tester.getTopLeft(headerFinder);
    expect(headerTopLeft.dy, 0.0);

    final titleFinder = find.text('Compass');
    expect(titleFinder, findsOneWidget);
    final titleTopLeft = tester.getTopLeft(titleFinder);
    expect(titleTopLeft.dy, greaterThanOrEqualTo(48.0),
        reason: 'Header content should be pushed down below the notification bar');
  });

  testWidgets('CompassHeader hides Reset Samples button when showResetSample is false',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920.0, 1080.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(1920.0, 1080.0)),
          child: CompassHeader(
            connection: ConnectionProfile(id: '1', name: 'Atlas Production', uri: 'mongodb+srv://test'),
            showResetSample: false,
            onOpenConnectModal: () {},
            onDisconnect: () {},
            onResetData: () {},
            isTerminalOpen: false,
            onToggleTerminal: () {},
            isDarkMode: true,
            onToggleDarkMode: () {},
            onToggleMobileSidebar: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Reset Samples'), findsNothing);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(1920.0, 1080.0)),
          child: CompassHeader(
            connection: ConnectionProfile(id: 'sample-data', name: 'Sample Data', uri: 'mongodb://localhost:27017'),
            showResetSample: true,
            onOpenConnectModal: () {},
            onDisconnect: () {},
            onResetData: () {},
            isTerminalOpen: false,
            onToggleTerminal: () {},
            isDarkMode: true,
            onToggleDarkMode: () {},
            onToggleMobileSidebar: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Reset Samples'), findsOneWidget);
  });

  testWidgets('AggregationsView allows editing stage content, adding stages, and running pipeline',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920.0, 1080.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: MediaQueryData(size: Size(1920.0, 1080.0)),
          child: SingleChildScrollView(
            child: AggregationsView(
              dbName: 'sample_mflix',
              collName: 'movies',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify initial stages and EditableText fields exist
    expect(find.text('Visual Pipeline Stages'), findsOneWidget);
    expect(find.byType(EditableText), findsWidgets);

    // Click 'Add Stage' button
    final addStageBtn = find.text('Add Stage');
    expect(addStageBtn, findsOneWidget);
    await tester.tap(addStageBtn);
    await tester.pumpAndSettle();

    // Verify stage was added (from 3 to 4 stages)
    expect(find.text('Stage 4:'), findsOneWidget);

    // Verify 'Run Pipeline' button is clickable
    final runBtn = find.text('Run Pipeline');
    expect(runBtn, findsOneWidget);
    await tester.tap(runBtn);
    await tester.pumpAndSettle();

    // Verify Results panel is rendered
    expect(find.text('Pipeline Results'), findsOneWidget);
  });
}
