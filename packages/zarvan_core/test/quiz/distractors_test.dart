import 'package:test/test.dart';
import 'package:zarvan_core/zarvan_core_quiz.dart';

QuizBank bank(Map<String, List<String>> byAuthor) => QuizBank(
  authors: [for (final a in byAuthor.keys) QuizAuthor(id: a, name: a)],
  items: [
    for (final e in byAuthor.entries)
      for (var i = 0; i < e.value.length; i++)
        QuizItem(id: '${e.key}$i', author: e.key, lines: [e.value[i]]),
  ],
);

Set<String> norm(Iterable<WordEntry> es) => {for (final e in es) e.word};

DistractorResult pick(
  QuizBank b,
  String targetId,
  String answer,
  QuizTier tier, {
  int seed = 1,
}) {
  final target = b.byId(targetId)!;
  return Distractors.pick(
    item: target,
    answer: answer,
    tier: tier,
    index: WordIndex.build(b, const {}),
    rng: SeededRandom(seed),
  );
}

void main() {
  // The answer is 'عشق' (3 letters, ending 'شق').
  final target = 'عشق دل';

  test(
    'R-DIST-3: easy options differ from the answer length by at least two',
    () {
      final b = bank({
        'a': [target, 'سلامت حکمتی', 'نسبت رحیم', 'کتابخانه'],
      });
      final r = pick(b, 'a0', 'عشق', QuizTier.easy);
      expect(r.words.length, 3);
      for (final w in r.words) {
        expect((w.length - 3).abs(), greaterThanOrEqualTo(2));
      }
      expect(r.usedAnyFallback, isFalse);
    },
  );

  test('R-DIST-4: medium options have the answer length', () {
    final b = bank({
      'a': [target, 'سلم حکم نسب', 'رحم کلاه', 'بلند'],
    });
    final r = pick(b, 'a0', 'عشق', QuizTier.medium);
    expect(r.words.map((w) => w.length), everyElement(3));
    expect(r.words.length, 3);
  });

  test(
    'R-DIST-4: with too few same-length words, lengths one apart fill in',
    () {
      final b = bank({
        'a': [target, 'سلم حکم', 'رحیم بلند'],
      });
      final r = pick(b, 'a0', 'عشق', QuizTier.medium);
      expect(norm(r.words).containsAll({'سلم', 'حکم'}), isTrue);
      final third = r.words.firstWhere((w) => w.length != 3);
      expect((third.length - 3).abs(), lessThanOrEqualTo(1));
      expect(r.usedAnyFallback, isFalse);
    },
  );

  test('R-DIST-5: hard takes same-author rhymes first, then bank rhymes', () {
    final b = bank({
      'a': [target, 'نشق فشق'],
      'b': ['خشق'],
    });
    final r = pick(b, 'a0', 'عشق', QuizTier.hard);
    expect(norm(r.words), {'نشق', 'فشق', 'خشق'});
  });

  test('R-DIST-5: after rhymes run out, equal-length words fill the rest', () {
    final b = bank({
      'a': [target, 'نشق'],
      'b': ['سلم حکم نسب'],
    });
    final r = pick(b, 'a0', 'عشق', QuizTier.literary);
    expect(norm(r.words).contains('نشق'), isTrue);
    expect(r.words.length, 3);
    final rest = r.words.where((w) => w.word != 'نشق');
    expect(rest.map((w) => w.length), everyElement(3));
    expect(r.usedAnyFallback, isFalse);
  });

  test(
    'R-DIST-1: no option equals the answer or another option once normalized',
    () {
      final b = bank({
        'a': [target, 'كتب کتب نسب سلم'],
        'b': ['عشق حکم'],
      });
      for (var s = 0; s < 20; s++) {
        final r = pick(b, 'a0', 'عشق', QuizTier.hard, seed: s);
        final words = [for (final w in r.words) w.word];
        expect(words.toSet().length, words.length);
        expect(words, isNot(contains('عشق')));
      }
    },
  );

  test('R-DIST-2: a word of the target item is never an option', () {
    final b = bank({
      'a': ['عشق دل جان', 'نسب سلم حکم رحم'],
    });
    for (var s = 0; s < 20; s++) {
      final words = pick(
        b,
        'a0',
        'عشق',
        QuizTier.medium,
        seed: s,
      ).words.map((w) => w.word);
      expect(words, isNot(contains('دل')));
      expect(words, isNot(contains('جان')));
    }
  });

  test('R-DIST-6: the order inside a stage comes from the seed', () {
    final b = bank({
      'a': [target, 'نسب سلم حکم رحم بحر کلم'],
    });
    List<String> run(int s) => [
      for (final w in pick(b, 'a0', 'عشق', QuizTier.medium, seed: s).words)
        w.word,
    ];
    expect(run(3), run(3));
    expect(
      {for (var s = 0; s < 15; s++) run(s).join(',')}.length,
      greaterThan(1),
    );
  });

  test(
    'R-DIST-7: a bank with too few words returns what exists and says so',
    () {
      final b = bank({
        'a': [target, 'سلامت حکم'],
      });
      final r = pick(b, 'a0', 'عشق', QuizTier.hard);
      expect(r.words.length, 2);
      expect(r.usedAnyFallback, isTrue);
    },
  );

  test(
    'R-DIST-7: a stage short of candidates is filled from the whole index',
    () {
      final b = bank({
        'a': [target, 'کتابخانه نسب'],
      });
      final r = pick(b, 'a0', 'عشق', QuizTier.easy);
      expect(r.words.length, 2);
      expect(r.usedAnyFallback, isTrue);
    },
  );
}
