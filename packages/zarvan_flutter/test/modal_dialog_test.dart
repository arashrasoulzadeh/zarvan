import 'dart:ui' show Offset, Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:zarvan_core/zarvan_core.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart' as eng;

World _world() {
  final w = World(width: 180, height: 320);
  registerCoreComponents(w);
  eng.registerFlutterComponents(w);
  return w;
}

eng.ModalDialog _dialog(World w, {bool pause = true}) => eng.ModalDialog.spawn(
  w,
  rect: const Rect.fromLTRB(20, 80, 160, 220),
  z: 150,
  frameAtlasId: 'panel',
  title: 'Hero',
  pause: pause,
);

double _sigma(World w) => w.componentsOf<eng.BackdropBlur>().denseAt(0).sigma;

void main() {
  test('a closed dialog parks its content off screen, blur off', () {
    final w = _world();
    final d = _dialog(w);
    final label = d.addText(90, 150, 'hi', 5, 0xFFFFFFFF);
    expect(d.isOpen, isFalse);
    expect(w.componentsOf<Position>().get(label)!.y, greaterThan(1000));
    expect(_sigma(w), 0);
  });

  test('opening pauses the world and fades the blur and content in', () {
    final w = _world();
    final d = _dialog(w);
    final label = d.addText(90, 150, 'hi', 5, 0xFFFFFFFF);
    d.open();
    expect(w.timeScale, 0, reason: 'dialogs pause the game');
    expect(w.componentsOf<Position>().get(label)!.y, 150);
    d.update(0.1);
    expect(_sigma(w), greaterThan(0));
    expect(_sigma(w), lessThan(3));
    d.update(1);
    expect(_sigma(w), 3);
    expect(
      (w.componentsOf<eng.Text>().get(label)!.colorArgb >> 24) & 0xFF,
      255,
    );
  });

  test('closing restores the time scale and parks everything again', () {
    final w = _world()..timeScale = 1;
    final d = _dialog(w);
    final label = d.addText(90, 150, 'hi', 5, 0xFFFFFFFF);
    d
      ..open()
      ..update(1)
      ..close();
    expect(w.timeScale, 1);
    d.update(1);
    expect(_sigma(w), 0);
    expect(w.componentsOf<Position>().get(label)!.y, greaterThan(1000));
  });

  test('pause: false leaves the world running', () {
    final w = _world();
    _dialog(w, pause: false).open();
    expect(w.timeScale, 1);
  });

  test('closesOn is true outside the panel and on the X, false inside', () {
    final w = _world();
    final d = _dialog(w);
    expect(d.closesOn(const Offset(5, 5)), isTrue);
    expect(d.closesOn(const Offset(90, 150)), isFalse);
    expect(d.closesOn(const Offset(144, 93)), isTrue, reason: 'the X');
  });

  test('setTitle rewrites the title text', () {
    final w = _world();
    _dialog(w).setTitle('Shop');
    final texts = w.componentsOf<eng.Text>();
    expect([
      for (var i = 0; i < texts.length; i++) texts.denseAt(i).text,
    ], contains('Shop'));
  });
}
