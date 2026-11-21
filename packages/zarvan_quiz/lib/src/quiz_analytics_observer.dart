import 'dart:async';

import 'quiz_session.dart';

/// Maps quiz lifecycle events to a small analytics event vocabulary without
/// choosing an analytics provider or storing player identity.
class QuizAnalyticsObserver {
  /// Creates an observer that sends mapped events through [event].
  QuizAnalyticsObserver(
    this.session, {
    required this.event,
    this.flush,
  });

  /// The quiz session to observe.
  final QuizSession session;

  /// Receives an event name and its plain-value dimensions.
  final void Function(String name, Map<String, Object?> dimensions) event;

  /// Flushes the provider queue after a round ends, when supplied.
  final Future<void> Function()? flush;

  /// Starts observing and returns a function that stops the subscription.
  void Function() start() {
    final sub = session.events.listen(_on);
    return () => unawaited(sub.cancel());
  }

  void _on(QuizEvent e) {
    final mode = e.round.mode.type;
    switch (e) {
      case RoundStarted():
        event('run_start', {
          'mode': mode,
          if (e.round.author != null) 'author': e.round.author,
          if (e.round.tier != null) 'tier': e.round.tier!.name,
        });
      case AnswerGiven():
        event('answer', {
          'mode': mode,
          'item': e.question.itemId,
          'tier': e.question.tier.name,
          'correct': e.result.correct,
          'hint': e.result.record.hint,
          'points': e.result.points,
          'streak': e.result.streak,
        });
      case HintUsed():
        event('hint', {
          'mode': mode,
          'item': e.question.itemId,
          'tier': e.question.tier.name,
        });
      case ContinueOffered():
        event('continue_offered', {'mode': mode});
      case ContinueResolved():
        event('continue', {'mode': mode, 'taken': e.taken});
      case RoundEnded():
        event('run_end', {
          'mode': mode,
          'score': e.round.run.score,
          'correct': e.round.correctCount,
          'answered': e.round.run.index,
          'stars': e.reward.stars,
          'coins': e.reward.coins,
          'record': e.reward.newRecord,
        });
        final flushEvents = flush;
        if (flushEvents != null) unawaited(flushEvents());
    }
  }
}
