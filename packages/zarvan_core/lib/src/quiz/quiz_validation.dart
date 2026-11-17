import 'quiz_generator.dart';
import 'quiz_item.dart';

/// Problems in a quiz bank, each prefixed with the item it concerns.
///
/// Checks what would make generation fail or look wrong: duplicate ids,
/// empty items, items with no blankable word, items for which the tier's
/// rules cannot find enough distinct distractors, and (via [minPerTier])
/// tiers with too few items.
List<String> validateQuizBank(
  QuizGenerator generator, {
  Map<int, int> minPerTier = const {},
}) {
  final problems = <String>[];
  final ids = <String>{};
  final perTier = <int, int>{};
  for (final item in generator.bank) {
    perTier[item.tier] = (perTier[item.tier] ?? 0) + 1;
    if (!ids.add(item.id)) problems.add('${item.id}: duplicate id');
    if (item.lines.isEmpty || item.lines.every((l) => l.trim().isEmpty)) {
      problems.add('${item.id}: has no text');
      continue;
    }
    final rules = generator.rulesFor(item.tier);
    final blankable = [
      for (final l in item.lines) ...generator.blankableIndexes(l, rules),
    ];
    if (blankable.isEmpty) {
      problems.add('${item.id}: no blankable word');
    } else if (!_generatesAlways(generator, item)) {
      problems.add(
        '${item.id}: too few distinct distractors for tier ${item.tier}',
      );
    }
  }
  minPerTier.forEach((tier, min) {
    final have = perTier[tier] ?? 0;
    if (have < min) problems.add('tier $tier: has $have items, needs $min');
  });
  return problems;
}

/// Tries every blank position with a throwaway generator so the real one's
/// random sequence is untouched; one failing position is enough to flag.
bool _generatesAlways(QuizGenerator g, QuizItem item) {
  final probe = QuizGenerator(
    bank: g.bank,
    seed: 0,
    tierRules: g.tierRules,
    stopWords: g.stopWords,
    tokenize: g.tokenize,
  );
  for (var s = 0; s < 8; s++) {
    final p = QuizGenerator(
      bank: probe.bank,
      seed: s,
      tierRules: probe.tierRules,
      stopWords: probe.stopWords,
      tokenize: probe.tokenize,
    );
    if (p.generate(item) == null) return false;
  }
  return true;
}
