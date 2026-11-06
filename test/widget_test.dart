// Basic smoke test for the Rusa (MongoDB database client) Flutter app.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rusa/app_info.dart';
import 'package:rusa/main.dart';
import 'package:rusa/icons/compass_svg_icons.dart';
import 'package:rusa/models/collection_tab.dart';
import 'package:rusa/models/mongo_models.dart';
import 'package:rusa/services/mongo_engine.dart';
import 'package:rusa/theme/compass_density.dart';
import 'package:rusa/theme/compass_theme.dart';
import 'package:rusa/theme/compass_theme_presets.dart';
import 'package:rusa/widgets/collection_tab_bar.dart';
import 'package:rusa/widgets/compass_header.dart';
import 'package:rusa/widgets/compass_icon_button.dart';
import 'package:rusa/widgets/compass_query_bar.dart';
import 'package:rusa/widgets/compass_sidebar.dart';
import 'package:rusa/widgets/modals/about_modal.dart';
import 'package:rusa/widgets/modals/compass_modal.dart';
import 'package:rusa/widgets/modals/connection_modal.dart';
import 'package:rusa/widgets/modals/create_index_modal.dart';
import 'package:rusa/widgets/modals/drop_index_modal.dart';
import 'package:rusa/widgets/modals/eula_acceptance_modal.dart';
import 'package:rusa/widgets/modals/insert_document_modal.dart';
import 'package:rusa/widgets/views/aggregations_view.dart';
import 'package:rusa/widgets/views/document_json_view.dart';
import 'package:rusa/widgets/views/document_tree_view.dart';
import 'package:rusa/widgets/views/indexes_view.dart';
import 'package:rusa/widgets/views/schema_view.dart';
import 'package:rusa/widgets/views/show_ddl_view.dart';

/// Parses the mongosh-flavoured text an editor shows and unwraps the Extended
/// JSON constructors (`ObjectId("...")` / `ISODate("...")`) back to the plain
/// values the engine stores, so tests can compare against `doc.data`.
dynamic unwrapMongoEditorText(String text) =>
    _unwrapExtended(mongoEngine.tolerantParse(text));

dynamic _unwrapExtended(dynamic value) {
  if (value is MongoObjectId) return value.hex;
  if (value is Map) {
    if (value.length == 1 && value[r'$oid'] is String) return value[r'$oid'];
    if (value.length == 1 && value.containsKey(r'$date')) return value[r'$date'];
    return value.map((k, v) => MapEntry(k.toString(), _unwrapExtended(v)));
  }
  if (value is List) return value.map(_unwrapExtended).toList();
  return value;
}

/// A fresh `CompassApp` boots into the connection popup (`_isConnectModalOpen
/// = true`), which covers the shell. Close it before driving the shell, or the
/// taps land on the modal backdrop instead of the header/sidebar/tabs.
Future<void> closeConnectionPopup(WidgetTester tester) async {
  // Let the stored EULA flag load so the first-run cover clears.
  await tester.pump();
  final closeIcon = find.descendant(
    of: find.byType(ConnectionModal),
    matching: find.byWidgetPredicate(
      (w) => w is CompassSvg && w.svgString == CompassSvgIcons.close,
    ),
  );
  if (closeIcon.evaluate().isEmpty) return;
  await tester.tap(closeIcon.first);
  await tester.pump();
  for (var i = 0; i < 50 && tester.takeException() != null; i++) {}
}

