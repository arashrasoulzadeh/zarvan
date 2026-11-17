import 'package:flutter/material.dart';
import 'package:zarvan_core/zarvan_core_quiz.dart';

import 'quiz_session.dart';

/// The poem with its blank. Text direction comes from the game (the engine
/// knows no language), defaulting to right-to-left for Persian text. Once the
/// question is answered the blank shows the right word.
class QuizQuestionCard extends StatelessWidget {
  const QuizQuestionCard({
    super.key,
    required this.session,
    this.textDirection = TextDirection.rtl,
    this.style,
  });

  final QuizSession session;
  final TextDirection textDirection;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      final q = session.question;
      if (q == null) return const SizedBox.shrink();
      final theme = Theme.of(context);
      final base = style ?? theme.textTheme.titleLarge;
      final answer = session.answered ? q.options[q.answerIndex] : null;
      return Directionality(
        textDirection: textDirection,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var l = 0; l < q.lines.length; l++)
                  Text.rich(
                    TextSpan(
                      children: [
                        for (var t = 0; t < q.lines[l].length; t++) ...[
                          if (t > 0) const TextSpan(text: ' '),
                          _token(q, l, t, answer, theme),
                        ],
                      ],
                    ),
                    key: ValueKey('line_$l'),
                    style: base,
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );

  TextSpan _token(Question q, int l, int t, String? answer, ThemeData theme) {
    final tok = q.lines[l][t];
    final isBlank = l == q.blankLine && t == q.blankToken;
    if (!isBlank) return TextSpan(text: tok.toString());
    return TextSpan(
      children: [
        TextSpan(text: tok.pre),
        TextSpan(
          text: answer ?? tok.text,
          style: answer == null
              ? null
              : TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
        ),
        TextSpan(text: tok.post),
      ],
    );
  }
}

/// The four options. Tapping one calls `session.answer`; afterwards the right
/// option takes the theme's primary colour and a wrong pick its error colour.
/// Options a hint removed are shown disabled.
class QuizOptions extends StatelessWidget {
  const QuizOptions({
    super.key,
    required this.session,
    this.textDirection = TextDirection.rtl,
  });

  final QuizSession session;
  final TextDirection textDirection;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      final q = session.question;
      if (q == null) return const SizedBox.shrink();
      final scheme = Theme.of(context).colorScheme;
      final picked = session.picked;
      return Directionality(
        textDirection: textDirection,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < q.options.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: FilledButton(
                  key: ValueKey('option_$i'),
                  style: picked == null
                      ? null
                      : FilledButton.styleFrom(
                          disabledBackgroundColor: i == q.answerIndex
                              ? scheme.primary
                              : i == picked
                              ? scheme.error
                              : null,
                          disabledForegroundColor: i == q.answerIndex
                              ? scheme.onPrimary
                              : i == picked
                              ? scheme.onError
                              : null,
                        ),
                  onPressed:
                      picked != null ||
                          q.removedByHint.contains(i) ||
                          session.paused
                      ? null
                      : () => session.answer(i),
                  child: Text(q.options[i]),
                ),
              ),
          ],
        ),
      );
    },
  );
}

/// What follows an answer: the whole poem with its author, and a Next
/// button. In a race there is no button (the next question comes by itself).
class QuizFeedback extends StatelessWidget {
  const QuizFeedback({
    super.key,
    required this.session,
    this.textDirection = TextDirection.rtl,
    this.nextLabel = 'Next',
  });

  final QuizSession session;
  final TextDirection textDirection;
  final String nextLabel;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      final q = session.question;
      final round = session.round;
      if (q == null || round == null || !session.answered) {
        return const SizedBox.shrink();
      }
      final item = round.bank.byId(q.itemId);
      final author = item?.author == null
          ? null
          : [
              for (final a in round.bank.authors)
                if (a.id == item!.author) a.name,
            ].firstOrNull;
      return Directionality(
        textDirection: textDirection,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (item != null)
              for (var i = 0; i < item.lines.length; i++)
                Text(
                  item.lines[i],
                  key: ValueKey('feedback_line_$i'),
                  textAlign: TextAlign.center,
                ),
            if (author != null)
              Text(
                author,
                key: const ValueKey('feedback_author'),
                textAlign: TextAlign.center,
              ),
            if (round.mode is! RaceMode)
              FilledButton(
                key: const ValueKey('next'),
                onPressed: session.next,
                child: Text(nextLabel),
              ),
          ],
        ),
      );
    },
  );
}

/// Score, streak, lives (or the race clock), coins and the hint button.
class QuizHud extends StatelessWidget {
  const QuizHud({super.key, required this.session, this.hintLabel = 'Hint'});

  final QuizSession session;
  final String hintLabel;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      final round = session.round;
      if (round == null) return const SizedBox.shrink();
      final run = round.run;
      final clock = run.clockMs;
      return Wrap(
        spacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('${run.score}', key: const ValueKey('hud_score')),
          Text('${run.streak}', key: const ValueKey('hud_streak')),
          if (run.lives != null)
            Text('${run.lives}', key: const ValueKey('hud_lives')),
          if (clock != null)
            Text('${(clock / 1000).ceil()}', key: const ValueKey('hud_clock')),
          Text('${session.progress.coins}', key: const ValueKey('hud_coins')),
          if (round.mode is! RaceMode)
            TextButton(
              key: const ValueKey('hint'),
              onPressed: session.canHint ? session.useHint : null,
              child: Text(hintLabel),
            ),
        ],
      );
    },
  );
}
