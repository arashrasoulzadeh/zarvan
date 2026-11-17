import 'package:flutter/material.dart';
import 'package:zarvan_core/zarvan_core_quiz.dart';

import 'quiz_controller.dart';

/// The question lines with the blank marker. [textDirection] is chosen by
/// the game (the engine knows no language), so RTL text lays out right.
class QuestionCard extends StatelessWidget {
  const QuestionCard({super.key, required this.question, this.textDirection = TextDirection.ltr, this.style});

  final QuizQuestion question;
  final TextDirection textDirection;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: textDirection,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final l in question.lines) Text(l, style: style ?? Theme.of(context).textTheme.titleLarge)],
        ),
      ),
    ),
  );
}

/// The answer options. After an answer the right one turns green and a
/// wrong pick red; options a hint removed are not shown.
class OptionButtons extends StatelessWidget {
  const OptionButtons({super.key, required this.controller, this.textDirection = TextDirection.ltr});

  final QuizController controller;
  final TextDirection textDirection;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final q = controller.question;
      if (q == null) return const SizedBox.shrink();
      final picked = controller.picked;
      return Directionality(
        textDirection: textDirection,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < q.options.length; i++)
              if (!controller.hidden.contains(i))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: FilledButton(
                    key: ValueKey('option_$i'),
                    style: picked == null
                        ? null
                        : FilledButton.styleFrom(
                            backgroundColor: i == q.correctIndex
                                ? Colors.green
                                : (i == picked ? Colors.red : Colors.grey),
                          ),
                    onPressed: picked == null ? () => controller.answer(i) : null,
                    child: Text(q.options[i]),
                  ),
                ),
          ],
        ),
      );
    },
  );
}

/// Score, streak, lives, countdown (timed race) and optional currency.
class QuizHud extends StatelessWidget {
  const QuizHud({super.key, required this.controller, this.currency});

  final QuizController controller;

  /// The player's balance, shown when given.
  final int? currency;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final run = controller.run;
      return Wrap(
        spacing: 16,
        children: [
          Text('Score ${run.score}', key: const ValueKey('hud_score')),
          Text('Streak ${run.streak}', key: const ValueKey('hud_streak')),
          Text('Lives ${run.lives}', key: const ValueKey('hud_lives')),
          if (controller.mode.kind == QuizModeKind.timedRace)
            Text('Time ${controller.secondsLeft}', key: const ValueKey('hud_time')),
          if (currency != null) Text('Coins $currency', key: const ValueKey('hud_currency')),
        ],
      );
    },
  );
}
