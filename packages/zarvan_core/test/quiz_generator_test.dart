import 'package:test/test.dart';
import 'package:zarvan_core/zarvan_core_quiz.dart';

QuizItem item(String id, String line, {int tier = 1, String? author}) =>
    QuizItem(id: id, lines: [line], tier: tier, author: author);

final bank = [
  item('a', 'alpha beta gamma', author: 'x'),
  item('b', 'one two three', author: 'x'),
  item('c', 'red green blue', author: 'y'),
  item('d', 'cat dog fish', author: 'y'),
  item('e', 'sun moon star', author: 'x'),
];

void main() {
  test('item and rules round-trip through JSON', () {
    final i = QuizItem(id: 'q', lines: const ['a b'], tier: 2, author: 'z', meta: const {'k': 'v'});
    expect(QuizItem.fromJson(i.toJson()).toJson(), i.toJson());
    const r = QuizTierRules(blank: BlankStrategy.randomContentWord, distractors: DistractorStrategy.sameRhyme, optionCount: 3);
    expect(QuizTierRules.fromJson(r.toJson()).toJson(), r.toJson());
  });

  test('last-word blank, correct option at correctIndex, no duplicate options', () {
    final q = QuizGenerator(bank: bank, seed: 1).generate(bank[0])!;
    expect(q.answer, 'gamma');
    expect(q.lines.single, 'alpha beta ____');
    expect(q.options.length, 4);
    expect(q.options.toSet().length, 4);
    expect(q.isCorrect(q.correctIndex), isTrue);
    expect(q.options[q.correctIndex], 'gamma');
    expect(QuizQuestion.fromJson(q.toJson()).toJson(), q.toJson());
  });

  test('same seed gives the same question', () {
    final a = QuizGenerator(bank: bank, seed: 7).generate(bank[1])!;
    final b = QuizGenerator(bank: bank, seed: 7).generate(bank[1])!;
    expect(a.toJson(), b.toJson());
  });

  test('stop words are never blanked', () {
    final g = QuizGenerator(
      bank: bank,
      seed: 3,
      stopWords: {'alpha', 'beta'},
      tierRules: {1: const QuizTierRules(blank: BlankStrategy.randomContentWord)},
    );
    for (var s = 0; s < 20; s++) {
      expect(g.generate(bank[0])!.answer, 'gamma');
    }
  });

  test('last-word blank yields nothing when the last word is a stop word', () {
    final g = QuizGenerator(bank: bank, seed: 1, stopWords: {'gamma'});
    expect(g.generate(bank[0]), isNull);
  });

  test('sameLength distractors share the answer length', () {
    final g = QuizGenerator(
      bank: bank,
      seed: 2,
      tierRules: {1: const QuizTierRules(distractors: DistractorStrategy.sameLength, optionCount: 3)},
    );
    final q = g.generate(bank[1])!;
    expect(q.answer, 'three');
    expect(q.options.every((o) => o.length == 5), isTrue);
  });

  test('sameRhyme distractors share the ending', () {
    final rhyme = [
      item('1', 'x night', tier: 1),
      item('2', 'y light'),
      item('3', 'z right'),
      item('4', 'w tree'),
    ];
    final g = QuizGenerator(
      bank: rhyme,
      seed: 5,
      tierRules: {1: const QuizTierRules(distractors: DistractorStrategy.sameRhyme, optionCount: 3, rhymeSuffixLength: 3)},
    );
    final q = g.generate(rhyme[0])!;
    expect(q.options.toSet(), {'night', 'light', 'right'});
  });

  test('sameAuthor distractors come only from that author', () {
    final g = QuizGenerator(
      bank: bank,
      seed: 4,
      tierRules: {1: const QuizTierRules(distractors: DistractorStrategy.sameAuthor, optionCount: 4)},
    );
    final q = g.generate(bank[0])!;
    const authorX = {'alpha', 'beta', 'gamma', 'one', 'two', 'three', 'sun', 'moon', 'star'};
    expect(q.options.every(authorX.contains), isTrue);
  });

  test('returns null when too few distractors exist', () {
    final g = QuizGenerator(
      bank: [bank[0]],
      seed: 1,
    );
    expect(g.generate(bank[0]), isNull);
  });

  test('custom tokenizer is used', () {
    final g = QuizGenerator(
      bank: [item('t', 'a,b,c'), item('u', 'd,e,f,g,h')],
      seed: 1,
      tokenize: (l) => l.split(','),
    );
    final q = g.generate(g.bank[0])!;
    expect(q.answer, 'c');
    expect(q.lines.single, 'a,b,____'.replaceAll(',', ' '));
  });
}
