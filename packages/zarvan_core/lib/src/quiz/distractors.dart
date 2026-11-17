import 'quiz_item.dart';
import 'quiz_text.dart';
import 'seeded_random.dart';
import 'word_index.dart';

/// The wrong options chosen for a question.
class DistractorResult {
  const DistractorResult(this.words, {required this.usedAnyFallback});

  /// The chosen words, in the order picked (the caller shuffles the options).
  final List<WordEntry> words;

  /// True when the last resort (any word of the bank) had to supply some of
  /// them; `validate_bank` counts these as warnings.
  final bool usedAnyFallback;
}

/// Picks the wrong options. Each tier is a chain of stages, tried in order,
/// and each stage only fills what the earlier ones left short; every stage is
/// one small function so the chain reads as the rule it implements.
abstract final class Distractors {
  /// Up to [count] wrong options for [answer] (the word as written in
  /// [item]). Never the answer, never a word of [item] itself, never two
  /// that normalize alike. Returns fewer than [count] only when the whole
  /// index has too few words.
  static DistractorResult pick({
    required QuizItem item,
    required String answer,
    required QuizTier tier,
    required WordIndex index,
    required SeededRandom rng,
    int count = 3,
  }) {
    final answerWord = QuizText.normalize(answer);
    final excluded = <String>{
      answerWord,
      for (final line in item.lines)
        for (final t in QuizText.tokenizeLine(line)) QuizText.normalize(t.text),
    };
    final pool = [
      for (final e in index.all)
        if (!excluded.contains(e.word)) e,
    ];
    final ctx = _Ctx(pool, answerWord, item.author, index);
    final stages = switch (tier) {
      QuizTier.easy => [_differentLength],
      QuizTier.medium => [_sameLength, _nearLength],
      QuizTier.hard || QuizTier.literary => [
        _sameAuthorRhyme,
        _bankRhyme,
        _sameLength,
        _nearLength,
      ],
    };
    final chosen = <WordEntry>[];
    for (final stage in stages) {
      if (chosen.length >= count) break;
      _fill(chosen, stage(ctx), count, rng);
    }
    var usedAny = false;
    if (chosen.length < count) {
      final before = chosen.length;
      _fill(chosen, pool, count, rng);
      usedAny = chosen.length > before;
    }
    return DistractorResult(chosen, usedAnyFallback: usedAny);
  }

  /// Adds shuffled [candidates] not yet in [chosen] until it holds [count].
  static void _fill(
    List<WordEntry> chosen,
    List<WordEntry> candidates,
    int count,
    SeededRandom rng,
  ) {
    final fresh = [
      for (final c in candidates)
        if (!chosen.contains(c)) c,
    ];
    rng.shuffle(fresh);
    for (final c in fresh) {
      if (chosen.length >= count) return;
      chosen.add(c);
    }
  }

  /// Easy: obviously out of place, so the length is clearly different.
  static List<WordEntry> _differentLength(_Ctx c) => [
    for (final e in c.pool)
      if ((e.length - c.answerLength).abs() >= 2) e,
  ];

  static List<WordEntry> _sameLength(_Ctx c) =>
      c.index.byLength(c.answerLength).where(c.allowed.contains).toList();

  static List<WordEntry> _nearLength(_Ctx c) => [
    for (final e in c.pool)
      if ((e.length - c.answerLength).abs() <= 1) e,
  ];

  static List<WordEntry> _bankRhyme(_Ctx c) =>
      c.index.byEnding(c.answerEnding).where(c.allowed.contains).toList();

  static List<WordEntry> _sameAuthorRhyme(_Ctx c) {
    final author = c.author;
    if (author == null) return const [];
    return c.index
        .byEnding(c.answerEnding, author: author)
        .where(c.allowed.contains)
        .toList();
  }
}

class _Ctx {
  _Ctx(this.pool, String answerWord, this.author, this.index)
    : allowed = pool.toSet(),
      answerLength = answerWord.runes.length,
      answerEnding = _ending(answerWord);

  final List<WordEntry> pool;

  /// [pool] as a set, so the index queries can be filtered in one pass.
  final Set<WordEntry> allowed;
  final String? author;
  final WordIndex index;
  final int answerLength;
  final String answerEnding;

  static String _ending(String w) {
    final r = w.runes.toList();
    return String.fromCharCodes(r.length <= 2 ? r : r.sublist(r.length - 2));
  }
}
