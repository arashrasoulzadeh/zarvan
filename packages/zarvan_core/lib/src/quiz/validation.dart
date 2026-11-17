import 'blank_picker.dart';
import 'distractors.dart';
import 'quiz_bank.dart';
import 'quiz_item.dart';
import 'quiz_text.dart';
import 'seeded_random.dart';
import 'word_index.dart';

/// What [validateBank] found: problems are reported, never thrown, so a tool
/// can show them all at once.
class BankReport {
  const BankReport({
    required this.errors,
    required this.warnings,
    required this.stats,
  });

  /// Things that make the bank unusable (R-VAL-1, R-VAL-2).
  final List<String> errors;

  /// Things worth fixing that still work (R-VAL-3, R-VAL-4).
  final List<String> warnings;

  /// Item counts: `items`, and `byAuthorTier` as author -> tier -> count.
  final Map<String, Object?> stats;

  bool get ok => errors.isEmpty;

  Map<String, dynamic> toJson() => {
    'ok': ok,
    'errors': errors,
    'warnings': warnings,
    'stats': stats,
  };
}

/// Checks a bank given as raw JSON (so a broken one can be described rather
/// than refused) against [stopWords] (raw words).
///
/// R-VAL-1: duplicate id, empty lines, invalid tier, unknown version.
/// R-VAL-2: an item with no content word to hide.
/// R-VAL-3: an item whose tier needs the any-word fallback for wrong options
/// (or cannot get three), over sample seeds 0..9.
/// R-VAL-4: counts per author and tier; a warning when one has fewer than
/// [stageSize] items.
BankReport validateBank(
  Map<String, dynamic> json,
  Set<String> stopWords, {
  int stageSize = 25,
  int sampleSeeds = 10,
}) {
  final errors = <String>[];
  final warnings = <String>[];
  if (json['version'] != QuizBank.supportedVersion) {
    errors.add(
      'version ${json['version']} is not supported (expected ${QuizBank.supportedVersion})',
    );
    return BankReport(errors: errors, warnings: warnings, stats: const {});
  }
  final authorIds = {
    for (final a in (json['authors'] as List? ?? const []))
      (a as Map)['id'] as String,
  };
  final seen = <String>{};
  final good = <QuizItem>[];
  final rawItems = json['items'] as List? ?? const [];
  for (var i = 0; i < rawItems.length; i++) {
    final raw = (rawItems[i] as Map).cast<String, dynamic>();
    final id = '${raw['id']}';
    var broken = false;
    if (!seen.add(id)) {
      errors.add('$id: duplicate id (item #${i + 1})');
      broken = true;
    }
    final lines = raw['lines'];
    if (lines is! List ||
        lines.isEmpty ||
        lines.every((l) => '$l'.trim().isEmpty)) {
      errors.add('$id: empty lines (item #${i + 1})');
      broken = true;
    }
    QuizItem? item;
    try {
      item = QuizItem.fromJson(raw);
    } on Object catch (e) {
      final msg = e is FormatException ? e.message : '$e';
      errors.add('$id: $msg (item #${i + 1})');
      broken = true;
    }
    if (item != null &&
        item.author != null &&
        authorIds.isNotEmpty &&
        !authorIds.contains(item.author)) {
      errors.add('$id: author "${item.author}" is not in the authors list');
      broken = true;
    }
    if (!broken && item != null) good.add(item);
  }

  final counts = <String, Map<String, int>>{};
  for (final item in good) {
    final tier = QuizTier.ofLevel(item.tier)?.name ?? '${item.tier}';
    final byTier = counts.putIfAbsent(item.author ?? '', () => {});
    byTier[tier] = (byTier[tier] ?? 0) + 1;
  }
  for (final a in counts.entries) {
    for (final t in QuizTier.values) {
      final n = a.value[t.name] ?? 0;
      if (n < stageSize) {
        warnings.add('${a.key}/${t.name}: $n items, a stage needs $stageSize');
      }
    }
  }

  final bank = QuizBank(
    authors: [for (final a in authorIds) QuizAuthor(id: a, name: a)],
    items: good,
  );
  final normStop = QuizText.normalizeAll(stopWords);
  final index = WordIndex.build(bank, stopWords);
  for (final item in good) {
    final tier = QuizTier.ofLevel(item.tier);
    if (tier == null) continue;
    if (BlankPicker.pick(item, tier, SeededRandom(0), normStop) == null) {
      errors.add('${item.id}: no content word to hide');
      continue;
    }
    var fallback = 0;
    var short = 0;
    for (var s = 0; s < sampleSeeds; s++) {
      final rng = SeededRandom(s);
      final blank = BlankPicker.pick(item, tier, rng, normStop)!;
      final tokens = QuizText.tokenizeLine(item.lines[blank.line]);
      final r = Distractors.pick(
        item: item,
        answer: tokens[blank.token].text,
        tier: tier,
        index: index,
        rng: rng,
      );
      if (r.words.length < 3) short++;
      if (r.usedAnyFallback) fallback++;
    }
    if (short > 0) {
      warnings.add(
        '${item.id}: fewer than 3 wrong options in $short of $sampleSeeds samples',
      );
    } else if (fallback > 0) {
      warnings.add(
        '${item.id}: wrong options fall back to any word in $fallback of $sampleSeeds samples',
      );
    }
  }
  return BankReport(
    errors: errors,
    warnings: warnings,
    stats: {'items': good.length, 'byAuthorTier': counts},
  );
}
