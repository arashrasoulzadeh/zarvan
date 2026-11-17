/// Every text the quiz screens show, given by the game, so the engine stays language-free
/// and another language is a second instance.
class QuizStrings {
  const QuizStrings({
    required this.appName,
    required this.coins,
    required this.settings,
    required this.about,
    required this.dailyChallenge,
    required this.dailyDone,
    required this.dailyTodayPlay,
    required this.chapters,
    required this.wallTitle,
    required this.chaptersDone,
    required this.outOf,
    required this.continueGame,
    required this.endless,
    required this.race,
    required this.stageLockedHint,
    required this.stars,
    required this.stage,
    required this.next,
    required this.hint,
    required this.lives,
    required this.clock,
    required this.score,
    required this.streak,
    required this.result,
    required this.stageResultPassed,
    required this.stageResultFailed,
    required this.newRecord,
    required this.coinsEarned,
    required this.backToMenu,
    required this.playAgain,
    required this.share,
    required this.copied,
    required this.shareFailed,
    required this.continueWithAd,
    required this.continueQuestion,
    required this.noThanks,
    required this.rewardAd,
    required this.tutorialTitle,
    required this.tutorialBody,
    required this.tutorialDone,
    required this.theme,
    required this.themeSystem,
    required this.themeLight,
    required this.themeDark,
    required this.sound,
    required this.haptics,
    required this.aboutSource,
    required this.aboutVersion,
    required this.aboutLicenseNote,
    required this.difficulty,
    required this.notEnoughCoins,
    required this.loadError,
    required this.tierNames,
    required this.number,
    this.rtl = false,
  });

  /// The game's name, shown as the title of the menu.
  final String appName;

  /// Word after the coin count ("coins").
  final String coins;

  /// Settings screen title.
  final String settings;

  /// About screen title and menu link.
  final String about;

  /// Daily challenge title and button.
  final String dailyChallenge;

  /// Shown on the daily card once played.
  final String dailyDone;

  /// Line under the daily title before it is played.
  final String dailyTodayPlay;

  /// Chapters screen title and menu button.
  final String chapters;

  /// Heading above the shelf of authors on the menu.
  final String wallTitle;

  /// Word after "2 of 10" ("complete").
  final String chaptersDone;

  /// The word between the two numbers of "2 of 10".
  final String outOf;

  /// The big button that goes on with the next stage.
  final String continueGame;

  /// Endless mode button.
  final String endless;

  /// Timed race button.
  final String race;

  /// What a locked stage needs.
  final String stageLockedHint;

  /// Word after a star count.
  final String stars;

  /// Word before a tier name on a stage card.
  final String stage;

  /// Next button after an answer.
  final String next;

  /// Hint button.
  final String hint;

  /// Label before the lives count.
  final String lives;

  /// Label before the race clock.
  final String clock;

  /// Label before the score.
  final String score;

  /// Label before the streak.
  final String streak;

  /// Result screen title.
  final String result;

  /// Line under the stars of a passed stage.
  final String stageResultPassed;

  /// Line under the stars of a failed stage.
  final String stageResultFailed;

  /// Shown when a record was beaten.
  final String newRecord;

  /// Label before the coins a round earned.
  final String coinsEarned;

  /// Back-to-menu button.
  final String backToMenu;

  /// Play-again button.
  final String playAgain;

  /// Share button.
  final String share;

  /// Shown when the text was copied instead of shared.
  final String copied;

  /// Shown when the text could neither be shared nor copied.
  final String shareFailed;

  /// Button that continues endless by watching an ad.
  final String continueWithAd;

  /// The question asked when the lives run out.
  final String continueQuestion;

  /// Button that declines the continue.
  final String noThanks;

  /// Menu button that gives coins for watching an ad.
  final String rewardAd;

  /// Tutorial title.
  final String tutorialTitle;

  /// Tutorial explanation.
  final String tutorialBody;

  /// Tutorial start button.
  final String tutorialDone;

  /// Theme setting label.
  final String theme;

  /// Theme follows the device.
  final String themeSystem;

  /// Light theme.
  final String themeLight;

  /// Dark theme.
  final String themeDark;

  /// Sound setting.
  final String sound;

  /// Vibration setting.
  final String haptics;

  /// Where the content comes from.
  final String aboutSource;

  /// Label before the version.
  final String aboutVersion;

  /// License / attribution note.
  final String aboutLicenseNote;

  /// Difficulty label.
  final String difficulty;

  /// Shown when a hint cannot be paid.
  final String notEnoughCoins;

  /// Shown when the saved progress could not be read.
  final String loadError;

  /// Whether the language reads right to left (text is laid out that way).
  final bool rtl;

  /// Names of the four tiers, easy to literary.
  final List<String> tierNames;

  /// How a whole number is written (for example with Persian digits).
  final String Function(int value) number;

  /// The name of tier [level] (1..4).
  String tierName(int level) => tierNames[(level.clamp(1, 4)) - 1];

  /// Every text by field name, for tests and tooling.
  Map<String, String> get all => {
    'appName': appName,
    'coins': coins,
    'settings': settings,
    'about': about,
    'dailyChallenge': dailyChallenge,
    'dailyDone': dailyDone,
    'dailyTodayPlay': dailyTodayPlay,
    'chapters': chapters,
    'wallTitle': wallTitle,
    'chaptersDone': chaptersDone,
    'outOf': outOf,
    'continueGame': continueGame,
    'endless': endless,
    'race': race,
    'stageLockedHint': stageLockedHint,
    'stars': stars,
    'stage': stage,
    'next': next,
    'hint': hint,
    'lives': lives,
    'clock': clock,
    'score': score,
    'streak': streak,
    'result': result,
    'stageResultPassed': stageResultPassed,
    'stageResultFailed': stageResultFailed,
    'newRecord': newRecord,
    'coinsEarned': coinsEarned,
    'backToMenu': backToMenu,
    'playAgain': playAgain,
    'share': share,
    'copied': copied,
    'shareFailed': shareFailed,
    'continueWithAd': continueWithAd,
    'continueQuestion': continueQuestion,
    'noThanks': noThanks,
    'rewardAd': rewardAd,
    'tutorialTitle': tutorialTitle,
    'tutorialBody': tutorialBody,
    'tutorialDone': tutorialDone,
    'theme': theme,
    'themeSystem': themeSystem,
    'themeLight': themeLight,
    'themeDark': themeDark,
    'sound': sound,
    'haptics': haptics,
    'aboutSource': aboutSource,
    'aboutVersion': aboutVersion,
    'aboutLicenseNote': aboutLicenseNote,
    'difficulty': difficulty,
    'notEnoughCoins': notEnoughCoins,
    'loadError': loadError,
  };
}
