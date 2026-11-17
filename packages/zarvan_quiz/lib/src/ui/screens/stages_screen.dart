import 'package:zarvan_core/zarvan_core.dart' show UiRect;
import 'package:zarvan_core/zarvan_core_quiz.dart';

import '../quiz_screen.dart';
import 'chapters_screen.dart';
import 'game_screen.dart';

/// The four stages of a chapter, in tier order. A stage opens when the one
/// before it was passed; a locked one says what it needs.
class QuizStagesScreen extends QuizScreen {
  QuizStagesScreen(super.kit, this.author);

  final QuizAuthor author;

  @override
  void build() {
    final s = kit.strings;
    final p = kit.session.progress;
    titleBar(author.name, onBack: () => goTo(QuizChaptersScreen(kit)));
    var y = 96.0;
    for (final tier in QuizTier.values) {
      final unlocked = p.isUnlocked(author.id, tier);
      final entry = p.stages[author.id]?[tier.name];
      final b = button(
        UiRect(
          QuizScreen.margin,
          y,
          QuizScreen.worldWidth - 2 * QuizScreen.margin,
          64,
        ),
        '${s.stage} ${s.tierName(tier.level)}',
        () => play(
          QuizRound.stage(
            kit.factory,
            kit.stageMode,
            author: author.id,
            tier: tier,
            attempt: (entry?.attempts ?? 0) + 1,
          ),
          () => QuizGameScreen(kit),
        ),
        style: QuizButtonStyle.option,
        size: 19,
      );
      b.label.pos.y -= 10;
      b.enabled = unlocked;
      final info = unlocked
          ? List.generate(3, (i) => i < (entry?.stars ?? 0) ? '★' : '☆').join()
          : s.stageLockedHint;
      label(
        info,
        QuizScreen.worldWidth / 2,
        y + 44,
        size: 14,
        color: unlocked ? theme.accent : theme.soft,
      );
      if (!unlocked) {
        b.bg.shape!.alpha = 0.5;
        b.label.text!.alpha = 0.5;
      }
      y += 76;
    }
  }
}
