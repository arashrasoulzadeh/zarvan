import 'quiz_item.dart';
import 'quiz_text.dart';
import 'seeded_random.dart';

/// Where in an item the blank goes: line and token index within it.
class BlankPosition {
  const BlankPosition(this.line, this.token);

  final int line;
  final int token;
}

/// Chooses which word to hide. Any content word of the item can be hidden,
/// wherever it stands in the verse (first, middle or the rhyme word at the end
/// of a line); the tier no longer decides the position, only how close the
/// wrong options are (see `Distractors`).
abstract final class BlankPicker {
  /// The blank for [item] (the [tier] is accepted for the callers' sake but
  /// does not change where the blank goes), or null when the item cannot be
  /// asked (no usable content word). [stopWords] must be normalized
  /// ([QuizText.normalizeAll]).
  ///
  /// A word that appears more than once in the item (compared normalized) is
  /// skipped: a second gap would give the answer away.
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
    final all = <BlankPosition>[
      for (var l = 0; l < lines.length; l++)
        for (var k = 0; k < lines[l].length; k++)
          if (QuizText.isContent(lines[l][k], stopWords) &&
              counts[QuizText.normalize(lines[l][k].text)] == 1)
            BlankPosition(l, k),
    ];
    if (all.isEmpty) return null;
    return rng.pick(all);
  }
}
