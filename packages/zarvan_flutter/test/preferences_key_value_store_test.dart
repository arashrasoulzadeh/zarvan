import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart';

void main() {
  test('PreferencesKeyValueStore round-trips and survives reopening', () async {
    SharedPreferences.setMockInitialValues({});
    final a = await PreferencesKeyValueStore.open();
    expect(await a.getString('save'), isNull);
    await a.setString('save', '{"v":1}');
    final b = await PreferencesKeyValueStore.open();
    expect(await b.getString('save'), '{"v":1}');
    await b.remove('save');
    expect(await a.getString('save'), isNull);
  });

  test('values present before the app starts are readable', () async {
    SharedPreferences.setMockInitialValues({'old': 'data'});
    final s = await PreferencesKeyValueStore.open();
    expect(await s.getString('old'), 'data');
  });
}
