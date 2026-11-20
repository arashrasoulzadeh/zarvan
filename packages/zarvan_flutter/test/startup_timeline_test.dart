import 'package:flutter_test/flutter_test.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart';

void main() {
  test('marks keep their order and never go backwards', () {
    final t = StartupTimeline(sink: (_) {});
    t.mark('a');
    t.mark('b');
    t.mark('c');
    expect([for (final m in t.marks) m.$1], ['a', 'b', 'c']);
    expect(t.marks[1].$2, greaterThanOrEqualTo(t.marks[0].$2));
    expect(t.marks[2].$2, greaterThanOrEqualTo(t.marks[1].$2));
  });

  test('format shows each phase with its total and its own share', () {
    final t = StartupTimeline(sink: (_) {});
    t.mark('font');
    t.mark('assets');
    expect(
      t.format(),
      matches(RegExp(r'^font=\d+\(\+\d+\)ms assets=\d+\(\+\d+\)ms$')),
    );
  });

  test('flush writes one tagged line, and nothing when nothing was marked', () {
    final lines = <String>[];
    final t = StartupTimeline(sink: lines.add);
    t.flush();
    expect(lines, isEmpty);
    t.mark('ready');
    t.flush();
    expect(lines, hasLength(1));
    expect(lines.single, startsWith('[zarvan:startup] ready='));
  });
}