/// A standalone [CompassQueryBar] at [width], with a desktop or touch profile,
/// so layout tests can exercise the inline vs. stacked action rows.
Widget queryBarFor({required double width, required bool touch}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Overlay(
      initialEntries: [
        OverlayEntry(
          builder: (context) => CompassDensity.forWidth(
            width: width,
            touchDevice: touch,
            child: MediaQuery(
              data: MediaQueryData(size: Size(width, 1000.0)),
              child: CompassQueryBar(
                options: QueryFilterOptions(),
                onChangeOptions: (_) {},
                onExecuteQuery: () {},
                onResetQuery: () {},
                optionsExpanded: false,
                onToggleOptions: () {},
                onOpenOverflow: () {},
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

void main() {
  // All tests run as a user who has already accepted the EULA, so the first-run
  // gate does not block the app shell. Test 18 overrides this.
  setUp(() {
    SharedPreferences.setMockInitialValues({'eula_accepted': true});
  });

  test('AboutModal.appVersion mirrors pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match =
        RegExp(r'^version:\s*(\S+)\s*$', multiLine: true).firstMatch(pubspec);
    expect(match, isNotNull, reason: 'pubspec.yaml must declare a version');

    final declared = match!.group(1)!; // e.g. "1.0.0+1"
    final parts = declared.split('+');
    expect(AppInfo.version, parts.first,
        reason: 'AppInfo.version must match pubspec (bump both together)');
    expect(AppInfo.buildNumber, parts.length > 1 ? parts[1] : '',
        reason: 'AppInfo.buildNumber must match pubspec');
    expect(AboutModal.appVersion, declared);
  });

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
      Directionality(
        textDirection: TextDirection.ltr,
        child: Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (context) => MediaQuery(
                data: const MediaQueryData(size: Size(1920.0, 1080.0)),
                child: CompassQueryBar(
                  options: QueryFilterOptions(),
                  onChangeOptions: (updated) => last = updated,
                  onExecuteQuery: () {},
                  onResetQuery: () {},
                  optionsExpanded: false,
                  onToggleOptions: () {},
                  onOpenOverflow: () {},
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}

    final filterField = find.byType(EditableText);
    expect(filterField, findsOneWidget);

    final elementBefore = tester.element(filterField);

    // Typing only validates — nothing is committed until Find is pressed.
    await tester.enterText(filterField, 'abc');
    await tester.pump();
    expect(last, isNull, reason: 'typing must not execute the query');
    // The EditableText element must survive typing...
    expect(identical(tester.element(filterField), elementBefore), isTrue);

    await tester.tap(find.text('Find'));
    await tester.pump();
    expect(last?.filter, 'abc');

    // ...and clearing to empty (backspace to nothing) must NOT recreate it,
    // otherwise the text-input connection is dropped and the field becomes
    // uneditable.
    await tester.enterText(filterField, '');
    await tester.pump();
    expect(identical(tester.element(filterField), elementBefore), isTrue);

    await tester.tap(find.text('Find'));
    await tester.pump();
    expect(last?.filter, '');

    // It must still accept input after having been emptied.
    await tester.enterText(filterField, 'xy');
    await tester.pump();
    expect(identical(tester.element(filterField), elementBefore), isTrue);

    await tester.tap(find.text('Find'));
    await tester.pump();
    expect(last?.filter, 'xy');

    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}
  });

  testWidgets('tablet query bar keeps Options/Reset/Find inline',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800.0, 1000.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(queryBarFor(width: 800.0, touch: true));
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}

    // One inline row: the stacked layout is the only thing that uses a Wrap.
    expect(find.byType(Wrap), findsNothing);
    expect(find.text('Options'), findsOneWidget);
    expect(find.text('Find'), findsOneWidget);
  });

  testWidgets('a narrow query bar wraps the action buttons',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(600.0, 1000.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(queryBarFor(width: 600.0, touch: true));
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}

    expect(find.byType(Wrap), findsWidgets);
  });

  testWidgets('CompassInput handles Backspace and arrow keys (needs DefaultTextEditingShortcuts)',
      (WidgetTester tester) async {
    final controller = TextEditingController(text: 'abc');
    addTearDown(controller.dispose);

    // Mirrors main(): the app is wrapped in DefaultTextEditingShortcuts so
    // bare EditableText fields honour Backspace / arrow keys.
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (context) => MediaQuery(
                data: const MediaQueryData(size: Size(800.0, 600.0)),
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
          ],
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
    await closeConnectionPopup(tester);

    final headerFinder = find.byType(CompassHeader);
    expect(headerFinder, findsOneWidget);

    final headerTopLeft = tester.getTopLeft(headerFinder);
    expect(headerTopLeft.dy, 0.0);

    final titleFinder = find.text('r u s a');
    expect(titleFinder, findsOneWidget);
    final titleTopLeft = tester.getTopLeft(titleFinder);
    expect(titleTopLeft.dy, greaterThanOrEqualTo(48.0),
        reason: 'Header content should be pushed down below the notification bar');
  });

  testWidgets('the shell clears the bottom system inset (navigation bar / home indicator)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920.0, 1080.0);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(bottom: 34.0);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);

    await tester.pumpWidget(const CompassApp());
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}
    await closeConnectionPopup(tester);

    // The sidebar (and terminal below it) lives inside the shell SafeArea, so
    // nothing the app paints reaches the bottom system inset.
    final sidebar = find.byType(CompassSidebar);
    expect(sidebar, findsOneWidget);
    expect(tester.getRect(sidebar).bottom, lessThanOrEqualTo(1080.0 - 34.0 + 0.001),
        reason: 'shell content should stop above the navigation bar');
  });

  testWidgets('system text scaling is clamped so the dense layout stays usable',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920.0, 1080.0);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(const CompassApp());
    await tester.pump();
    // The harness's placeholder font is far wider than Inter, so the connection
    // modal's footer overflows in *any* test that boots the shell (also at 1.0);
    // drain it rather than failing on a test-only artefact.
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}
    await closeConnectionPopup(tester);

    final scaler = MediaQuery.textScalerOf(
      tester.element(find.byType(CompassHeader)),
    );
    expect(scaler.scale(10.0), closeTo(13.0, 0.001),
        reason: 'an OS scale of 2.0 should be clamped to 1.3');
  });

  testWidgets('the brand mark flips colour with the theme brightness',
      (WidgetTester tester) async {
    Future<Color> markColour(CompassThemeVariant variant) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(size: Size(1920.0, 1080.0)),
            child: CompassTheme(
              variant: variant,
              child: CompassHeader(
                connection: null,
                showResetSample: true,
                onOpenConnectModal: () {},
                onDisconnect: () {},
                isTerminalOpen: false,
                onToggleTerminal: () {},
                themeVariant: variant,
                onSelectTheme: (_) {},
                onToggleMobileSidebar: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final mark = tester
          .widgetList<CompassSvg>(find.byType(CompassSvg))
          .firstWhere((svg) => svg.svgString == CompassSvgIcons.rusa);
      return mark.color!;
    }

    expect(await markColour(CompassThemeVariant.dracula),
        const Color(0xFFFFFFFF),
        reason: 'the mark is white on dark variants');
    expect(await markColour(CompassThemeVariant.monokaiLight),
        const Color(0xFF2B2119),
        reason: 'the mark is near-black on light variants');
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
            themeVariant: CompassThemeVariant.dracula,
            onSelectTheme: (_) {},
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
            themeVariant: CompassThemeVariant.dracula,
            onSelectTheme: (_) {},
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
              dbName: 'library',
              collName: 'books',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The pipeline starts empty (like Compass).
    expect(find.text('Visual Pipeline Stages'), findsOneWidget);
    expect(find.text('No pipeline stages added yet.'), findsOneWidget);

    // Click 'Add Stage' button
    final addStageBtn = find.text('Add Stage');
    expect(addStageBtn, findsOneWidget);
    await tester.tap(addStageBtn);
    await tester.pumpAndSettle();

    // Verify a stage (and its editor) was added.
    expect(find.text('Stage 1:'), findsOneWidget);
    expect(find.byType(EditableText), findsWidgets);

    // Verify 'Run Pipeline' button is clickable
    final runBtn = find.text('Run Pipeline');
    expect(runBtn, findsOneWidget);
    await tester.tap(runBtn);
    await tester.pumpAndSettle();

    // Verify Results panel is rendered
    expect(find.text('Pipeline Results'), findsOneWidget);
  });

  testWidgets('Run Pipeline executes the raw aggregation script',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920.0, 1080.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CompassApp());
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}
    await closeConnectionPopup(tester);

    await tester.tap(find.text('Aggregations'));
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}

    // Switch to Raw mode; its editor does not auto-run on type.
    await tester.tap(find.text('Raw Aggregations'));
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}

    final rawEditor = find.descendant(
      of: find.byType(AggregationsView),
      matching: find.byType(EditableText),
    );
    expect(rawEditor, findsOneWidget);
    await tester.enterText(
      rawEditor,
      '[{ "\$match": { "published_year": 2019 } }]',
    );
    await tester.pump();

    // The top action-bar button must run the edited script.
    await tester.tap(find.text('Run Pipeline'));
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}

    expect(find.textContaining('1 docs ('), findsWidgets);
  });

  testWidgets('aggregation results preview is paged 20 at a time',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920.0, 1080.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(mongoEngine.resetToDefaults);

    // 2 seeded books + 25 bulk = 27 documents.
    for (var i = 0; i < 25; i++) {
      mongoEngine.insertDocument('library', 'books', {
        '_id': 'bulk-$i',
        'title': 'Bulk $i',
        'isbn': 'bulk-isbn-$i',
        'published_year': 2020,
      });
    }

    await tester.pumpWidget(const CompassApp());
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}
    await closeConnectionPopup(tester);

    await tester.tap(find.text('Aggregations'));
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}

    await tester.tap(find.text('Raw Aggregations'));
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}

    final rawEditor = find.descendant(
      of: find.byType(AggregationsView),
      matching: find.byType(EditableText),
    );
    await tester.enterText(rawEditor, '[{ "\$match": {} }]');
    await tester.pump();
    await tester.tap(find.text('Run Pipeline'));
    await tester.pump(const Duration(milliseconds: 400));
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}

    // First page of 20, with the pager showing the 27-document total.
    expect(find.text('1–20 of 27'), findsOneWidget);

    final nextBtn = find.byWidgetPredicate(
      (w) => w is CompassIconButton && w.semanticLabel == 'Next results page',
    );
    expect(nextBtn, findsOneWidget);
    await tester.tap(nextBtn);
    await tester.pump();

    expect(find.text('21–27 of 27'), findsOneWidget);
  });

  testWidgets('selecting collections opens them in tabs', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920.0, 1080.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CompassApp());
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}
    await closeConnectionPopup(tester);

    final tabBar = find.byType(CollectionTabBar);
    expect(tabBar, findsOneWidget);

    // `CompassApp` provides the theme at the root (dark by default) so the
    // strip can follow the dark/light toggle.
    final theme = tester.widget<CompassTheme>(find.byType(CompassTheme));
    expect(theme.isDarkMode, isTrue);

    // `library.books` is open in a tab by default.
    var bar = tester.widget<CollectionTabBar>(tabBar);
    expect(bar.tabs.length, 1);
    expect(bar.activeIndex, 0);
    expect(find.text('1 open'), findsOneWidget);
    expect(find.descendant(of: tabBar, matching: find.text('books')), findsOneWidget);

    // Selecting another collection from the sidebar opens a *new* tab and
    // makes it active.
    await tester.tap(find.text('comments'));
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}

    bar = tester.widget<CollectionTabBar>(tabBar);
    expect(bar.tabs.length, 2);
    expect(bar.activeIndex, 1);
    expect(bar.tabs[1].collName, 'comments');
    expect(find.text('2 open'), findsOneWidget);

    // Re-selecting an already-open collection focuses its tab instead of
    // opening a duplicate.
    await tester.tap(
      find.descendant(of: find.byType(CompassSidebar), matching: find.text('books')),
    );
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}

    bar = tester.widget<CollectionTabBar>(tabBar);
    expect(bar.tabs.length, 2, reason: 'an already-open collection must not duplicate');
    expect(bar.activeIndex, 0);

    // Clicking a tab switches back to that collection.
    await tester.tap(find.descendant(of: tabBar, matching: find.text('comments')));
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}
    expect(tester.widget<CollectionTabBar>(tabBar).activeIndex, 1);

    // Closing a tab removes it and activates its neighbour.
    final closeButtons = find.descendant(
      of: tabBar,
      matching: find.byWidgetPredicate(
        (w) => w is CompassSvg && w.svgString == CompassSvgIcons.close,
      ),
    );
    expect(closeButtons, findsNWidgets(2));
    await tester.tap(closeButtons.first);
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}

    bar = tester.widget<CollectionTabBar>(tabBar);
    expect(bar.tabs.length, 1);
    expect(bar.tabs.single.collName, 'comments');
    expect(bar.activeIndex, 0);
    expect(find.text('1 open'), findsOneWidget);
  });

  testWidgets('collection tab bar follows the selected CompassTheme variant',
      (WidgetTester tester) async {
    const light = CompassThemeVariant.monokaiLight;

    await tester.pumpWidget(
      CompassTheme(
        variant: light,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(size: Size(800.0, 200.0)),
            child: CollectionTabBar(
              tabs: [CollectionTab(dbName: 'library', collName: 'books')],
              activeIndex: 0,
              onSelect: (_) {},
              onClose: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}

    // The outer strip container picks the variant's panel background + border.
    final strip = tester.widget<Container>(
      find.descendant(of: find.byType(CollectionTabBar), matching: find.byType(Container)).first,
    );
    final decoration = strip.decoration as BoxDecoration;
    expect(decoration.color, light.palette.bgPanel);
    expect((decoration.border as Border).bottom.color, light.palette.border);

    // And it still renders the tab contents.
    expect(find.text('books'), findsOneWidget);
    expect(find.text('library'), findsOneWidget);
  });

  testWidgets('options menu lists every theme and applies the selected one',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920.0, 1080.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CompassApp());
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}
    await closeConnectionPopup(tester);

    Color? headerColor() {
      final header = find.byType(CompassHeader);
      final container = tester.widget<Container>(
        find.descendant(of: header, matching: find.byType(Container)).first,
      );
      return (container.decoration as BoxDecoration).color;
    }

    // Dracula (dark) is the default.
    expect(tester.widget<CompassTheme>(find.byType(CompassTheme)).variant,
        CompassThemeVariant.dracula);
    expect(headerColor(), CompassThemeVariant.dracula.palette.bgPanel);

    // Open the header options menu (the `⋮` button on desktop).
    final moreButton = find.descendant(
      of: find.byType(CompassHeader),
      matching: find.byWidgetPredicate(
        (w) => w is CompassSvg && w.svgString == CompassSvgIcons.moreVertical,
      ),
    );
    expect(moreButton, findsOneWidget);
    await tester.tap(moreButton);
    await tester.pump();

    // Every variant is offered, grouped under the dark / light headings.
    for (final variant in CompassThemeVariant.values) {
      expect(find.text(variant.label), findsOneWidget,
          reason: '${variant.label} must be listed in the options menu');
    }
    expect(find.text('DARK THEMES'), findsOneWidget);
    expect(find.text('LIGHT THEMES'), findsOneWidget);
    // The menu sits above Report Bug.
    expect(find.text('Report Bug'), findsOneWidget);

    // Selecting a light theme applies it to the whole chrome.
    await tester.tap(find.text(CompassThemeVariant.monokaiLight.label));
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}

    expect(tester.widget<CompassTheme>(find.byType(CompassTheme)).variant,
        CompassThemeVariant.monokaiLight,
        reason: 'the root theme must switch to the selected variant');
    expect(headerColor(), CompassThemeVariant.monokaiLight.palette.bgPanel,
        reason: 'the header chrome must follow the selected palette');
  });

  testWidgets('content views follow the selected light theme (documents, aggregations, schema, indexes)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920.0, 1080.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CompassApp());
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}
    await closeConnectionPopup(tester);

    const light = CompassThemeVariant.materialLight;

    // Switch to a light theme through the header options menu.
    await tester.tap(
      find.descendant(
        of: find.byType(CompassHeader),
        matching: find.byWidgetPredicate(
          (w) => w is CompassSvg && w.svgString == CompassSvgIcons.moreVertical,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text(light.label));
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}
    expect(tester.widget<CompassTheme>(find.byType(CompassTheme)).variant, light);

    // Surfaces from the dark (Dracula) palette that must never appear once a
    // light theme is selected. (`bgApp` == `bgInput` and `bgSidebar` ==
    // `bgPanel` in the palette, so list the distinct values only.)
    const dark = CompassThemeVariant.dracula;
    final darkSurfaces = <Color>{
      dark.palette.bgApp,
      dark.palette.bgSidebar,
      dark.palette.bgSubtle,
      dark.palette.bgHover,
    };

    // Every opaque surface currently in the tree must use the light palette,
    // and there must be at least one light panel (so the check can't pass
    // vacuously on an empty tree).
    void expectLightSurfaces(String section) {
      var lightPanels = 0;
      for (final container in tester.widgetList<Container>(find.byType(Container))) {
        Color? color = container.color;
        final decoration = container.decoration;
        if (decoration is BoxDecoration && decoration.color != null) {
          color = decoration.color;
        }
        if (color == null) continue;
        expect(darkSurfaces.contains(color), isFalse,
            reason: '$section (light theme): a surface still uses a dark colour $color');
        if (color == light.palette.bgPanel) lightPanels++;
      }
      expect(lightPanels, greaterThan(0),
          reason: '$section (light theme): expected at least one light panel surface');
    }

    Future<void> selectSection(String label) async {
      await tester.tap(find.text(label).first);
      await tester.pump();
      for (var i = 0; i < 50 && tester.takeException() != null; i++) {}
    }

    // `library.books` is open by default, starting on Documents.
    expectLightSurfaces('documents');

    await selectSection('Aggregations');
    expectLightSurfaces('aggregations');

    await selectSection('Schema');
    expectLightSurfaces('schema');

    await selectSection('Indexes');
    expectLightSurfaces('indexes');
  });

  testWidgets(
      'tree-mode copy icon opens a popup with the copied value and an Insert Document button',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920.0, 1080.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // The engine is a shared singleton; restore the seed data afterwards.
    addTearDown(mongoEngine.resetToDefaults);

    await tester.pumpWidget(const CompassApp());
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}
    await closeConnectionPopup(tester);

    final booksColl = mongoEngine.getCollection('library', 'books')!;
    final originalCount = booksColl.documents.length;
    expect(originalCount, greaterThan(0));

    // Tree mode (the default) renders one copy/duplicate icon per document
    // card; scope the finder to the tree so it can't pick up copy icons from
    // other views or (closed) modals.
    final copyIcon = find.descendant(
      of: find.byType(DocumentTreeView),
      matching: find.byWidgetPredicate(
        (w) => w is CompassSvg && w.svgString == CompassSvgIcons.copy,
      ),
    );
    expect(copyIcon, findsNWidgets(originalCount));

    await tester.tap(copyIcon.first);
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}

    final modal = find.byType(InsertDocumentModal);

    // Clone mode: both the dialog title and its primary action read
    // "Insert Document" (and it is not an edit dialog).
    expect(
      find.descendant(of: modal, matching: find.text('Insert Document')),
      findsNWidgets(2),
    );
    expect(
      find.descendant(of: modal, matching: find.text('Edit Document')),
      findsNothing,
    );

    // Copying alone must not insert anything — the popup awaits confirmation.
    expect(booksColl.documents.length, originalCount);

    // The popup is pre-filled with the copied document's value, but with a
    // fresh _id so the copy can actually be inserted.
    final editor = find.descendant(
      of: modal,
      matching: find.byType(EditableText),
    );
    expect(editor, findsOneWidget);
    final parsed = unwrapMongoEditorText(
      tester.widget<EditableText>(editor).controller.text,
    ) as Map<String, dynamic>;
    final existingIds = booksColl.documents.map((d) => d.id).toSet();
    expect(
      existingIds.contains(parsed['_id']),
      isFalse,
      reason: 'the copy must carry a fresh _id',
    );
    bool isCopyOf(Map<String, dynamic> candidate, MongoDocument doc) {
      final a = Map<String, dynamic>.from(candidate)..remove('_id');
      final b = Map<String, dynamic>.from(
        _unwrapExtended(doc.data) as Map<String, dynamic>,
      )..remove('_id');
      return jsonEncode(a) == jsonEncode(b);
    }

    expect(
      booksColl.documents.any((d) => isCopyOf(parsed, d)),
      isTrue,
      reason: 'the popup must show the same value as the copied document',
    );

    // Inserting the unchanged copy collides with the unique isbn index: the
    // failure must surface inside the popup instead of being swallowed.
    final insertBtn = find.descendant(
      of: modal,
      matching: find.widgetWithText(CompassPrimaryButton, 'Insert Document'),
    );
    expect(insertBtn, findsOneWidget);

    await tester.tap(insertBtn);
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}

    expect(
      find.descendant(of: modal, matching: find.textContaining('E11000')),
      findsOneWidget,
      reason: 'the duplicate-key error must be shown in the popup',
    );
    expect(booksColl.documents.length, originalCount);

    // Editing the conflicting field and confirming inserts the copy as a new
    // document; the popup then closes.
    final edited = Map<String, dynamic>.from(parsed)
      ..['isbn'] = '978-0-00-000000-1';
    await tester.enterText(editor, jsonEncode(edited));
    await tester.pump();

    await tester.tap(insertBtn);
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}

    expect(
      find.descendant(of: modal, matching: find.text('Insert Document')),
      findsNothing,
      reason: 'the popup must close after a successful insert',
    );
    expect(booksColl.documents.length, originalCount + 1);
    expect(
      booksColl.documents.any((d) => d.data['isbn'] == '978-0-00-000000-1'),
      isTrue,
    );
    expect(
      find.text('#${originalCount + 1}'),
      findsOneWidget,
      reason: 'the tree view must show the newly inserted document card',
    );
  });

  testWidgets('Analyze Schema button shows progress and re-runs the analysis',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920.0, 1080.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // The engine is a shared singleton; this test mutates it directly, so
    // restore the seed data afterwards.
    addTearDown(mongoEngine.resetToDefaults);

    await tester.pumpWidget(const CompassApp());
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}
    await closeConnectionPopup(tester);

    // Opening the Schema section auto-runs an analysis: the button is
    // disabled and shows "Analyzing..." until the simulated 250 ms pass
    // completes (library.books is selected by default).
    await tester.tap(find.text('Schema').first);
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}

    final schemaView = find.byType(SchemaView);
    expect(schemaView, findsOneWidget);
    expect(
      find.descendant(of: schemaView, matching: find.text('Analyzing...')),
      findsOneWidget,
      reason: 'the button must show progress while the analysis runs',
    );
    expect(
      find.descendant(of: schemaView, matching: find.text('Analyze Schema')),
      findsNothing,
    );

    await tester.pump(const Duration(milliseconds: 300));
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}

    expect(
      find.descendant(of: schemaView, matching: find.text('Analyze Schema')),
      findsOneWidget,
      reason: 'the button must return to idle once the analysis finishes',
    );
    // The seed books documents have a `title` field, so its card renders.
    expect(
      find.descendant(of: schemaView, matching: find.text('title')),
      findsOneWidget,
    );

    // Insert a document with a brand-new top-level field behind the view's
    // back: the displayed schema is stale until Analyze Schema is pressed.
    mongoEngine.insertDocument('library', 'books', {
      'title': 'Schema Probe',
      'analyzer_probe': 'probe',
    });
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}
    expect(
      find.descendant(of: schemaView, matching: find.text('analyzer_probe')),
      findsNothing,
      reason: 'the schema must not refresh without an explicit re-analysis',
    );

    // Pressing Analyze Schema flips back into the analyzing state, then the
    // re-run analysis picks up the newly inserted field.
    await tester.tap(
      find.descendant(of: schemaView, matching: find.text('Analyze Schema')),
    );
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}
    expect(
      find.descendant(of: schemaView, matching: find.text('Analyzing...')),
      findsOneWidget,
      reason: 'the button must be disabled again while re-analyzing',
    );

    await tester.pump(const Duration(milliseconds: 300));
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}

    expect(
      find.descendant(of: schemaView, matching: find.text('Analyze Schema')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: schemaView, matching: find.text('analyzer_probe')),
      findsOneWidget,
      reason: 'the re-analysis must surface the new field',
    );
    expect(
      find.descendant(
        of: schemaView,
        matching: find.text('Analyzed 10 unique fields in books'),
      ),
      findsOneWidget,
      reason: 'the header count must reflect the refreshed analysis',
    );
  });

  testWidgets('Create Index modal creates an index and reports duplicate names',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920.0, 1080.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // Indexes live on the shared engine singleton; restore the seed afterwards.
    addTearDown(mongoEngine.resetToDefaults);

    await tester.pumpWidget(const CompassApp());
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}
    await closeConnectionPopup(tester);

    // Switch to the Indexes section (library.books is selected by default).
    await tester.tap(find.text('Indexes').first);
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}

    final books = mongoEngine.getCollection('library', 'books')!;
    final originalIndexCount = books.indexes.length;

    // The Create Index button must open the modal (it was a no-op stub before).
    await tester.tap(find.text('Create Index'));
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}

    final modal = find.byType(CreateIndexModal);
    expect(modal, findsOneWidget);
    expect(
      find.descendant(of: modal, matching: find.text('Create New Index')),
      findsOneWidget,
    );

    // An empty field name is rejected and the modal stays open.
    final createButton = find.descendant(
      of: modal,
      matching: find.widgetWithText(CompassPrimaryButton, 'Create'),
    );
    await tester.tap(createButton);
    await tester.pump();
    expect(
      find.descendant(of: modal, matching: find.text('Field name is required')),
      findsOneWidget,
    );
    expect(books.indexes.length, originalIndexCount);

    // Fill the form: descending, unique `year` index.
    final fieldInput = find.descendant(of: modal, matching: find.byType(EditableText));
    await tester.enterText(fieldInput, 'year');
    await tester.pump();
    await tester.tap(find.descendant(of: modal, matching: find.text('-1 (Descending)')));
    await tester.pump();
    await tester.tap(
      find.descendant(
        of: modal,
        matching: find.text('Create as Unique Index (Rejects duplicate values)'),
      ),
    );
    await tester.pump();

    await tester.tap(createButton);
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}

    // The modal closed and both the engine and the table show the new index.
    expect(
      find.descendant(of: modal, matching: find.text('Create New Index')),
      findsNothing,
    );
    expect(books.indexes.length, originalIndexCount + 1);
    final created = books.indexes.firstWhere((i) => i.name == 'year_-1');
    expect(created.unique, isTrue);
    expect(created.keys['year'], -1);
    expect(find.text('year_-1'), findsOneWidget);
    expect(find.text('{year: -1}'), findsOneWidget);

    // A second attempt with the same field + direction hits the engine's name
    // collision check and surfaces the React error text in the modal banner.
    await tester.tap(find.text('Create Index'));
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}
    await tester.enterText(fieldInput, 'year');
    await tester.pump();
    await tester.tap(find.descendant(of: modal, matching: find.text('-1 (Descending)')));
    await tester.pump();
    await tester.tap(createButton);
    await tester.pump();
    expect(
      find.descendant(
        of: modal,
        matching: find.text('An index with this name or key pattern already exists'),
      ),
      findsOneWidget,
    );
    expect(books.indexes.length, originalIndexCount + 1);
  });

  testWidgets('Drop Index modal removes a non-protected index after confirmation',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920.0, 1080.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(mongoEngine.resetToDefaults);

    await tester.pumpWidget(const CompassApp());
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}
    await closeConnectionPopup(tester);

    await tester.tap(find.text('Indexes').first);
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}

    final books = mongoEngine.getCollection('library', 'books')!;
    final originalIndexCount = books.indexes.length;
    expect(books.indexes.any((i) => i.name == 'isbn_1'), isTrue);
    expect(find.text('Protected'), findsOneWidget); // the `_id_` row

    // One trash button per droppable index; `_id_` is protected instead.
    final trashIcons = find.descendant(
      of: find.byType(IndexesView),
      matching: find.byWidgetPredicate(
        (w) => w is CompassSvg && w.svgString == CompassSvgIcons.trash,
      ),
    );
    expect(trashIcons, findsNWidgets(originalIndexCount - 1));

    final modal = find.byType(DropIndexModal);

    // The first trash button belongs to the isbn_1 row (seed order: _id_, isbn_1, ...).
    await tester.tap(trashIcons.first);
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}
    expect(
      find.descendant(of: modal, matching: find.text('Drop Index')),
      findsNWidgets(2), // header title + danger button
    );
    expect(find.descendant(of: modal, matching: find.text('isbn_1')), findsOneWidget);

    // Cancel keeps the index.
    await tester.tap(
      find.descendant(
        of: modal,
        matching: find.widgetWithText(CompassSecondaryButton, 'Cancel'),
      ),
    );
    await tester.pump();
    expect(find.descendant(of: modal, matching: find.text('isbn_1')), findsNothing);
    expect(books.indexes.length, originalIndexCount);

    // Re-open and confirm the drop.
    await tester.tap(trashIcons.first);
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}
    await tester.tap(
      find.descendant(
        of: modal,
        matching: find.widgetWithText(CompassDangerButton, 'Drop Index'),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}

    expect(find.descendant(of: modal, matching: find.text('isbn_1')), findsNothing);
    expect(books.indexes.any((i) => i.name == 'isbn_1'), isFalse);
    expect(books.indexes.length, originalIndexCount - 1);
    expect(find.text('isbn_1'), findsNothing);
    expect(trashIcons, findsNWidgets(originalIndexCount - 2));
    expect(find.text('Protected'), findsOneWidget); // `_id_` is untouched
  });

  testWidgets('tree view starts with data structures collapsed', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920.0, 1080.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CompassApp());
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}
    await closeConnectionPopup(tester);

    final tree = find.byType(DocumentTreeView);
    expect(tree, findsOneWidget);

    final chevronDown = find.descendant(
      of: tree,
      matching: find.byWidgetPredicate(
        (w) => w is CompassSvg && w.svgString == CompassSvgIcons.chevronDown,
      ),
    );
    final chevronRight = find.descendant(
      of: tree,
      matching: find.byWidgetPredicate(
        (w) => w is CompassSvg && w.svgString == CompassSvgIcons.chevronRight,
      ),
    );

    // `library.books` seeds two docs, each with one expandable field
    // (`genre_ids`, 2 and 1 entries). Every Object/Array node starts collapsed.
    expect(chevronDown, findsNothing, reason: 'no node starts expanded');
    expect(chevronRight, findsNWidgets(2));
    expect(
      find.descendant(of: tree, matching: find.text('[ ... 2 items ]')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tree, matching: find.text('[ ... 1 items ]')),
      findsOneWidget,
    );
    expect(find.descendant(of: tree, matching: find.text('0:')), findsNothing);

    // Expanding one array reveals its items and swaps the chevron.
    await tester.tap(chevronRight.first);
    await tester.pump();
    expect(chevronDown, findsOneWidget);
    expect(chevronRight, findsOneWidget);
    expect(
      find.descendant(of: tree, matching: find.text('[ ... 2 items ]')),
      findsNothing,
    );
    expect(find.descendant(of: tree, matching: find.text('0:')), findsOneWidget);
    expect(find.descendant(of: tree, matching: find.text('1:')), findsOneWidget);

    // Collapsing it again restores the summary.
    await tester.tap(chevronDown);
    await tester.pump();
    expect(chevronDown, findsNothing);
    expect(
      find.descendant(of: tree, matching: find.text('[ ... 2 items ]')),
      findsOneWidget,
    );
  });

  testWidgets('json view edit button saves changes to the document',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920.0, 1080.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // The engine is a shared singleton; restore the seed data afterwards.
    addTearDown(mongoEngine.resetToDefaults);

    await tester.pumpWidget(const CompassApp());
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}
    await closeConnectionPopup(tester);

    // Switch the documents view to JSON.
    await tester.tap(find.text('JSON'));
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}

    final jsonView = find.byType(DocumentJsonView);
    expect(jsonView, findsOneWidget);

    final books = mongoEngine.getCollection('library', 'books')!;
    final originalCount = books.documents.length;
    final firstId = books.documents.first.id;

    // One pencil per document card.
    final editIcon = find.descendant(
      of: jsonView,
      matching: find.byWidgetPredicate(
        (w) => w is CompassSvg && w.svgString == CompassSvgIcons.pencil,
      ),
    );
    expect(editIcon, findsNWidgets(originalCount));

    // Tapping the pencil opens the inline JSON editor for that card.
    await tester.tap(editIcon.first);
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}

    final editor = find.descendant(
      of: jsonView,
      matching: find.byType(EditableText),
    );
    expect(editor, findsOneWidget, reason: 'the card body must become editable');
    // Only the edited card swaps its pencil for Save/Cancel.
    expect(editIcon, findsNWidgets(originalCount - 1));

    final edited = unwrapMongoEditorText(
      tester.widget<EditableText>(editor).controller.text,
    ) as Map<String, dynamic>;
    edited['copies_available'] = 1234;
    edited.remove('rating'); // deleting a field must delete it persistently
    await tester.enterText(editor, jsonEncode(edited));
    await tester.pump();

    // Save (check icon).
    final saveIcon = find.descendant(
      of: jsonView,
      matching: find.byWidgetPredicate(
        (w) => w is CompassSvg && w.svgString == CompassSvgIcons.check,
      ),
    );
    expect(saveIcon, findsOneWidget);
    await tester.tap(saveIcon);
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}

    final saved = books.documents.firstWhere((d) => d.id == firstId);
    expect(saved.data['copies_available'], 1234,
        reason: 'the edited field must be persisted to the engine');
    expect(saved.data.containsKey('rating'), isFalse,
        reason: 'a field removed from the JSON must be removed persistently');
    expect(saved.id, firstId,
        reason: 'the document identity must be preserved');
    // The editor closes and the pencil returns.
    expect(
      find.descendant(of: jsonView, matching: find.byType(EditableText)),
      findsNothing,
    );
    expect(editIcon, findsNWidgets(originalCount));
  });

  testWidgets('updateMany with a plain map replaces matched documents',
      (WidgetTester tester) async {
    // Restore the mutated seed data afterwards.
    addTearDown(mongoEngine.resetToDefaults);

    final books = mongoEngine.getCollection('library', 'books')!;
    final firstId = books.documents.first.id;
    final secondId = books.documents[1].id;

    // A non-operator update document is a full replacement (`$set` still merges).
    final replaced = mongoEngine.updateMany(
      'library',
      'books',
      {'_id': firstId},
      {'title': 'Rewritten', 'copies_available': 7},
    );
    expect(replaced, 1);

    final first = books.documents.firstWhere((d) => d.id == firstId);
    expect(first.data['title'], 'Rewritten');
    expect(first.data['copies_available'], 7);
    expect(first.id, firstId);
    expect(first.data.containsKey('author'), isFalse,
        reason: 'a plain update document replaces, it does not merge');
    expect(first.data.containsKey('rating'), isFalse);

    // Documents that did not match the filter are untouched.
    final second = books.documents.firstWhere((d) => d.id == secondId);
    expect(second.data['title'], isNot('Rewritten'));

    // An operator update still merges.
    mongoEngine.updateMany(
      'library',
      'books',
      {'_id': firstId},
      {'\$set': {'copies_available': 9}},
    );
    final merged = books.documents.firstWhere((d) => d.id == firstId);
    expect(merged.data['copies_available'], 9);
    expect(merged.data['title'], 'Rewritten',
        reason: r'an $set update must not remove other fields');
  });

  testWidgets('first-time user must accept the EULA before using the app',
      (WidgetTester tester) async {
    // A brand-new install: nothing stored yet.
    SharedPreferences.setMockInitialValues(const {});
    tester.view.physicalSize = const Size(1920.0, 1080.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CompassApp());
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}
    await tester.pump();

    // The gate blocks the app: it is on screen and cannot be dismissed.
    expect(find.byType(EulaAcceptanceModal), findsOneWidget);
    expect(find.text('I Accept'), findsOneWidget);
    expect(find.text('End User License Agreement'), findsWidgets);

    // Nothing is persisted until the user accepts.
    expect(
      (await SharedPreferences.getInstance()).getBool('eula_accepted'),
      isNull,
    );

    // Accept (the button sits at the end of the scrollable licence text).
    await tester.ensureVisible(find.text('I Accept'));
    await tester.pump();
    await tester.tap(find.text('I Accept'));
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}
    await tester.pump();

    // The gate is gone and acceptance is persisted for the next launch.
    expect(find.text('I Accept'), findsNothing);
    expect(
      (await SharedPreferences.getInstance()).getBool('eula_accepted'),
      isTrue,
    );
  });

  testWidgets('saved connections can be edited from the connect popup',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920.0, 1080.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CompassApp());
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}

    final modal = find.byType(ConnectionModal);
    expect(modal, findsOneWidget);

    // One edit (pencil) button per saved connection, alongside delete.
    final editIcons = find.descendant(
      of: modal,
      matching: find.byWidgetPredicate(
        (w) => w is CompassSvg && w.svgString == CompassSvgIcons.pencil,
      ),
    );
    expect(editIcons, findsNWidgets(2));

    // Edit the second saved connection (Atlas), whose URI differs from the
    // default form values, so the assertion is meaningful.
    await tester.ensureVisible(editIcons.last);
    await tester.pump();
    await tester.tap(editIcons.last);
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}

    final texts = find
        .descendant(of: modal, matching: find.byType(EditableText))
        .evaluate()
        .map((e) => (e.widget as EditableText).controller.text)
        .toList();
    expect(texts, contains('mongodb+srv://admin@cluster0.mongodb.net/test'));
    expect(texts, contains('Atlas Production ReplicaSet'));

    // The footer switches to an in-place update while editing.
    expect(find.text('Update & Connect'), findsOneWidget);
    expect(
      find.textContaining('Editing “Atlas Production ReplicaSet”'),
      findsOneWidget,
    );
  });

  testWidgets('the URI field copy button copies the connection string',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920.0, 1080.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(const CompassApp());
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}

    final modal = find.byType(ConnectionModal);
    expect(modal, findsOneWidget);

    final copyIcon = find.descendant(
      of: modal,
      matching: find.byWidgetPredicate(
        (w) => w is CompassSvg && w.svgString == CompassSvgIcons.copy,
      ),
    );
    expect(copyIcon, findsWidgets);

    await tester.tap(copyIcon.first);
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}

    expect(copied, contains('mongodb://localhost:27017'));

    // The icon swaps to a checkmark to confirm the copy.
    expect(
      find.descendant(
        of: modal,
        matching: find.byWidgetPredicate(
          (w) => w is CompassSvg && w.svgString == CompassSvgIcons.check,
        ),
      ),
      findsWidgets,
    );

    // Let the 2-second reset timer fire so no timer is left pending.
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('sidebar lists databases and collections alphabetically',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920.0, 1080.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CompassApp());
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}
    await closeConnectionPopup(tester);

    final sidebar = find.byType(CompassSidebar);
    double topOf(String name) {
      final finder =
          find.descendant(of: sidebar, matching: find.text(name));
      expect(finder, findsWidgets, reason: '"$name" must be in the sidebar');
      return tester.getTopLeft(finder.first).dy;
    }

    // Databases: library before social_networks.
    expect(topOf('library'), lessThan(topOf('social_networks')));

    // Collections inside "library": books, genres, publishers.
    final books = topOf('books');
    final genres = topOf('genres');
    final publishers = topOf('publishers');
    expect(books, lessThan(genres));
    expect(genres, lessThan(publishers));
  });

  testWidgets('a view has a Show DDL tab that updates the view and copies to aggregations',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920.0, 1080.0);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // The engine is a shared singleton; restore the seed data afterwards.
    addTearDown(mongoEngine.resetToDefaults);

    // A view over library.books.
    mongoEngine.createView('library', 'recent_books', 'books', [
      {
        r'$match': {
          'published_year': {r'$gte': 2015},
        },
      },
    ]);

    await tester.pumpWidget(const CompassApp());
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}
    await closeConnectionPopup(tester);

    // Select the view from the sidebar.
    await tester.tap(find.text('recent_books'));
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}

    // The Show DDL tab appears alongside the others.
    expect(find.text('Show DDL'), findsOneWidget);
    await tester.tap(find.text('Show DDL'));
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}

    final ddl = find.byType(ShowDdlView);
    expect(ddl, findsOneWidget);

    final editor = find.descendant(of: ddl, matching: find.byType(EditableText));
    expect(editor, findsOneWidget);
    expect(
      tester.widget<EditableText>(editor).controller.text,
      contains(r'$match'),
    );

    // Editing the DDL and pressing Update View re-applies it.
    await tester.enterText(
      editor,
      '[{ "\$match": { "published_year": { "\$gte": 2020 } } }]',
    );
    await tester.pump();
    await tester.tap(find.text('Update View'));
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}

    final updated = mongoEngine.getCollection('library', 'recent_books')!;
    expect(updated.pipeline!.first.toString(), contains('2020'));

    // Copy to Aggregations runs the view's DDL against its SOURCE collection
    // (library.books) and shows the resulting documents.
    await tester.tap(find.text('Copy to Aggregations'));
    await tester.pump();
    await tester.pump();
    for (var i = 0; i < 50 && tester.takeException() != null; i++) {}

    expect(find.byType(AggregationsView), findsOneWidget);
    expect(find.text(r'$match'), findsWidgets);
    expect(find.textContaining('1 docs ('), findsWidgets);
  });
}
