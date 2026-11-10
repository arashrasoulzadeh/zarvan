import 'package:flutter_test/flutter_test.dart';
import 'package:zarvan_core/zarvan_core.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart';

class _Colors implements UiColors {
  @override
  int get background => 0xFFFFFFFF;
  @override
  int get ink => 0xFF111111;
  @override
  int get soft => 0xFFAAAAAA;
}

World _world() {
  final w = World(width: 360, height: 640);
  registerCoreComponents(w);
  registerFlutterComponents(w);
  return w;
}

UiBuilder _builder({double dy = 0, String? font}) => UiBuilder(
  _world(),
  _Colors(),
  width: 360,
  height: 640,
  dy: dy,
  fontFamily: font,
);

void main() {
  test('a button runs its action when tapped inside and plays the click', () {
    final ui = _builder();
    var taps = 0, clicks = 0;
    ui.onPress = () => clicks++;
    ui.add(ui.button(const UiRect(10, 10, 100, 40), 'Go', () => taps++));
    expect(ui.tap(500, 500), isFalse);
    expect(ui.tap(20, 20), isTrue);
    expect((taps, clicks), (1, 1));
  });

  test('hidden and disabled buttons ignore taps', () {
    final ui = _builder();
    var taps = 0;
    final b = ui.add(ui.button(const UiRect(0, 0, 50, 50), 'x', () => taps++));
    b.setVisible(false);
    expect(ui.tap(10, 10), isFalse);
    b.setVisible(true);
    b.enabled = false;
    expect(ui.tap(10, 10), isFalse);
    expect(taps, 0);
  });

  test('dy moves both the drawn nodes and the hit box', () {
    final ui = _builder(dy: 50);
    var taps = 0;
    ui.add(ui.button(const UiRect(0, 0, 100, 40), 'x', () => taps++));
    expect(ui.tap(10, 10), isFalse);
    expect(ui.tap(10, 60), isTrue);
    expect(ui.text('t', 5, 5).pos.y, 55);
  });

  test('every label takes the builder font unless it brings its own', () {
    final ui = _builder(font: 'Vazirmatn');
    expect(ui.text('a', 0, 0).text!.fontFamily, 'Vazirmatn');
    final own = UiNode.textNode(
      _world(),
      Text('b', fontFamily: 'Mine'),
      fontFamily: 'Vazirmatn',
    );
    expect(own.text!.fontFamily, 'Mine');
  });

  test('style: outlined ink when enabled, soft when not, solid when filled', () {
    final ui = _builder();
    final b = ui.button(const UiRect(0, 0, 50, 50), 'x', () {});
    expect(b.bg.shape!.colorArgb, 0xFF111111);
    expect(b.bg.shape!.strokeWidth, 2.5);
    b.style(_Colors(), filled: true);
    expect(b.bg.shape!.strokeWidth, 0);
    expect(b.label.text!.colorArgb, 0xFFFFFFFF);
    b.enabled = false;
    b.style(_Colors());
    expect(b.bg.shape!.colorArgb, 0xFFAAAAAA);
  });

  test('a node hides off screen and shows again', () {
    final n = _builder().circle(5, 6, 10, 0xFF000000);
    n.hide();
    expect(n.isHidden, isTrue);
    n.show(1, 2);
    expect((n.pos.x, n.pos.y), (1, 2));
  });
}
