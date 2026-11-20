import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/shader_cost.dart';

void main() {
  test('nested loops multiply the cost of the calls inside them', () {
    final c = analyzeShader('''
void main() {
  float a = sin(1.0);
  for (int i = 0; i < 4; i++) {
    for (int j = 0; j <= 2; j++) {
      a += cos(float(j)) + texture(uImg, p).r;
    }
  }
}
''');
    expect(c.loops, 2);
    expect(c.maxLoopDepth, 2);
    expect(c.worstCaseIterations, 12);
    expect(c.transcendentals, 2);
    expect(c.weightedTranscendentals, 1 + 12);
    expect(c.weightedTextureReads, 12);
    expect(c.score, 13 + 4 * 12);
  });

  test('comments do not count and straight-line code costs one pass', () {
    final c = analyzeShader(
      '// sin(x) pow(x, 2.0)\nvoid main() { x = sqrt(y); }',
    );
    expect(c.transcendentals, 1);
    expect(c.weightedTranscendentals, 1);
    expect(c.loops, 0);
  });

  test('every shipped shader can be analysed', () {
    final files = Directory(
      'shaders',
    ).listSync().whereType<File>().where((f) => f.path.endsWith('.frag'));
    expect(files, isNotEmpty);
    for (final f in files) {
      expect(
        analyzeShader(f.readAsStringSync()).lines,
        greaterThan(1),
        reason: f.path,
      );
    }
  });
}
