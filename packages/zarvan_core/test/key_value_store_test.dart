import 'package:test/test.dart';
import 'package:zarvan_core/zarvan_core.dart';

void main() {
  test('stores, replaces and removes strings', () async {
    final s = MemoryKeyValueStore();
    expect(await s.getString('a'), isNull);
    await s.setString('a', '1');
    expect(await s.getString('a'), '1');
    await s.setString('a', '2');
    expect(await s.getString('a'), '2');
    await s.remove('a');
    expect(await s.getString('a'), isNull);
    await s.remove('missing');
  });

  test('keys are independent and the initial map is copied', () async {
    final seed = {'x': 'y'};
    final s = MemoryKeyValueStore(seed);
    seed['x'] = 'changed';
    expect(await s.getString('x'), 'y');
    await s.setString('z', 'w');
    expect(await s.getString('x'), 'y');
    expect(s.values.keys, containsAll(['x', 'z']));
  });
}
