import 'quiz_item.dart';
import 'quiz_text.dart';
import 'seeded_random.dart';

/// Where in an item the blank goes: line and token index within it.
class BlankPosition {
  const BlankPosition(this.line, this.token);

  final int line;
  final int token;
}

/// Chooses which word to hide. Difficulty comes partly from here: the easy
/// tier asks for the rhyme word, which is easiest to guess, and the others
/// for words from the middle of a line.
abstract final class BlankPicker {
  /// The blank for [item] at [tier], or null when the item cannot be asked
  /// (no usable content word). [stopWords] must be normalized
  /// ([QuizText.normalizeAll]).
  ///
  /// A word that appears more than once in the item (compared normalized) is
  /// skipped: a second gap would give the answer away. When the tier's set is
  /// empty the pick falls back to every usable word.
  static BlankPosition? pick(
    QuizItem item,
    QuizTier tier,
    SeededRandom rng,
    Set<String> stopWords,
  ) {
    final lines = [for (final l in item.lines) QuizText.tokenizeLine(l)];
    final counts = <String, int>{};
    for (final tokens in lines) {
      for (final t in tokens) {
        final n = QuizText.normalize(t.text);
        counts[n] = (counts[n] ?? 0) + 1;
      }
    }
    bool usable(int l, int k) {
      final t = lines[l][k];
      return QuizText.isContent(t, stopWords) &&
          counts[QuizText.normalize(t.text)] == 1;
    }

    final all = <BlankPosition>[
      for (var l = 0; l < lines.length; l++)
        for (var k = 0; k < lines[l].length; k++)
          if (usable(l, k)) BlankPosition(l, k),
    ];
    final tierSet = switch (tier) {
      QuizTier.easy => _lineFinal(lines, usable),
      QuizTier.medium => [
        for (final p in all)
          if (p.token != lines[p.line].length - 1) p,
      ],
      QuizTier.hard || QuizTier.literary => all,
    };
    final candidates = tierSet.isNotEmpty ? tierSet : all;
    if (candidates.isEmpty) return null;
    return rng.pick(candidates);
  }

  /// The last content word of each line, among words that pass [usable].
  static List<BlankPosition> _lineFinal(
    List<List<Token>> lines,
    bool Function(int line, int token) usable,
  ) {
    final out = <BlankPosition>[];
    for (var l = 0; l < lines.length; l++) {
      for (var k = lines[l].length - 1; k >= 0; k--) {
        if (usable(l, k)) {
          out.add(BlankPosition(l, k));
          break;
        }
      }
    }
    return out;
  }
}
