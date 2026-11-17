import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zarvan_core/zarvan_core.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart' hide Text;

Widget host(Widget child, {double w = 300, double h = 200}) => MaterialApp(
  home: Scaffold(body: Center(child: SizedBox(width: w, height: h, child: child))),
);

void main() {
  testWidgets('list builds only visible rows, scrolls by drag and wheel', (t) async {
    final m = ScrollListModel(itemCount: 100, itemHeight: 50, viewportHeight: 200);
    await t.pumpWidget(host(ModelScrollList(
      model: m,
      itemBuilder: (c, i, s) => Text('row $i'),
    )));
    expect(find.text('row 0'), findsOneWidget);
    expect(find.text('row 50'), findsNothing);
    expect(find.byType(Positioned), findsAtLeastNWidgets(4));
    expect(find.byType(Positioned).evaluate().length, lessThan(10));

    await t.drag(find.byType(ModelScrollList), const Offset(0, -120)); // 20px of touch slop is not scrolled
    await t.pump();
    expect(m.offset, 100);
    expect(find.text('row 0'), findsNothing);
    expect(find.text('row 2'), findsOneWidget);

    final p = TestPointer(1, PointerDeviceKind.mouse);
    await t.sendEventToBinding(p.hover(t.getCenter(find.byType(ModelScrollList))));
    await t.sendEventToBinding(p.scroll(const Offset(0, 50)));
    await t.pump();
    expect(m.offset, 150);
  });

  testWidgets('tap selects and activates the row under the finger', (t) async {
    final m = ScrollListModel(itemCount: 10, itemHeight: 50, viewportHeight: 200);
    int? hit;
    await t.pumpWidget(host(ModelScrollList(
      model: m,
      onActivate: (i) => hit = i,
      itemBuilder: (c, i, s) => Text(s ? 'sel $i' : 'row $i'),
    )));
    await t.tapAt(t.getTopLeft(find.byType(ModelScrollList)) + const Offset(10, 120));
    await t.pump();
    expect(hit, 2);
    expect(m.selected, 2);
    expect(find.text('sel 2'), findsOneWidget);
  });

  testWidgets('arrow keys move the selection and Enter activates it', (t) async {
    final m = ScrollListModel(itemCount: 10, itemHeight: 50, viewportHeight: 200);
    int? hit;
    await t.pumpWidget(host(ModelScrollList(
      model: m,
      autofocus: true,
      onActivate: (i) => hit = i,
      itemBuilder: (c, i, s) => Text('row $i'),
    )));
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(m.selected, isNotNull);
    expect(hit, m.selected);
  });

  testWidgets('text field routes keys into the model, honoring its limit', (t) async {
    final m = TextInputModel(maxLength: 3);
    String? changed, submitted;
    await t.pumpWidget(host(ModelTextField(
      model: m,
      autofocus: true,
      onChanged: (s) => changed = s,
      onSubmitted: (s) => submitted = s,
    )));
    await t.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'a');
    await t.sendKeyEvent(LogicalKeyboardKey.keyB, character: 'b');
    await t.sendKeyEvent(LogicalKeyboardKey.keyC, character: 'c');
    await t.sendKeyEvent(LogicalKeyboardKey.keyD, character: 'd');
    expect(m.text, 'abc');
    await t.sendKeyEvent(LogicalKeyboardKey.backspace);
    expect(changed, 'ab');
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(submitted, 'ab');
  });

  testWidgets('tabs build only the selected page and report changes', (t) async {
    int? changed;
    await t.pumpWidget(host(GameTabs(
      onChanged: (i) => changed = i,
      tabs: [
        GameTab(label: 'Shop', builder: (_) => const Text('shop page')),
        GameTab(label: 'Bag', builder: (_) => const Text('bag page')),
      ],
    )));
    expect(find.text('shop page'), findsOneWidget);
    expect(find.text('bag page'), findsNothing);
    await t.tap(find.byKey(const ValueKey('tab_1')));
    await t.pump();
    expect(changed, 1);
    expect(find.text('bag page'), findsOneWidget);
    expect(find.text('shop page'), findsNothing);
  });

  testWidgets('popup is pinned by anchor and dismisses on the scrim', (t) async {
    late BuildContext ctx;
    await t.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));
    showGamePopup<void>(ctx, anchor: UiAnchor.bottomRight, width: 100, height: 60, child: const Text('pop'));
    await t.pumpAndSettle();
    final r = t.getRect(find.ancestor(of: find.text('pop'), matching: find.byType(Material)).first);
    final screen = t.view.physicalSize / t.view.devicePixelRatio;
    expect(r.right, screen.width);
    expect(r.bottom, screen.height);
    expect(r.size, const Size(100, 60));
    await t.tapAt(const Offset(5, 5));
    await t.pumpAndSettle();
    expect(find.text('pop'), findsNothing);
  });

  testWidgets('tooltip shows its message on long press', (t) async {
    await t.pumpWidget(host(const GameTooltip(message: 'Sharp blade', child: Text('sword'))));
    await t.longPress(find.text('sword'));
    await t.pump();
    expect(find.text('Sharp blade'), findsOneWidget);
  });
}
