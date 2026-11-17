import 'package:test/test.dart';
import 'package:zarvan_core/zarvan_core_quiz.dart';

QuizBank bank() => QuizBank.fromJson({
  'version': 1,
  'authors': [
    {'id': 'a', 'name': 'A'},
    {'id': 'b', 'name': 'B'},
  ],
  'items': [
    {
      'id': 'a1',
      'author': 'a',
      'tier': 'easy',
      'fame': 1,
      'lines': ['عشق و دل', 'که عشق «نور»'],
    },
    {
      'id': 'b1',
      'author': 'b',
      'tier': 'easy',
      'fame': 1,
      'lines': ['عشق بلبل', 'دل كه نور'],
    },
  ],
});

void main() {
  test(
    'R-DIST: each content word appears once, stop words and short words skipped',
    () {
      final idx = WordIndex.build(bank(), {'كه', 'و'});
      expect({for (final e in idx.all) e.word}, {'عشق', 'دل', 'نور', 'بلبل'});
      expect(idx.all.length, 4);
    },
  );

  test('authors accumulate across items; display keeps the first spelling', () {
    final idx = WordIndex.build(bank(), {'که'});
    final nur = idx.all.firstWhere((e) => e.word == 'نور');
    expect(nur.authors, {'a', 'b'});
    expect(nur.display, 'نور');
    final ishq = idx.all.firstWhere((e) => e.word == 'عشق');
    expect(ishq.authors, {'a', 'b'});
    final bulbul = idx.all.firstWhere((e) => e.word == 'بلبل');
    expect(bulbul.authors, {'b'});
  });

  test('byLength and byEnding answer from the index', () {
    final idx = WordIndex.build(bank(), {'که'});
    expect({for (final e in idx.byLength(3)) e.word}, {'عشق', 'نور'});
    expect(idx.byLength(9), isEmpty);
    expect({for (final e in idx.byEnding('ور')) e.word}, {'نور'});
    expect({for (final e in idx.byEnding('بل')) e.word}, {'بلبل'});
    expect({for (final e in idx.byEnding('شق', author: 'a')) e.word}, {'عشق'});
    expect(idx.byEnding('بل', author: 'a'), isEmpty);
  });

  test('order follows first appearance so results are reproducible', () {
    final a = WordIndex.build(bank(), {'که'}).all.map((e) => e.word).toList();
    final b = WordIndex.build(bank(), {'که'}).all.map((e) => e.word).toList();
    expect(a, b);
    expect(a.first, 'عشق');
  });
}
