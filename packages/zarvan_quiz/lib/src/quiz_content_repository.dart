import 'dart:convert';

import 'package:zarvan_core/zarvan_core_quiz.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart' show loadTextAsset;

/// Loads a quiz bank and its language-specific stop words from bundled assets.
class QuizContentRepository {
  /// Creates a content repository and indexes its bank for question building.
  QuizContentRepository(this.bank, this.stopWords)
    : factory = QuestionFactory(bank, stopWords);

  /// The loaded quiz bank.
  final QuizBank bank;

  /// Language-specific words that should not be blanked.
  final Set<String> stopWords;

  /// Builds deterministic questions from [bank] and [stopWords].
  final QuestionFactory factory;

  /// Loads bank and stop-word JSON from the game's declared Flutter assets.
  /// [bankAsset] and [stopWordsAsset] are paths relative to the asset bundle.
  static Future<QuizContentRepository> load({
    required String bankAsset,
    required String stopWordsAsset,
  }) async => parse(
    await loadTextAsset(bankAsset),
    await loadTextAsset(stopWordsAsset),
  );

  /// Parses a bank and a stop-word document; words remain supplied by the game.
  static QuizContentRepository parse(String bankJson, String stopWordsJson) {
    final bank = QuizBank.fromJson(
      jsonDecode(bankJson) as Map<String, dynamic>,
    );
    final stop = jsonDecode(stopWordsJson) as Map<String, dynamic>;
    return QuizContentRepository(bank, {
      ...(stop['words'] as List? ?? const []).cast<String>(),
    });
  }
}
