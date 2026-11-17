import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:zarvan_core/zarvan_core_quiz.dart';

/// Rules must hold on real Persian text (rhyme, radif, half-spaces), not only
/// on made-up examples. The fixture is 40 items, one per author and tier,
/// cut from the real bank; its stop words live in the file, not in the code.
void main() {
  final raw =
      jsonDecode(File('test/fixtures/quiz_bank_sample.json').readAsStringSync())
          as Map<String, dynamic>;
  final bank = QuizBank.fromJson(raw);
  final stop = (raw['stopWords'] as List).cast<String>().toSet();
  final factory = QuestionFactory(bank, stop);
  final normStop = QuizText.normalizeAll(stop);

  test('the fixture is one item per author and tier and stays small', () {
    expect(bank.items().length, 40);
    expect(
      File('test/fixtures/quiz_bank_sample.json').lengthSync(),
      lessThan(50 * 1024),
    );
  });

  for (final item in bank.items()) {
    test('R-DIST-1/2: ${item.id} builds a valid question for seeds 0..9', () {
      final tier = QuizTier.ofLevel(item.tier)!;
      final itemWords = {
        for (final line in item.lines)
          for (final t in QuizText.tokenizeLine(line))
            QuizText.normalize(t.text),
      };
      for (var seed = 0; seed < 10; seed++) {
        final q = factory.create(item.id, tier, seed);
        expect(q, isNotNull, reason: '${item.id} seed $seed');
        expect(q!.options.length, 4);
        final answer = q.options[q.answerIndex];
        expect(QuizText.isContent(Token(answer), normStop), isTrue);
        final normalized = [for (final o in q.options) QuizText.normalize(o)];
        expect(normalized.toSet().length, 4, reason: 'duplicate option');
        for (var i = 0; i < 4; i++) {
          if (i == q.answerIndex) continue;
          expect(
            itemWords,
            isNot(contains(normalized[i])),
            reason: 'option from the item itself',
          );
        }
        expect(q.render().join(' '), contains(defaultBlankMarker));
        final shownWords = [
          for (final line in q.lines)
            for (final t in line) QuizText.normalize(t.text),
        ];
        expect(
          shownWords,
          isNot(contains(QuizText.normalize(answer))),
          reason: 'answer visible as a word',
        );
      }
    });
  }
}
