import 'package:zarvan_core/zarvan_core_quiz.dart';

/// Distinct three-letter Persian words, so no two items share a word.
String word(int n) {
  const letters = 'ابتثجحخدذرزسشصضطظعغفقکگلمنهی';
  final b = letters.length;
  return letters[n % b] + letters[(n ~/ b) % b] + letters[(n ~/ (b * b)) % b];
}

QuizBank makeBank({int perTier = 30}) {
  var w = 0;
  final items = <Map<String, dynamic>>[];
  for (final t in QuizTier.values) {
    for (var i = 0; i < perTier; i++) {
      items.add({
        'id': 'a-${t.name}-${i.toString().padLeft(2, '0')}',
        'author': 'a',
        'tier': t.name,
        'fame': 100 - i,
        'lines': ['${word(w++)} ${word(w++)}', '${word(w++)} ${word(w++)}'],
      });
    }
  }
  return QuizBank.fromJson({
    'version': 1,
    'authors': [
      {'id': 'a', 'name': 'شاعر'},
    ],
    'items': items,
  });
}

QuestionFactory factoryOf(QuizBank b) => QuestionFactory(b, const {});

/// A bank with several authors (a, b, c, ...), [perTier] items each per tier.
QuizBank makeMultiBank({int authors = 3, int perTier = 30}) {
  var w = 0;
  final items = <Map<String, dynamic>>[];
  final ids = [for (var i = 0; i < authors; i++) String.fromCharCode(97 + i)];
  for (final a in ids) {
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
      for (final a in ids) {'id': a, 'name': 'Poet $a'},
    ],
    'items': items,
  });
}
