import 'package:test/test.dart';
import 'package:zarvan_core/zarvan_core_quiz.dart';

QuizItem item(List<String> lines) => QuizItem(id: 'x', lines: lines);

Set<(int, int)> picked(
  QuizItem it,
  QuizTier tier, {
  Set<String> stop = const {},
  int seeds = 40,
}) {
  final out = <(int, int)>{};
  for (var s = 0; s < seeds; s++) {
    final p = BlankPicker.pick(
      it,
      tier,
      SeededRandom(s),
      QuizText.normalizeAll(stop),
    );
    if (p != null) out.add((p.line, p.token));
  }
  return out;
}

void main() {
  final plain = item(['الف بب جج', 'دد ههه وو']);

  test('R-BLANK-2: easy picks the last content word of a line', () {
    expect(picked(plain, QuizTier.easy), {(0, 2), (1, 2)});
  });

  test(
    'R-BLANK-2: a stop word at the end of a line moves the target one back',
    () {
      expect(picked(plain, QuizTier.easy, stop: {'جج'}), {(0, 1), (1, 2)});
    },
  );

  test('R-BLANK-3: medium never picks the last word of a line', () {
    expect(picked(plain, QuizTier.medium), {(0, 0), (0, 1), (1, 0), (1, 1)});
  });

  test('R-BLANK-4: hard and literary may pick any content word', () {
    final all = {
      for (var l = 0; l < 2; l++)
        for (var t = 0; t < 3; t++) (l, t),
    };
    expect(picked(plain, QuizTier.hard), all);
    expect(picked(plain, QuizTier.literary), all);
  });

  test('R-BLANK-1: stop words and one-letter words are never picked', () {
    final it = item(['الف بب و', 'دد ههه وو']);
    final got = picked(it, QuizTier.hard, stop: {'الف'});
    expect(got.contains((0, 0)), isFalse); // stop word
    expect(got.contains((0, 2)), isFalse); // one letter
    expect(got.length, 4);
  });

  test('R-BLANK-5: an empty tier set falls back to every content word', () {
    final it = item(['از عشق', 'به دل']);
    expect(picked(it, QuizTier.medium, stop: {'از', 'به'}), {(0, 1), (1, 1)});
  });

  test('R-BLANK-5: an item with no content word cannot be asked', () {
    expect(
      BlankPicker.pick(item(['از به']), QuizTier.easy, SeededRandom(1), {
        'از',
        'به',
      }),
      isNull,
    );
    expect(
      BlankPicker.pick(item([]), QuizTier.hard, SeededRandom(1), const {}),
      isNull,
    );
  });

  test('R-BLANK-6: a word that repeats in the item is never blanked', () {
    final it = item(['عشق بب', 'عشق جج']);
    expect(picked(it, QuizTier.hard), {(0, 1), (1, 1)});
  });

  test('R-BLANK-6: repeats are found after normalization (ي vs ی)', () {
    final it = item(['عشقي بب', 'عشقی جج']);
    expect(picked(it, QuizTier.hard), {(0, 1), (1, 1)});
  });

  test(
    'R-BLANK-6: when repeats empty the tier set, the any-word fallback applies',
    () {
      final it = item(['دل عشق', 'گل عشق']);
      expect(picked(it, QuizTier.easy), {(0, 0), (1, 0)});
    },
  );

  test('R-BLANK-6: if every content word repeats the item cannot be asked', () {
    expect(picked(item(['عشق عشق']), QuizTier.hard), isEmpty);
  });

  test('the same seed picks the same blank', () {
    BlankPosition? at(int s) =>
        BlankPicker.pick(plain, QuizTier.hard, SeededRandom(s), const {});
    expect(at(5)!.line, at(5)!.line);
    expect(at(5)!.token, at(5)!.token);
  });
}
