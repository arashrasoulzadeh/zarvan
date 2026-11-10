import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart';

class _Bundle extends CachingAssetBundle {
  _Bundle(this.files);
  final Map<String, String> files;
  @override
  Future<ByteData> load(String key) async {
    final s = files[key];
    if (s == null) throw FlutterError('missing $key');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(s)));
  }
}

void main() {
  test('loadJsonAsset decodes a JSON object', () async {
    final m = await loadJsonAsset(
      'a.json',
      bundle: _Bundle({'a.json': '{"x": 3, "y": [1]}'}),
    );
    expect(m['x'], 3);
    expect(m['y'], [1]);
  });

  test('a non-object JSON file is rejected', () async {
    expect(
      loadJsonAsset('a.json', bundle: _Bundle({'a.json': '[1,2]'})),
      throwsFormatException,
    );
  });

  test('a missing asset fails', () async {
    expect(
      loadJsonAsset('nope.json', bundle: _Bundle({})),
      throwsA(isA<FlutterError>()),
    );
  });
}
