import 'dart:convert';

import '../../ecs/deterministic_random.dart';
import '../../quiz/quiz_generator.dart';
import '../../quiz/quiz_item.dart';
import '../../quiz/quiz_progress.dart';
import '../../quiz/quiz_question.dart';
import '../../quiz/quiz_rules.dart';
import '../../quiz/quiz_scoring.dart';
import '../../quiz/quiz_validation.dart';
import '../context.dart';
import '../operation.dart';
import '../param.dart';
import '../result.dart';

Map<String, dynamic> _object(
  OpContext ctx,
  Map<String, Object?> a,
  String jsonKey,
  String pathKey,
) {
  final inline = a[jsonKey];
  if (inline is Map) return inline.cast<String, dynamic>();
  final rel = a[pathKey] as String?;
  if (rel == null) {
    throw OpError(
      ErrorCode.invalidParams,
      'Give "$pathKey" (a project file) or "$jsonKey" (inline JSON).',
    );
  }
  if (ctx.project == null) {
    throw OpError(
      ErrorCode.notFound,
      'No project is open.',
      hint: 'Call project.open first.',
    );
  }
  final text = ctx.files.read(ctx.project!.resolve(rel));
  if (text == null) throw OpError(ErrorCode.notFound, 'No file at $rel.');
  try {
    return (jsonDecode(text) as Map).cast<String, dynamic>();
  } on Object catch (e) {
    throw OpError(
      ErrorCode.validationFailed,
      '$rel is not a JSON object ($e).',
    );
  }
}

/// A bank file is `{items: [...], tiers: {"1": {...}}, stopWords: [...]}`.
QuizGenerator _generator(Map<String, dynamic> bank, int seed) {
  try {
    return QuizGenerator(
      bank: [
        for (final i in (bank['items'] as List? ?? const []))
          QuizItem.fromJson((i as Map).cast<String, dynamic>()),
      ],
      seed: seed,
      tierRules: {
        for (final e in ((bank['tiers'] as Map?) ?? const {}).entries)
          int.parse(e.key as String): QuizTierRules.fromJson(
            (e.value as Map).cast<String, dynamic>(),
          ),
      },
      stopWords: {...((bank['stopWords'] as List?) ?? const []).cast<String>()},
    );
  } on Object catch (e) {
    throw OpError(ErrorCode.validationFailed, 'The bank is malformed ($e).');
  }
}

const _bankParams = [
  Param(
    'path',
    ParamType.path,
    positional: true,
    description: 'Bank file in the project.',
  ),
  Param(
    'json',
    ParamType.json,
    cliFlag: 'inline-json',
    description: 'The bank inline, instead of a file.',
  ),
];

