import 'package:zarvan_core/zarvan_core_quiz.dart';

/// Distinct three-letter Persian words, so no two items share a word and a
/// question never lacks wrong options.
String word(int n) {
  const letters = 'ابتثجحخدذرزسشصضطظعغفقکگلمنهی';
  final b = letters.length;
  return letters[n % b] + letters[(n ~/ b) % b] + letters[(n ~/ (b * b)) % b];
}

QuizBank makeBank({int perTier = 12, List<String> authors = const ['a', 'b']}) {
  var w = 0;
  final items = <Map<String, dynamic>>[];
  for (final a in authors) {
    for (final t in QuizTier.values) {
      for (var i = 0; i < perTier; i++) {
        items.add({
          'id': '$a-${t.name}-${i.toString().padLeft(2, '0')}',
          'author': a,
          'tier': t.name,
          'fame': 100 - i,
          'lines': ['${word(w++)} ${word(w++)}', '${word(w++)} ${word(w++)}'],
        });
      }
    }
  }
  return QuizBank.fromJson({
    'version': 1,
    'authors': [
      for (final a in authors) {'id': a, 'name': a},
    ],
    'items': items,
  });
}

QuestionFactory factoryOf(QuizBank b) => QuestionFactory(b, const {});

/// Plays [round] to its end answering by [pick] and returns the questions.
List<Question> play(
  QuizRound round,
  bool Function(Question q, int index) pick, {
  int max = 500,
}) {
  final asked = <Question>[];
  while (!round.isOver && asked.length < max) {
    final q = round.nextQuestion();
    if (q == null) break;
    asked.add(q);
    final right = pick(q, asked.length - 1);
    round.answer(right ? q.answerIndex : (q.answerIndex + 1) % 4);
  }
  return asked;
}
