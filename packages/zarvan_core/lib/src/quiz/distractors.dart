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
    // Every tier's wrong options rhyme with the answer; the tier only decides
    // which rhymes come first (how close they are in length and author), and
    // length alone is a last resort when there are too few rhymes.
    final stages = switch (tier) {
      QuizTier.easy => [
        ctx.rhyme(3, ctx.differentLength),
        ctx.rhyme(2, ctx.differentLength),
        ctx.rhyme(3),
        ctx.rhyme(2),
        ctx.rhyme(1, ctx.differentLength),
        ctx.rhyme(1),
        ctx.only(ctx.differentLength),
        ctx.only(ctx.nearLength),
      ],
      QuizTier.medium => [
        ctx.rhyme(3, ctx.sameLength),
        ctx.rhyme(2, ctx.sameLength),
        ctx.rhyme(3, ctx.nearLength),
        ctx.rhyme(2, ctx.nearLength),
        ctx.rhyme(3),
        ctx.rhyme(2),
        ctx.rhyme(1, ctx.sameLength),
        ctx.rhyme(1),
        ctx.only(ctx.sameLength),
        ctx.only(ctx.nearLength),
      ],
      QuizTier.hard || QuizTier.literary => [
        ctx.rhyme(3, ctx.sameAuthor),
        ctx.rhyme(3),
        ctx.rhyme(2, ctx.sameAuthor),
        ctx.rhyme(2),
        ctx.rhyme(1, ctx.sameLength),
        ctx.rhyme(1),
        ctx.only(ctx.sameLength),
        ctx.only(ctx.nearLength),
      ],
    };
    final chosen = <WordEntry>[];
    for (final stage in stages) {
      if (chosen.length >= count) break;
      _fill(chosen, stage, count, rng);
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
}

class _Ctx {
  _Ctx(this.pool, String answerWord, this.author, this.index)
    : allowed = pool.toSet(),
      answer = answerWord,
      answerLength = answerWord.runes.length;

  final List<WordEntry> pool;

  /// [pool] as a set, so index queries can be filtered in one pass.
  final Set<WordEntry> allowed;
  final String answer;
  final String? author;
  final WordIndex index;
  final int answerLength;

  /// The last [k] letters of the answer, or fewer when the answer is short
  /// (never the whole word: a word sharing all of it is the answer itself).
  String _ending(int k) {
    final r = answer.runes.toList();
    final n = k < r.length ? k : r.length - 1;
    return n <= 0 ? '' : String.fromCharCodes(r.sublist(r.length - n));
  }

  /// Words ending with the answer's last [k] letters (a rhyme), optionally
  /// narrowed by [where] (length or author closeness).
  List<WordEntry> rhyme(int k, [bool Function(WordEntry)? where]) {
    final suffix = _ending(k);
    if (suffix.isEmpty) return const [];
    return [
      for (final e in pool)
        if (e.word.endsWith(suffix) && (where == null || where(e))) e,
    ];
  }

  /// The pool narrowed to the words [where] accepts.
  List<WordEntry> only(bool Function(WordEntry) where) => [
    for (final e in pool)
      if (where(e)) e,
  ];

  bool differentLength(WordEntry e) => (e.length - answerLength).abs() >= 2;
  bool nearLength(WordEntry e) => (e.length - answerLength).abs() <= 1;
  bool sameLength(WordEntry e) => e.length == answerLength;
  bool sameAuthor(WordEntry e) => author != null && e.authors.contains(author);
}