/// `quiz.*`: the quiz-genre tools. Stateless: a run or a question travels
/// in and out as JSON, so an agent can play a quiz step by step.
List<Operation> quizOperations() => [
  Operation(
    name: 'quiz.generate',
    summary: 'Generate seeded fill-in-the-blank questions from a bank.',
    description:
        'Bank shape: `{items: [{id, lines, tier, author?}], tiers: {"1": {blank, distractors, optionCount}}, '
        'stopWords: []}`. Same bank, seed and arguments give the same questions. Items that cannot make a '
        'question are skipped and listed in `skipped`.',
    kind: OperationKind.read,
    scope: OperationScope.pure,
    idempotent: true,
    params: const [
      ..._bankParams,
      Param('seed', ParamType.integer, defaultValue: 1),
      Param('count', ParamType.integer, min: 1, max: 500, defaultValue: 10),
      Param(
        'tier',
        ParamType.integer,
        min: 1,
        description: 'Only items of this tier.',
      ),
    ],
    errors: {ErrorCode.validationFailed: 'The bank is malformed.'},
    handler: (ctx, a) {
      final g = _generator(
        _object(ctx, a, 'json', 'path'),
        (a['seed']! as num).toInt(),
      );
      final tier = (a['tier'] as num?)?.toInt();
      final pool = [
        for (final i in g.bank)
          if (tier == null || i.tier == tier) i,
      ];
      final order = [...pool];
      final rng = DeterministicRandom((a['seed']! as num).toInt() + 1);
      for (var i = order.length - 1; i > 0; i--) {
        final j = rng.nextInt(i + 1);
        final t = order[i];
        order[i] = order[j];
        order[j] = t;
      }
      final questions = <Map<String, dynamic>>[];
      final skipped = <String>[];
      for (final item in order) {
        if (questions.length >= (a['count']! as num).toInt()) break;
        final q = g.generate(item);
        if (q == null) {
          skipped.add(item.id);
        } else {
          questions.add(q.toJson());
        }
      }
      return OpOutcome.data({'questions': questions, 'skipped': skipped});
    },
    examples: const [
      Example('Two items', {
        'json': {
          'items': [
            {
              'id': 'a',
              'lines': ['one two three'],
            },
            {
              'id': 'b',
              'lines': ['four five six'],
            },
            {
              'id': 'c',
              'lines': ['seven eight nine'],
            },
            {
              'id': 'd',
              'lines': ['ten eleven twelve'],
            },
          ],
        },
        'count': 1,
      }),
    ],
  ),
  Operation(
    name: 'quiz.answer',
    summary: 'Apply one answer to a run and return the updated run and result.',
    description:
        'Give the `question` (from quiz.generate), the chosen option index and the current `run` (omit to start a '
        'fresh one with default rules). Returns the new `run` to pass to the next call.',
    kind: OperationKind.read,
    scope: OperationScope.pure,
    params: const [
      Param('question', ParamType.json, required: true),
      Param('option', ParamType.integer, required: true, min: 0),
      Param(
        'run',
        ParamType.json,
        description: 'Run state from a previous call.',
      ),
      Param('secondsLeft', ParamType.integer, min: 0, defaultValue: 0),
    ],
    handler: (ctx, a) {
      try {
        final q = QuizQuestion.fromJson(
          (a['question']! as Map).cast<String, dynamic>(),
        );
        final option = (a['option']! as num).toInt();
        if (option >= q.options.length) {
          throw OpError(
            ErrorCode.invalidParams,
            'option $option is out of range (0..${q.options.length - 1}).',
          );
        }
        final run = a['run'] is Map
            ? SimpleQuizRun.fromJson((a['run']! as Map).cast<String, dynamic>())
            : SimpleQuizRun(rules: const ScoreRules());
        final r = run.answer(
          q,
          option,
          secondsLeft: (a['secondsLeft']! as num).toInt(),
        );
        return OpOutcome.data({
          'correct': r.correct,
          'answer': q.answer,
          'pointsDelta': r.pointsDelta,
          'streak': r.streak,
          'livesLeft': r.livesLeft,
          'over': run.isOver,
          'run': run.toJson(),
        });
      } on OpError {
        rethrow;
      } on Object catch (e) {
        throw OpError(
          ErrorCode.validationFailed,
          'The question or run is malformed ($e).',
        );
      }
    },
    examples: const [
      Example(
        'Right answer',
        {
          'question': {
            'itemId': 'a',
            'tier': 1,
            'lines': ['one two ____'],
            'blankLine': 0,
            'answer': 'three',
            'options': ['three', 'four'],
            'correctIndex': 0,
          },
          'option': 0,
        },
        expect: {'correct': true},
      ),
    ],
  ),
  Operation(
    name: 'quiz.state',
    summary: 'Summarize a run and, optionally, saved progress.',
    description:
        'Reads `run` and `progress` JSON (as returned by quiz.answer and saved by the game); changes nothing.',
    kind: OperationKind.read,
    scope: OperationScope.pure,
    idempotent: true,
    params: const [
      Param('run', ParamType.json),
      Param('progress', ParamType.json),
    ],
    handler: (ctx, a) {
      if (a['run'] == null && a['progress'] == null) {
        throw OpError(
          ErrorCode.invalidParams,
          'Give "run", "progress" or both.',
        );
      }
      try {
        final out = <String, Object?>{};
        if (a['run'] is Map) {
          final run = SimpleQuizRun.fromJson(
            (a['run']! as Map).cast<String, dynamic>(),
          );
          out['run'] = {
            'score': run.score,
            'streak': run.streak,
            'multiplier': run.multiplier,
            'lives': run.lives,
            'answered': run.answered,
            'correct': run.correctCount,
            'over': run.isOver,
          };
        }
        if (a['progress'] is Map) {
          final p = QuizProgress.fromJson(
            (a['progress']! as Map).cast<String, dynamic>(),
          );
          out['progress'] = {
            'totalStars': p.totalStars,
            'unlocked': p.unlocked.toList()..sort(),
            'records': p.records,
            'currency': p.currency,
          };
        }
        return OpOutcome.data(out);
      } on Object catch (e) {
        throw OpError(
          ErrorCode.validationFailed,
          'The run or progress is malformed ($e).',
        );
      }
    },
  ),
  Operation(
    name: 'quiz.validate_bank',
    summary:
        'Check a quiz bank: blankable words, enough distractors, no duplicate ids, tier counts.',
    description:
        'Nothing is generated for play or written. `minPerTier` is an object like `{"1": 20}` requiring at least '
        'that many items in a tier.',
    kind: OperationKind.read,
    scope: OperationScope.pure,
    idempotent: true,
    params: const [..._bankParams, Param('minPerTier', ParamType.object)],
    handler: (ctx, a) {
      final bank = _object(ctx, a, 'json', 'path');
      final g = _generator(bank, 0);
      final min = <int, int>{
        for (final e in ((a['minPerTier'] as Map?) ?? const {}).entries)
          int.parse(e.key as String): (e.value as num).toInt(),
      };
      final problems = validateQuizBank(g, minPerTier: min);
      return OpOutcome.data({
        'ok': problems.isEmpty,
        'problems': problems,
        'items': g.bank.length,
      });
    },
    examples: const [
      Example(
        'Too small',
        {
          'json': {
            'items': [
              {
                'id': 'a',
                'lines': ['one two three'],
              },
            ],
          },
        },
        expect: {'ok': false},
      ),
    ],
  ),
];
