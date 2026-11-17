import 'quiz_item.dart';

/// An author a bank credits; the bank's author order is the order of
/// chapters in a staged game.
class QuizAuthor {
  const QuizAuthor({required this.id, required this.name});

  final String id;
  final String name;
}

/// A bank of [QuizItem]s in the generic JSON format a game ships as an asset.
/// Nothing here is specific to poetry: whatever a game wants to carry
/// (source link, form, title) rides in each item's `meta` untouched.
class QuizBank {
  QuizBank({required this.authors, required List<QuizItem> items})
    : _items = List.unmodifiable(items),
      _byId = {for (final i in items) i.id: i};

  /// The only format version this reader understands.
  static const supportedVersion = 1;

  final List<QuizAuthor> authors;
  final List<QuizItem> _items;
  final Map<String, QuizItem> _byId;

  /// Reads a bank. An unknown `version` or a bad item raises a
  /// [FormatException] that says which, instead of failing later and vaguely.
  factory QuizBank.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    if (version != supportedVersion) {
      throw FormatException(
        'Unsupported quiz bank version $version (this reader supports version $supportedVersion).',
      );
    }
    final rawItems = (json['items'] as List? ?? const []);
    final items = <QuizItem>[];
    for (var i = 0; i < rawItems.length; i++) {
      final map = (rawItems[i] as Map).cast<String, dynamic>();
      try {
        items.add(QuizItem.fromJson(map));
      } on FormatException catch (e) {
        throw FormatException('Item #${i + 1} (${map['id']}): ${e.message}');
      }
    }
    return QuizBank(
      authors: [
        for (final a in (json['authors'] as List? ?? const []))
          QuizAuthor(id: (a as Map)['id'] as String, name: a['name'] as String),
      ],
      items: items,
    );
  }

  /// Items, optionally narrowed to [author] and [tier], most famous first and
  /// by id within equal fame, so a stage always lists the same questions in
  /// the same order.
  List<QuizItem> items({String? author, QuizTier? tier}) {
    final out = [
      for (final i in _items)
        if ((author == null || i.author == author) &&
            (tier == null || i.tier == tier.level))
          i,
    ];
    out.sort((a, b) {
      final f = b.fame.compareTo(a.fame);
      return f != 0 ? f : a.id.compareTo(b.id);
    });
    return out;
  }

  /// The item with [id], or null.
  QuizItem? byId(String id) => _byId[id];

  Map<String, dynamic> toJson() => {
    'version': supportedVersion,
    'authors': [
      for (final a in authors) {'id': a.id, 'name': a.name},
    ],
    'items': [
      for (final i in _items)
        {...i.toJson(), 'tier': QuizTier.ofLevel(i.tier)?.name ?? i.tier},
    ],
  };
}
