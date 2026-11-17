import 'dart:math' show Random;

import '../ecs/deterministic_random.dart';
import 'quiz_item.dart';
import 'quiz_question.dart';
import 'quiz_rules.dart';

/// Builds [QuizQuestion]s from a bank of [QuizItem]s.
///
/// Language knowledge arrives as data: [tokenize] splits a line into words
/// and [stopWords] lists words never worth blanking, so the engine stays
/// language-neutral. Output depends only on the bank, rules and RNG seed.
class QuizGenerator {
  final List<QuizItem> bank;
  final Map<int, QuizTierRules> tierRules;
  final Set<String> stopWords;
  final List<String> Function(String line) tokenize;
  final DeterministicRandom random;

  QuizGenerator({
    required this.bank,
    required int seed,
    this.tierRules = const {},
    this.stopWords = const {},
    this.tokenize = splitOnWhitespace,
  }) : random = DeterministicRandom(seed);

  /// Default tokenizer: splits on runs of whitespace.
  static List<String> splitOnWhitespace(String line) =>
      line.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

  QuizTierRules rulesFor(int tier) => tierRules[tier] ?? const QuizTierRules();

  /// Words of [line] that may be blanked under [rules].
  List<int> blankableIndexes(String line, QuizTierRules rules) {
    final words = tokenize(line);
    if (words.isEmpty) return const [];
    if (rules.blank == BlankStrategy.lastWord) {
      return stopWords.contains(words.last) ? const [] : [words.length - 1];
    }
    return [
      for (var i = 0; i < words.length; i++)
        if (!stopWords.contains(words[i])) i,
    ];
  }

  /// Generates a question for [item], or null when no line has a blankable
  /// word or too few distinct distractors exist for the tier.
  QuizQuestion? generate(QuizItem item) {
    final rules = rulesFor(item.tier);
    final candidates = <(int, int)>[
      for (var l = 0; l < item.lines.length; l++)
        for (final w in blankableIndexes(item.lines[l], rules)) (l, w),
    ];
    if (candidates.isEmpty) return null;
    final (lineIndex, wordIndex) = candidates[random.nextInt(candidates.length)];
    final words = tokenize(item.lines[lineIndex]);
    final answer = words[wordIndex];

    final pool = _distractorPool(item, answer, rules);
    final needed = rules.optionCount - 1;
    if (pool.length < needed) return null;
    pool.shuffle(_Shuffler(random));
    final options = [answer, ...pool.take(needed)]..shuffle(_Shuffler(random));

    final blanked = [...words]..[wordIndex] = QuizQuestion.blankMarker;
    final lines = [...item.lines]..[lineIndex] = blanked.join(' ');
    return QuizQuestion(
      itemId: item.id,
      tier: item.tier,
      lines: lines,
      blankLine: lineIndex,
      answer: answer,
      options: options,
      correctIndex: options.indexOf(answer),
    );
  }

  List<String> _distractorPool(QuizItem item, String answer, QuizTierRules rules) {
    final source = rules.distractors == DistractorStrategy.sameAuthor
        ? bank.where((i) => i.author != null && i.author == item.author)
        : bank;
    final seen = <String>{answer};
    final pool = <String>[];
    for (final other in source) {
      if (other.id == item.id) continue;
      for (final line in other.lines) {
        for (final word in tokenize(line)) {
          if (stopWords.contains(word) || !seen.add(word)) continue;
          if (_matches(word, answer, rules)) pool.add(word);
        }
      }
    }
    return pool;
  }

  bool _matches(String word, String answer, QuizTierRules rules) {
    switch (rules.distractors) {
      case DistractorStrategy.unrelated:
      case DistractorStrategy.sameAuthor:
        return true;
      case DistractorStrategy.sameLength:
        return word.length == answer.length;
      case DistractorStrategy.sameRhyme:
        final n = rules.rhymeSuffixLength;
        return word.length >= n &&
            answer.length >= n &&
            word.substring(word.length - n) == answer.substring(answer.length - n);
    }
  }
}

/// Adapts [DeterministicRandom] to `List.shuffle`, which wants a `Random`.
class _Shuffler implements Random {
  final DeterministicRandom _r;
  _Shuffler(this._r);
  @override
  int nextInt(int max) => _r.nextInt(max);
  @override
  double nextDouble() => _r.nextDouble();
  @override
  bool nextBool() => _r.nextBool();
}
