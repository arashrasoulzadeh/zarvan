import 'dart:convert';

import '../../quiz/game_mode.dart';
import '../../quiz/question.dart';
import '../../quiz/quiz_bank.dart';
import '../../quiz/quiz_item.dart';
import '../../quiz/round.dart';
import '../../quiz/run.dart';
import '../../quiz/simulate.dart';
import '../../quiz/validation.dart';
import '../context.dart';
import '../operation.dart';
import '../param.dart';
import '../result.dart';

Map<String, dynamic> _readJsonFile(OpContext ctx, String rel) {
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

Map<String, dynamic> _bankJson(OpContext ctx, Map<String, Object?> a) {
  final inline = a['json'];
  if (inline is Map) return inline.cast<String, dynamic>();
  final rel = a['bank'] as String?;
  if (rel == null) {
    throw OpError(
      ErrorCode.invalidParams,
      'Give "bank" (a project file) or "json" (the bank inline).',
    );
  }
  return _readJsonFile(ctx, rel);
}

/// Stop words from `stopwords` (a file shaped `{"words": [...]}`) and/or
/// the inline `stopWords` list; none is fine (the engine has no default).
Set<String> _stopWords(OpContext ctx, Map<String, Object?> a) {
  final words = <String>{};
  final rel = a['stopwords'] as String?;
  if (rel != null) {
    words.addAll(
      ((_readJsonFile(ctx, rel)['words'] as List?) ?? const []).cast<String>(),
    );
  }
  final inline = a['stopWords'];
  if (inline is List) words.addAll(inline.cast<String>());
  return words;
}

QuestionFactory _factory(OpContext ctx, Map<String, Object?> a) {
  final QuizBank bank;
  try {
    bank = QuizBank.fromJson(_bankJson(ctx, a));
  } on FormatException catch (e) {
    throw OpError(
      ErrorCode.validationFailed,
      'The bank is not valid: ${e.message}',
    );
  }
  return QuestionFactory(bank, _stopWords(ctx, a));
}

/// `mode` is a name (`"stage"`) for the defaults or an object
/// (`{"type": "endless", "lives": 5}`).
GameMode _mode(Map<String, Object?> a) {
  final m = a['mode'];
  try {
    if (m is String) return GameMode.fromJson({'type': m});
    if (m is Map) return GameMode.fromJson(m.cast<String, dynamic>());
  } on FormatException catch (e) {
    throw OpError(ErrorCode.invalidParams, e.message);
  }
  throw OpError(
    ErrorCode.invalidParams,
    'Give "mode": stage, endless, race, daily or a mode object.',
  );
}

QuizTier _tier(Object? v, {QuizTier fallback = QuizTier.easy}) {
  if (v == null) return fallback;
  return QuizTier.byName('$v') ??
      (throw OpError(
        ErrorCode.invalidParams,
        'Unknown tier "$v" (easy, medium, hard or literary).',
      ));
}

/// A new round for the mode and the start parameters.
QuizRound _start(QuestionFactory f, GameMode mode, Map<String, Object?> a) {
  switch (mode) {
    case StageMode():
      final author =
          (a['author'] as String?) ??
          (f.bank.authors.isNotEmpty ? f.bank.authors.first.id : null);
      if (author == null) {
        throw OpError(
          ErrorCode.invalidParams,
          'A stage needs "author" (the bank lists none).',
        );
      }
      return QuizRound.stage(
        f,
        mode,
        author: author,
        tier: _tier(a['tier']),
        attempt: (a['attempt'] as num?)?.toInt() ?? 1,
      );
    case EndlessMode():
      return QuizRound.endless(
        f,
        mode,
        seedBase: (a['seedBase'] as String?) ?? 'endless:1',
      );
    case RaceMode():
      return QuizRound.race(
        f,
        mode,
        seedBase: (a['seedBase'] as String?) ?? 'race:1',
      );
    case DailyMode():
      final date = a['date'] as String?;
      if (date == null)
        throw OpError(
          ErrorCode.invalidParams,
          'A daily needs "date" (YYYY-MM-DD).',
        );
      try {
        return QuizRound.daily(f, mode, date: date);
      } on ArgumentError catch (e) {
        throw OpError(ErrorCode.invalidParams, '${e.message}');
      }
  }
}

QuizRound _resume(QuestionFactory f, GameMode mode, Map<String, Object?> a) {
  final raw = a['run'];
  if (raw is! Map)
    throw OpError(ErrorCode.invalidParams, 'Give "run" (the run JSON).');
  try {
    return QuizRound.resume(
      f,
      mode,
      QuizRun.fromJson(raw.cast<String, dynamic>()),
    );
  } on FormatException catch (e) {
    throw OpError(
      ErrorCode.validationFailed,
      'The run does not fit: ${e.message}',
    );
  }
}

Map<String, Object?> _summary(QuizRound r) => {
  'score': r.run.score,
  'streak': r.run.streak,
  'lives': r.run.lives,
  'clockMs': r.run.clockMs,
  'answered': r.run.index,
  'correct': r.correctCount,
  'over': r.isOver,
  'stars': r.stars,
  'passed': r.passed,
};

const _bankParams = [
  Param(
    'bank',
    ParamType.path,
    description: 'The bank file in the project (bank.json).',
  ),
  Param(
    'json',
    ParamType.json,
    cliFlag: 'inline-json',
    description: 'The bank inline, instead of a file.',
  ),
  Param(
    'stopwords',
    ParamType.path,
    description: 'Stop-word file (`{"words": [...]}`).',
  ),
  Param(
    'stopWords',
    ParamType.array,
    items: Param.string(),
    cliFlag: 'stop-word',
    description: 'Stop words inline.',
  ),
];

const _modeParam = Param(
  'mode',
  ParamType.json,
  required: true,
  description:
      'stage, endless, race, daily, or a mode object such as {"type": "endless", "lives": 5}.',
);

const _startParams = [
  Param(
    'author',
    ParamType.string,
    description: 'Stage: the chapter (default: the first author).',
  ),
  Param(
    'tier',
    ParamType.enumeration,
    options: ['easy', 'medium', 'hard', 'literary'],
    description: 'Stage: the tier (default easy).',
  ),
  Param(
    'attempt',
    ParamType.integer,
    min: 1,
    description: 'Stage: attempt number; it changes which word is hidden.',
  ),
  Param(
    'date',
    ParamType.string,
    description: 'Daily: the local date, YYYY-MM-DD.',
  ),
  Param(
    'seedBase',
    ParamType.string,
    description: 'Endless and race: text the question seeds come from.',
  ),
];

/// `quiz.*`: the quiz-genre tools. Stateless: a run travels in and out as
/// JSON, so an agent can play or simulate a round step by step.
List<Operation> quizOperations() => [
  Operation(
    name: 'quiz.validate_bank',
    summary:
        'Check a quiz bank: ids, tiers, blankable words, wrong-option supply, stage sizes.',
    description:
        'Reports (never throws) `errors` that make the bank unusable (duplicate id, empty lines, invalid tier, '
        'an item with no word to hide) and `warnings` (an item whose wrong options need the any-word fallback; an '
        'author and tier with fewer items than a stage needs), plus counts per author and tier. `ok` is false when '
        'there are errors, so the command exits 1.',
    kind: OperationKind.read,
    scope: OperationScope.pure,
    idempotent: true,
    params: const [
      ..._bankParams,
      Param(
        'stageSize',
        ParamType.integer,
        min: 1,
        defaultValue: 25,
        description: 'Items a stage needs.',
      ),
    ],
    handler: (ctx, a) {
      final report = validateBank(
        _bankJson(ctx, a),
        _stopWords(ctx, a),
        stageSize: (a['stageSize']! as num).toInt(),
      );
      return OpOutcome.data(report.toJson());
    },
    examples: const [
      Example('One small item', {
        'json': {
          'version': 1,
          'authors': [
            {'id': 'a', 'name': 'A'},
          ],
          'items': [
            {
              'id': 'x',
              'author': 'a',
              'tier': 'easy',
              'fame': 1,
              'lines': ['الف بب', 'جج دد'],
            },
          ],
        },
      }),
    ],
  ),
  Operation(
    name: 'quiz.generate',
    summary: 'Make the question a player would see for an item, tier and seed.',
    description:
        'Same as the game: the same bank, stop words, item, tier and seed always give the same `Question`. `tier` '
        'defaults to the item\'s own tier.',
    kind: OperationKind.read,
    scope: OperationScope.pure,
    idempotent: true,
    params: const [
      ..._bankParams,
      Param('itemId', ParamType.string, required: true),
      Param(
        'tier',
        ParamType.enumeration,
        options: ['easy', 'medium', 'hard', 'literary'],
      ),
      Param('seed', ParamType.integer, defaultValue: 0),
    ],
    errors: {
      ErrorCode.notFound: 'The item is not in the bank.',
      ErrorCode.validationFailed:
          'The bank is invalid, or the item cannot make a question.',
    },
    handler: (ctx, a) {
      final f = _factory(ctx, a);
      final id = a['itemId']! as String;
      final item = f.bank.byId(id);
      if (item == null)
        throw OpError(ErrorCode.notFound, 'No item "$id" in the bank.');
      final tier = _tier(
        a['tier'],
        fallback: QuizTier.ofLevel(item.tier) ?? QuizTier.easy,
      );
      try {
        final q = f.create(id, tier, (a['seed']! as num).toInt());
        if (q == null) {
          throw OpError(
            ErrorCode.validationFailed,
            'Item "$id" has no word that can be hidden.',
          );
        }
        return OpOutcome.data(q.toJson());
      } on StateError catch (e) {
        throw OpError(ErrorCode.validationFailed, e.message);
      }
    },
  ),
  Operation(
    name: 'quiz.start',
    summary:
        'Start a round in a mode and return the run with its first question.',
    description:
        'The run is plain JSON (`QuizRun`): keep it and pass it to quiz.answer. Stage needs `author` and `tier`, '
        'daily needs `date`, endless and race may take a `seedBase`.',
    kind: OperationKind.read,
    scope: OperationScope.pure,
    idempotent: true,
    params: const [..._bankParams, _modeParam, ..._startParams],
    errors: {
      ErrorCode.invalidParams:
          'A parameter the mode needs is missing or wrong.',
    },
    handler: (ctx, a) {
      final f = _factory(ctx, a);
      final round = _start(f, _mode(a), a);
      round.nextQuestion();
      return OpOutcome.data({
        'run': round.run.toJson(),
        'summary': _summary(round),
      });
    },
  ),
  Operation(
    name: 'quiz.answer',
    summary:
        'Answer the current question; get the new run, the result and the next question.',
    description:
        'Give the same bank and mode as quiz.start and the `run` it returned. With `hint` the hint is taken first '
        '(once per question; not in a race). The returned run already holds the next question unless the round '
        'is over.',
    kind: OperationKind.read,
    scope: OperationScope.pure,
    params: const [
      ..._bankParams,
      _modeParam,
      Param('run', ParamType.json, required: true),
      Param('choice', ParamType.integer, required: true, min: 0, max: 3),
      Param('hint', ParamType.boolean, defaultValue: false),
    ],
    errors: {
      ErrorCode.invalidParams:
          'The option does not exist or was removed by the hint.',
      ErrorCode.conflict: 'The round is over, or no question is waiting.',
    },
    handler: (ctx, a) {
      final f = _factory(ctx, a);
      final round = _resume(f, _mode(a), a);
      try {
        if (a['hint'] == true &&
            round.run.current?.removedByHint.isEmpty == true) {
          round.useHint();
        }
        final r = round.answer((a['choice']! as num).toInt());
        round.nextQuestion();
        return OpOutcome.data({
          'run': round.run.toJson(),
          'result': {
            'correct': r.correct,
            'points': r.points,
            'streak': r.streak,
            'livesLeft': r.livesLeft,
            'over': r.over,
          },
          'summary': _summary(round),
        });
      } on StateError catch (e) {
        throw OpError(ErrorCode.conflict, e.message);
      } on ArgumentError catch (e) {
        throw OpError(ErrorCode.invalidParams, '${e.message}');
      }
    },
  ),
  Operation(
    name: 'quiz.state',
    summary:
        'Summarize a run: score, streak, lives, clock, stars, and whether it is over.',
    description: 'Reads the bank, mode and run; changes nothing.',
    kind: OperationKind.read,
    scope: OperationScope.pure,
    idempotent: true,
    params: const [
      ..._bankParams,
      _modeParam,
      Param('run', ParamType.json, required: true),
    ],
    handler: (ctx, a) {
      final round = _resume(_factory(ctx, a), _mode(a), a);
      return OpOutcome.data(_summary(round));
    },
  ),
  Operation(
    name: 'quiz.simulate',
    summary:
        'Play many rounds with a fixed policy and report the score, stars and pass rate.',
    description:
        '`policy` is `always_correct`, `random` (uniform over the options) or `accuracy:<p>`. Round r of a stage is '
        'attempt r+1; endless and race use `<seedBase>:<r>`; daily uses `date` plus r days. In a race each question '
        'advances the clock by `secondsPerQuestion`. Same inputs, same report. Use it to tune difficulty and the '
        'coin economy without playing.',
    kind: OperationKind.read,
    scope: OperationScope.pure,
    idempotent: true,
    params: const [
      ..._bankParams,
      _modeParam,
      ..._startParams,
      Param('policy', ParamType.string, defaultValue: 'always_correct'),
      Param('runs', ParamType.integer, min: 1, max: 10000, defaultValue: 100),
      Param('seed', ParamType.integer, defaultValue: 1),
      Param('secondsPerQuestion', ParamType.integer, min: 0, defaultValue: 4),
    ],
    handler: (ctx, a) {
      final f = _factory(ctx, a);
      final mode = _mode(a);
      final AnswerPolicy policy;
      try {
        policy = AnswerPolicy.parse(a['policy']! as String);
      } on FormatException catch (e) {
        throw OpError(ErrorCode.invalidParams, e.message);
      }
      final seed = (a['seed']! as num).toInt();
      QuizRound build(int r) {
        final args = {...a};
        switch (mode) {
          case StageMode():
            args['attempt'] = r + 1;
          case EndlessMode() || RaceMode():
            args['seedBase'] = '${a['seedBase'] ?? mode.type}:$r';
          case DailyMode():
            final base = DateTime.tryParse('${a['date']}');
            if (base != null) {
              final d = DateTime.utc(base.year, base.month, base.day + r);
              args['date'] =
                  '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
            }
        }
        return _start(f, mode, args);
      }

      build(0); // surface a bad parameter as an error, not mid-simulation
      final report = simulateRounds(
        newRound: build,
        policy: policy,
        runs: (a['runs']! as num).toInt(),
        seed: seed,
        secondsPerQuestion: (a['secondsPerQuestion']! as num).toInt(),
      );
      return OpOutcome.data(report.toJson());
    },
  ),
];
