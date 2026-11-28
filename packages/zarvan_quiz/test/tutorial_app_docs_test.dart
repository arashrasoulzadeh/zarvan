import 'package:flutter_test/flutter_test.dart';
import 'package:zarvan_core/zarvan_core.dart' show KeyValueStore, MemoryKeyValueStore;
import 'package:zarvan_flutter/zarvan_flutter.dart';
import 'package:zarvan_quiz/zarvan_quiz.dart';

Future<QuizKit> createKit(KeyValueStore store) async {
  final bank = QuizBank.fromJson({
    'version': 1,
    'authors': [
      {'id': 'garden', 'name': 'Word Garden'},
    ],
    'items': [
      for (final (tier, sentences) in [
        ('easy', [
          'bright flowers grow beside rivers',
          'gentle birds sing above trees',
        ]),
        ('medium', [
          'silver moonlight covers quiet valleys',
          'autumn leaves drift across meadows',
        ]),
        ('hard', [
          'distant thunder echoes through mountains',
          'morning mist surrounds ancient forests',
        ]),
        ('literary', [
          'amber twilight softens silent horizons',
          'patient tides polish weathered stones',
        ]),
      ])
        for (var i = 0; i < sentences.length; i++)
          {
            'id': '$tier-$i',
            'author': 'garden',
            'tier': tier,
            'fame': 10 - i,
            'lines': [sentences[i]],
          },
    ],
  });
  return QuizKit(
    session: await QuizSession.open(store),
    factory: QuestionFactory(bank, const {}),
    strings: strings,
    themes: themes,
    settings: await QuizSettings.load(store),
    stageMode: const StageMode(
      questionCount: 2,
      passAt: 1,
      starAt: [1, 2],
    ),
    transitions: false,
  );
}

class WordGarden extends Game {
  WordGarden(this.kit);
  final QuizKit kit;

  @override
  GameConfig get config => const GameConfig(
    title: 'Word Garden',
    worldWidth: QuizScreen.worldWidth,
    worldHeight: QuizScreen.worldHeight,
    orientation: GameOrientation.portrait,
    onScreenControls: OnScreenControlsMode.off,
    fixedTimestepSeconds: 1 / 60,
  );

  @override
  ViewportConfig get viewportConfig => const ViewportConfig.fittingWorld(
    QuizScreen.worldWidth, QuizScreen.worldHeight,
  );

  @override
  Scene createInitialScene() =>
      kit.session.progress.flags['tutorialDone'] == true
          ? QuizHomeScreen(kit)
          : QuizTutorialScreen(kit);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('tutorial quiz kit starts a playable stage', () async {
    final kit = await createKit(MemoryKeyValueStore());
    final app = WordGarden(kit);
    expect(app.createInitialScene(), isA<QuizTutorialScreen>());
    kit.session.begin(QuizRound.stage(kit.factory, kit.stageMode,
        author: 'garden', tier: QuizTier.easy));
    final question = kit.session.question;
    expect(question, isNotNull);
    expect(question!.options.length, 4);
    kit.session.answer(question.answerIndex);
    expect(kit.session.lastResult!.correct, isTrue);
  });
}

const strings = QuizStrings(
  appName: 'Word Garden',
  coins: 'coins',
  settings: 'Settings',
  about: 'About',
  dailyChallenge: 'Daily',
  dailyDone: 'Done',
  dailyTodayPlay: 'Five new questions',
  chapters: 'Chapters',
  wallTitle: 'Collections',
  chaptersDone: 'complete',
  outOf: 'of',
  continueGame: 'Continue',
  endless: 'Endless',
  race: 'Race',
  stageLockedHint: 'Pass the previous stage',
  stars: 'stars',
  stage: 'Stage',
  next: 'Next',
  hint: 'Hint',
  lives: 'Lives',
  clock: 'Time',
  score: 'Score',
  streak: 'Streak',
  result: 'Result',
  stageResultPassed: 'Passed',
  stageResultFailed: 'Try again',
  newRecord: 'New record',
  coinsEarned: 'Coins earned',
  backToMenu: 'Menu',
  playAgain: 'Again',
  share: 'Share',
  copied: 'Copied',
  shareFailed: 'Could not share',
  continueWithAd: 'Continue with an ad',
  continueQuestion: 'Out of lives. One more for an ad?',
  noThanks: 'No, finish',
  tutorialTitle: 'Find the word',
  tutorialBody: 'One word is missing',
  tutorialDone: 'Start',
  tutorialTip: 'A hint costs 20 coins',
  theme: 'Theme',
  themeSystem: 'System',
  themeLight: 'Light',
  themeDark: 'Dark',
  sound: 'Sound',
  haptics: 'Haptics',
  aboutSource: 'Original demo sentences',
  aboutVersion: 'Version',
  aboutLicenseNote: 'Demo content',
  difficulty: 'Difficulty',
  notEnoughCoins: 'Not enough coins',
  loadError: 'Save not read',
  rewardAd: '15 coins for an ad',
  tierNames: ['Easy', 'Medium', 'Hard', 'Literary'],
  number: _plain,
);
String _plain(int n) => '$n';

const themes = QuizThemes(
  light: QuizTheme(
    background: 0xFFFFFFFF,
    ink: 0xFF111111,
    soft: 0xFF888888,
    surface: 0xFFEEEEEE,
    accent: 0xFF1F6F6B,
    onAccent: 0xFFFFFFFF,
    correct: 0xFF2E7D32,
    wrong: 0xFFC62828,
  ),
  dark: QuizTheme(
    background: 0xFF101010,
    ink: 0xFFEEEEEE,
    soft: 0xFF999999,
    surface: 0xFF222222,
    accent: 0xFF6FC2BC,
    onAccent: 0xFF101010,
    correct: 0xFF66BB6A,
    wrong: 0xFFEF5350,
    isDark: true,
  ),
);
