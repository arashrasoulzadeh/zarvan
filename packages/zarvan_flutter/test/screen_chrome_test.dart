import 'package:flutter_test/flutter_test.dart';
import 'package:zarvan_core/zarvan_core.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart' as eng;
import 'package:zarvan_flutter/zarvan_flutter.dart'
    show NavTab, ScreenChrome, ScreenChromeStyle;

World _world() {
  final w = World(width: 180, height: 320);
  registerCoreComponents(w);
  eng.registerFlutterComponents(w);
  return w;
}

const _tabs = [
  NavTab(id: 'battle', label: 'Battle', icon: 0),
  NavTab(id: 'hero', label: 'Hero', icon: 1),
  NavTab(id: 'upgrade', label: 'Upgrade', icon: 2),
  NavTab(id: 'skills', label: 'Skills', icon: 3),
  NavTab(id: 'allies', label: 'Allies', icon: 4),
  NavTab(id: 'shop', label: 'Shop', icon: 5),
];

ScreenChrome _spawn(World w, {bool rtl = false}) => ScreenChrome.spawn(
  w,
  style: ScreenChromeStyle(tabs: _tabs, rtl: rtl),
  fillAtlasId: 'panel',
  iconAtlasId: 'tabs',
  currencyAtlasId: 'coins',
);

List<String> _texts(World w) {
  final t = w.componentsOf<eng.Text>();
  return [for (var i = 0; i < t.length; i++) t.denseAt(i).text];
}

void main() {
  group('ScreenChrome', () {
    test('hit maps a tap on the bottom bar to the tab under it', () {
      final chrome = _spawn(_world());
      // Six tabs across 180 units: the first starts at x=3, the last ends ~177.
      expect(chrome.hit(const Offset(15, 305)), 'battle');
      expect(chrome.hit(const Offset(90, 305)), anyOf('upgrade', 'skills'));
      expect(chrome.hit(const Offset(165, 305)), 'shop');
      expect(chrome.hit(const Offset(15, 200)), isNull, reason: 'not the bar');
    });

    test('safeInset keeps the tabs out of the cropped side margins', () {
      final chrome = ScreenChrome.spawn(
        _world(),
        style: const ScreenChromeStyle(tabs: _tabs, safeInset: 20),
        fillAtlasId: 'panel',
      );
      expect(chrome.hit(const Offset(10, 305)), isNull, reason: 'cropped edge');
      expect(chrome.hit(const Offset(170, 305)), isNull);
      expect(chrome.hit(const Offset(30, 305)), 'battle');
      expect(chrome.hit(const Offset(150, 305)), 'shop');
    });

    test('right to left mirrors the tab order', () {
      final chrome = _spawn(_world(), rtl: true);
      expect(chrome.hit(const Offset(165, 305)), 'battle');
      expect(chrome.hit(const Offset(15, 305)), 'shop');
    });

    test('setActive moves the highlight under the chosen tab', () {
      final w = _world();
      final chrome = _spawn(w);
      final sprites = w.componentsOf<eng.Sprite>();
      Position highlight() {
        for (var i = 0; i < sprites.length; i++) {
          if (sprites.denseAt(i).tintArgb == 0x80C0802C) {
            return w.componentsOf<Position>().get(sprites.entityAt(i))!;
          }
        }
        throw StateError('no highlight');
      }

      expect(chrome.active, -1, reason: 'no tab is open at start');
      expect(highlight().y, lessThan(0), reason: 'highlight hidden');
      final first = highlight().x;
      chrome.setActive(chrome.indexOf('shop'));
      expect(chrome.active, 5);
      expect(highlight().x, greaterThan(first + 100));
      chrome.setActive(99);
      expect(chrome.active, 5, reason: 'clamped to the last tab');
      chrome.setActive(-1);
      expect(highlight().y, lessThan(0));
    });

    test('sync writes the gold, gems and title; tabs carry their labels', () {
      final w = _world();
      final chrome = _spawn(w);
      chrome.sync(gold: '12.4K', gems: '38', title: 'A1 — Zabulistan');
      final texts = _texts(w);
      expect(
        texts,
        containsAll(['12.4K', '38', 'A1 — Zabulistan', 'Battle', 'Shop']),
      );
    });

    test('draws the six tab icons and the two currency icons', () {
      final w = _world();
      _spawn(w);
      final sprites = w.componentsOf<eng.Sprite>();
      int count(String atlas) => [
        for (var i = 0; i < sprites.length; i++)
          if (sprites.denseAt(i).atlasId == atlas) 1,
      ].length;
      expect(count('tabs'), 6);
      expect(count('coins'), 2);
    });
  });
}
