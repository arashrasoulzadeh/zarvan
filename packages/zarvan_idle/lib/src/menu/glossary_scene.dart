import 'dart:async' show Completer;
import 'dart:ui' show Offset, Rect, Size;

import 'package:zarvan_core/zarvan_core.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart'
    as eng
    show
        AnimationClip,
        AnimationState,
        AnimationSystem,
        AtlasRegistry,
        LoadedSheet,
        ModalDialog,
        Pivot,
        Scene,
        SceneController,
        ShaderEffect,
        Sprite,
        SpriteAtlas,
        Text,
        TextAlignment,
        loadSpriteSheet,
        panelFrameAtlas,
        spawnPanelFrame,
        spawnWorldText;

import '../platformer/hud/upgrade_bar.dart' show UpgradeBar;
import 'art_sizes.dart';
import 'menu_button.dart';

/// One glossary entry: a level/zone or an enemy, in both languages. Pure data,
/// so any idle game can build its glossary from its own level/roster files.
class GlossaryEntry {
  const GlossaryEntry({
    required this.id,
    required this.category,
    required this.nameEn,
    required this.nameFa,
    required this.subtitleEn,
    required this.subtitleFa,
    required this.detailEn,
    required this.detailFa,
    this.statsEn,
    this.statsFa,
    this.spriteStem,
    this.backgroundImages,
  });

  /// Stable key, e.g. a zone key or a roster enemy id.
  final String id;

  /// One of [GlossaryConfig.categories]' ids ('level' / 'enemy' by convention).
  final String category;

  final String nameEn;
  final String nameFa;

  /// One line shown under the name in the list (zone range, enemy's zone...).
  final String subtitleEn;
  final String subtitleFa;

  /// The write-up shown under the stat table in the detail dialog (history,
  /// powers...), already formatted as the multi-line text to draw.
  final String detailEn;
  final String detailFa;

  /// This entry's core numbers, label -> value, drawn as a small table in
  /// the detail dialog (e.g. `{'HP': '40', 'ATK': '6'}`); null or empty for
  /// an entry with nothing to tabulate (a level has no combat stats).
  /// [statsEn]/[statsFa] must have the same length, in the same order —
  /// only the labels (and any unit in the value) are expected to differ.
  final Map<String, String>? statsEn;
  final Map<String, String>? statsFa;

  /// Asset stem of this entry's strip sheets (`<stem>_idle.png`/`.json`,
  /// `_attack`, `_death`), e.g. `assets/mobarez/enemies/wolf`; each sheet is
  /// one row of square frames, same shape `loadSpriteSheet` reads for
  /// gameplay. Null for an entry with no art (every other category falls
  /// back to the plain text list). A category whose first entry sets this
  /// draws as a grid instead: each card loops [idle] before it's even
  /// tapped, and opening the entry shows [idle]/`attack`/`death` (whichever
  /// exist) side by side, in that order, above its write-up.
  final String? spriteStem;

  /// Full-image layers stacked as this entry's row background instead of the
  /// plain dark panel (e.g. a level's own `sky.png`/`far.png` parallax), back
  /// to front. Null draws the ordinary flat panel. Only meaningful for a
  /// list-category entry — a grid card's own looping [spriteStem] art
  /// already serves that role.
  final List<String>? backgroundImages;
}

/// One tab of the category switcher ('Levels', 'Enemies'...). [id] matches
/// [GlossaryEntry.category].
class GlossaryCategory {
  const GlossaryCategory({
    required this.id,
    required this.labelEn,
    required this.labelFa,
  });

  final String id;
  final String labelEn;
  final String labelFa;
}

/// Data of a [GlossaryScene].
class GlossaryConfig {
  const GlossaryConfig({
    required this.backgroundImage,
    required this.buttonImage,
    required this.panelImage,
    required this.entries,
    required this.categories,
    required this.onBack,
    this.titleBannerImage,
    this.washAlpha = 0x60,
    this.titleEn = 'Glossary',
    this.titleFa = 'دانشنامه',
    this.backLabel = 'Back',
    this.idleLabelEn = 'Idle',
    this.idleLabelFa = 'آماده',
    this.attackLabelEn = 'Attack',
    this.attackLabelFa = 'حمله',
    this.deathLabelEn = 'Death',
    this.deathLabelFa = 'مرگ',
    this.rtl = false,
    this.perPage = 6,
    this.gridColumns = 3,
    this.gridRows = 4,
    this.safeInset = 20,
    this.initialCategory,
  });

  final String backgroundImage;
  final String buttonImage;
  final String panelImage;

  /// Ribbon drawn behind the title; null draws the title straight on the art.
  final String? titleBannerImage;

  /// Opacity (0-255) of the dark wash over the background.
  final int washAlpha;

  /// Every level and enemy, in any order; the scene groups and paginates them.
  final List<GlossaryEntry> entries;

  /// The category tabs, in display order; must cover every entry's category.
  final List<GlossaryCategory> categories;

  final void Function(eng.SceneController scenes) onBack;
  final String titleEn;
  final String titleFa;
  final String backLabel;

  /// Captions under the three animation previews in the detail dialog.
  final String idleLabelEn, idleLabelFa;
  final String attackLabelEn, attackLabelFa;
  final String deathLabelEn, deathLabelFa;

  final bool rtl;

  /// Entries per page for a category with no [GlossaryEntry.spriteStem]
  /// (drawn as a text list, e.g. levels).
  final int perPage;

  /// Grid size for a category whose entries have art (e.g. enemies); entries
  /// per page is `gridColumns * gridRows`.
  final int gridColumns;
  final int gridRows;

  /// Margin kept clear on both sides for the part a tall phone crops.
  final double safeInset;

  /// Category tab selected when the scene first opens; null defaults to
  /// [categories]' first entry (as this always did before this field
  /// existed).
  final String? initialCategory;
}

/// A bilingual glossary of levels and enemies: a category switcher over a
/// paged list (or, for a category whose entries carry art, a grid of cards
/// each looping their idle animation before they're even tapped); opening
/// an entry shows its idle/attack/death clips side by side, in that order,
/// above its write-up, in a [eng.ModalDialog]. Built from [GlossaryConfig]
/// only, so any idle game can drive it from its own data (zones, a roster
/// file...).
class GlossaryScene extends eng.Scene {
  GlossaryScene(this.config)
    : assert(config.categories.isNotEmpty, 'GlossaryScene needs categories'),
      _category = config.initialCategory ?? config.categories.first.id;

  final GlossaryConfig config;

  static const _bg = 'glossary_bg';
  static const _btn = 'glossary_btn';
  static const _panel = 'glossary_panel';
  static const _banner = 'glossary_banner';

  /// Layout constants, named so the header/tabs/list vertical rhythm reads
  /// as one block instead of magic numbers repeated at each call site.
  static const _titleY = 16.0;
  static const _tabsY = 46.0;
  static const _listTop = 62.0;
  static const _footerY = -22.0; // from world height

  String _category;
  int _page = 0;

  /// Bumped on every page/category change; an in-flight grid-thumbnail load
  /// checks its captured value against this before touching entities, so a
  /// load that resolves after the player has already turned the page is a
  /// no-op instead of mutating entities `_buildPage` already destroyed.
  ///
  /// Kept separate from [_detailToken] on purpose: opening a card's detail
  /// dialog must not cancel its *siblings'* still-loading grid thumbnails —
  /// they share no entities, so there's nothing to protect, and conflating
  /// the two orphaned every other card's thumbnail the instant one card was
  /// tapped before the rest finished decoding (worse the slower a load is,
  /// which pivot measurement made otherwise-silent).
  int _pageToken = 0;

  /// Bumped every time the detail dialog opens a (possibly different) entry;
  /// an in-flight clip load checks its captured value against this so a
  /// load for the *previous* entry can't paint over the one now showing.
  int _detailToken = 0;

  final _fit = ArtFitter();
  final _pageEntities = <EntityId>[];
  final _rowRects = <Rect, GlossaryEntry>{};
  final _catButtons = <MenuButton>[];
  late MenuButton _prev, _next, _back;
  late EntityId _pageLabel;
  eng.ModalDialog? _dialog;
  EntityId? _detailTitle;
  EntityId? _detailBody;

  /// The detail dialog's three animation previews, built once and reused
  /// (re-pointed at a different entry's sheets) every time it opens, so
  /// opening a new entry never grows the entity count.
  late final List<_AnimPreview> _detailPreviews;

  /// The detail dialog's stat table (fixed 2x2 grid), built once and
  /// reused the same way as [_detailPreviews].
  late final List<_StatCell> _statCells;

  /// A level entry (no [GlossaryEntry.spriteStem]) has no animations to show
  /// in the detail dialog, so it shows its own background layers here
  /// instead, through a `portal`-kind [eng.ShaderEffect]: the same glowing,
  /// slowly-turning rim and radial core used for the world map's zone
  /// portals, which reads as a glossy orb/sphere with the zone's scenery
  /// inside it rather than a flat cropped photo. Built once and reused like
  /// [_detailPreviews]; its `images` are cleared (nothing drawn) whenever
  /// the open entry is an enemy instead.
  late final EntityId _levelPreviewEffect;

  late eng.AtlasRegistry _registry;

  /// `Scene.populate` runs *before* `loadAssets` (see the base class's own
  /// doc comment) — but the glossary now opens straight on the Enemies
  /// grid, so its art-loading can start from `populate` itself, racing
  /// ahead of [_registry] (only set once `loadAssets` finishes). Every
  /// loader awaits this before touching it, instead of assuming it's
  /// already there the way a tap-triggered load safely could.
  final _registryReady = Completer<void>();

  /// Sheets already loaded (frame count + measured pivots), by atlas id —
  /// avoids re-decoding/re-measuring an id already registered.
  final _sheets = <String, _Sheet>{};

  /// Full-image atlas ids already registered — avoids re-decoding a row
  /// background (`GlossaryEntry.backgroundImages`) already loaded.
  final _loadedImages = <String>{};

  List<GlossaryEntry> get _visible =>
      config.entries.where((e) => e.category == _category).toList();

  bool get _gridCategory =>
      _visible.isNotEmpty && _visible.first.spriteStem != null;

  int get _perPage =>
      _gridCategory ? config.gridColumns * config.gridRows : config.perPage;

  int get _pages => (_visible.length / _perPage).ceil().clamp(1, 1 << 30);

  @override
  bool get showOnScreenControls => false;

  @override
  double? get ambientBrightness => 1;

  @override
  Future<eng.AtlasRegistry> loadAssets() async {
    final r = eng.AtlasRegistry();
    Future<eng.SpriteAtlas> full(String p) =>
        eng.SpriteAtlas.loadFullImageFromAssets(p);
    final bg = await full(config.backgroundImage);
    artSizes[config.backgroundImage] = Size(
      bg.image.width.toDouble(),
      bg.image.height.toDouble(),
    );
    r.register(_bg, bg);
    r.register(_btn, UpgradeBar.atlasFor(await full(config.buttonImage)));
    r.register(_panel, eng.panelFrameAtlas(await full(config.panelImage), 24));
    if (config.titleBannerImage != null) {
      final banner = await full(config.titleBannerImage!);
      artSizes[config.titleBannerImage!] = Size(
        banner.image.width.toDouble(),
        banner.image.height.toDouble(),
      );
      r.register(_banner, banner);
    }
    _registry = r;
    _registryReady.complete();
    return r;
  }

  /// Loads `<stem>_<clip>.png`/`.json` into the registry under [atlasId] the
  /// first time it's asked for; a later call for the same id is a no-op.
  /// Each sheet is cropped per pose (an attack lunges, a death collapses),
  /// so every frame's actual art sits in a different spot of its 128px cell
  /// — drawn cell-centred (the sprite's only anchor) that makes a small
  /// looping preview visibly slide frame to frame. [eng.sheetPivots] finds
  /// each frame's standing point by pixels; callers turn that into
  /// `AnimationClip`/manual per-frame offsets that cancel the slide (see
  /// [_loopClip] and [_loadDetailArt]). Returns null if this clip's asset
  /// doesn't exist for this entry (e.g. an enemy with no death sheet).
  Future<_Sheet?> _ensureSheet(String stem, String clip, String atlasId) async {
    final cached = _sheets[atlasId];
    if (cached != null) return cached.frames == 0 ? null : cached;
    await _registryReady.future;
    eng.LoadedSheet sheet;
    try {
      sheet = await eng.loadSpriteSheet('${stem}_$clip');
    } catch (_) {
      _sheets[atlasId] = const _Sheet(frames: 0, pivots: []);
      return null;
    }
    _registry.register(atlasId, sheet.atlas);
    final result = _Sheet(frames: sheet.sidecar.frames, pivots: sheet.pivots);
    _sheets[atlasId] = result;
    return result;
  }

  /// Registers [path] as a full-image atlas under [atlasId] the first time
  /// it's asked for (a later call for the same id is a no-op) — used for a
  /// list row's own background layers (see [GlossaryEntry.backgroundImages]),
  /// which need no cropping or pivots, unlike [_ensureSheet]'s clip sheets.
  /// Returns whether [atlasId] is registered and ready (either just now, or
  /// from an earlier call) — false if [path] doesn't exist, which this
  /// scene then leaves undrawn rather than crashing on a bundle that's
  /// missing one zone's background.
  Future<bool> _ensureFullImage(String path, String atlasId) async {
    if (_loadedImages.contains(atlasId)) return true;
    await _registryReady.future;
    try {
      final atlas = await eng.SpriteAtlas.loadFullImageFromAssets(path);
      artSizes[path] = Size(
        atlas.image.width.toDouble(),
        atlas.image.height.toDouble(),
      );
      _registry.register(atlasId, atlas);
    } catch (_) {
      return false;
    }
    _loadedImages.add(atlasId);
    return true;
  }

  String _idleAtlasId(String entryId) => 'glossary_idle_$entryId';

  String _rowBgAtlasId(String entryId, int layer) =>
      'glossary_rowbg_${entryId}_$layer';
  String _clipAtlasId(String entryId, String clip) =>
      'glossary_${clip}_$entryId';

  /// A looping clip of [sheet]'s frames, each offset against [sheet]'s own
  /// first frame so the character's standing point stays put as it loops
  /// (see [_ensureSheet]).
  eng.AnimationState _loopClip(_Sheet sheet) {
    final ref = sheet.pivots.first;
    return eng.AnimationState(
      eng.AnimationClip(
        'idle',
        [for (var i = 0; i < sheet.frames; i++) '$i'],
        frameDurationSeconds: 0.12,
        frameOffsetsX: [for (final p in sheet.pivots) ref.x - p.x],
        frameOffsetsY: [for (final p in sheet.pivots) ref.y - p.y],
      ),
    );
  }

  /// Frame duration for the detail dialog's own previews (see
  /// [_AnimPreview] on why they aren't driven by [eng.AnimationSystem]).
  static const _previewFrameSeconds = 0.12;

  @override
  Future<void> populate(
    World world,
    eng.SceneController scenes,
    GameState state,
  ) async {
    world.addSystem(eng.AnimationSystem());
    final w = world.width.toDouble(), h = world.height.toDouble();
    EntityId sprite(
      String a,
      String reg,
      double x,
      double y,
      double sx,
      double sy,
      int z, {
      int? tint,
    }) {
      final e = world.spawn();
      world.componentsOf<Position>().set(e, Position(x, y));
      world.componentsOf<eng.Sprite>().set(
        e,
        eng.Sprite(a, reg, scaleX: sx, scaleY: sy, zIndex: z, tintArgb: tint),
      );
      return e;
    }

    final bgE = sprite(_bg, 'full', w / 2, h / 2, w / 180, h / 320, 0);
    _fit.addStretch(bgE, config.backgroundImage, w, h, 180, 320);
    sprite(
      _panel,
      'f11',
      w / 2,
      h / 2,
      (w + 20) / 48,
      (h + 20) / 27,
      1,
      tint: config.washAlpha << 24,
    );
    if (config.titleBannerImage != null) {
      final bannerE = sprite(_banner, 'full', w / 2, _titleY, 1, 1, 5);
      _fit.add(bannerE, config.titleBannerImage!, 112, 104);
    }
    eng.spawnWorldText(
      world,
      w / 2,
      _titleY,
      config.rtl ? config.titleFa : config.titleEn,
      fontSize: 8,
      colorArgb: 0xFFFFE38A,
      zIndex: 6,
      maxWidth: 140,
      rtl: config.rtl ? true : null,
    );

    final n = config.categories.length;
    for (var i = 0; i < n; i++) {
      final c = config.categories[i];
      final cx = w / 2 + (i - (n - 1) / 2) * 56;
      _catButtons.add(
        MenuButton.spawn(
          world,
          atlasId: _btn,
          id: c.id,
          label: config.rtl ? c.labelFa : c.labelEn,
          cx: cx,
          cy: _tabsY,
          width: 50,
          style: c.id == _category ? 'primary' : 'disabled',
          fontSize: 6.5,
          rtl: config.rtl,
        ),
      );
    }

    final y = h + _footerY;
    _prev = MenuButton.spawn(
      world,
      atlasId: _btn,
      id: 'prev',
      label: config.rtl ? '›' : '‹',
      cx: config.rtl ? w - config.safeInset - 16 : config.safeInset + 16,
      cy: y,
      width: 34,
      fontSize: 9,
    );
    _next = MenuButton.spawn(
      world,
      atlasId: _btn,
      id: 'next',
      label: config.rtl ? '‹' : '›',
      cx: config.rtl ? config.safeInset + 16 : w - config.safeInset - 16,
      cy: y,
      width: 34,
      fontSize: 9,
    );
    _back = MenuButton.spawn(
      world,
      atlasId: _btn,
      id: 'back',
      label: config.backLabel,
      cx: w / 2,
      cy: y,
      width: 60,
      style: 'primary',
      fontSize: 7.5,
      rtl: config.rtl,
    );
    _pageLabel = eng.spawnWorldText(
      world,
      w / 2,
      y - 18,
      '',
      fontSize: 5.5,
      colorArgb: 0xFFD8C48A,
      zIndex: 6,
    );
    _buildDialog(world);
    _buildPage(world);
  }

  void _buildDialog(World world) {
    final w = world.width.toDouble(), h = world.height.toDouble();
    final rect = Rect.fromLTRB(
      config.safeInset + 6,
      _listTop,
      w - config.safeInset - 6,
      h + _footerY - 6,
    );
    final d = _dialog = eng.ModalDialog.spawn(
      world,
      rect: rect,
      z: 150,
      frameAtlasId: _panel,
      rtl: config.rtl,
    );
    final textW = rect.width - 24;
    _detailTitle = d.addText(
      rect.center.dx,
      rect.top + 18,
      '',
      7.5,
      0xFFFFE38A,
      maxWidth: textW,
    );
    final slots = [
      (config.rtl ? config.idleLabelFa : config.idleLabelEn),
      (config.rtl ? config.attackLabelFa : config.attackLabelEn),
      (config.rtl ? config.deathLabelFa : config.deathLabelEn),
    ];
    final previewY = rect.top + 42;
    // Evenly split across the full rect width (no left margin bias) so the
    // row of three sits centred under the title, not shifted right.
    final spacing = rect.width / 3;
    _detailPreviews = [
      for (var i = 0; i < 3; i++)
        _AnimPreview(
          sprite: _spawnPreviewSprite(world, d, rect, spacing, i, previewY),
          label: d.addText(
            rect.left + spacing * (i + 0.5),
            previewY + 16,
            '',
            4.6,
            0xFFD8C48A,
          ),
          captionText: slots[i],
        ),
    ];

    // A true circle (the `orb` shader masks itself to the circle inscribed
    // in its rect, unlike `portal`'s edge-to-edge doorway), nudged down from
    // `previewY` so its top doesn't creep under the title text above it.
    const orbDiameter = 50.0;
    final orbEntity = world.spawn();
    world.componentsOf<Position>().set(
      orbEntity,
      Position(rect.center.dx, previewY + 10),
    );
    world.componentsOf<eng.ShaderEffect>().set(
      orbEntity,
      eng.ShaderEffect(
        kind: eng.ShaderEffect.orb,
        width: orbDiameter,
        height: orbDiameter,
        zIndex: 161,
        speed: 0.5,
      ),
    );
    _levelPreviewEffect = d.add(orbEntity);

    // A 2x2 stat table, right under the previews' captions.
    const cols = 2, rows = 2, cellGap = 3.0, cellH = 17.0;
    final tableTop = previewY + 26;
    final tableW = rect.width - 20;
    final cellW = (tableW - cellGap * (cols - 1)) / cols;
    _statCells = [
      for (var i = 0; i < cols * rows; i++)
        _buildStatCell(
          world,
          d,
          cx: rect.left + 10 + (i % cols) * (cellW + cellGap) + cellW / 2,
          cy: tableTop + (i ~/ cols) * (cellH + cellGap) + cellH / 2,
          cellW: cellW,
          cellH: cellH,
        ),
    ];
    final tableBottom = tableTop + rows * cellH + (rows - 1) * cellGap;

    _detailBody = d.addText(
      rect.center.dx,
      tableBottom + 40,
      '',
      5.6,
      0xFFEDE3C8,
      maxWidth: textW,
    );
  }

  _StatCell _buildStatCell(
    World world,
    eng.ModalDialog d, {
    required double cx,
    required double cy,
    required double cellW,
    required double cellH,
  }) {
    // Not registered with `d.add`: `ModalDialog._applyFade` forces every
    // tracked sprite that isn't part of its own frame to a flat white tint
    // (so it can fade it in/out), which would wipe this cell's dark tint
    // right back to the panel art's own parchment color. Managing this
    // sprite's scale by hand in `_openDetail` (0 to hide, the base scale to
    // show) gets the same show/hide behavior without that clobber.
    final panel = world.spawn();
    world.componentsOf<Position>().set(panel, Position(cx, cy));
    world.componentsOf<eng.Sprite>().set(
      panel,
      eng.Sprite(
        _panel,
        'f11',
        scaleX: 0,
        scaleY: 0,
        zIndex: 160,
        tintArgb: 0xE0140A06,
      ),
    );
    return _StatCell(
      panel: panel,
      baseScaleX: cellW / 48,
      baseScaleY: cellH / 27,
      label: d.addText(cx, cy - 4, '', 4.0, 0xFFD8C48A),
      value: d.addText(cx, cy + 5, '', 6.2, 0xFFFFE38A),
    );
  }

  EntityId _spawnPreviewSprite(
    World world,
    eng.ModalDialog d,
    Rect rect,
    double spacing,
    int i,
    double previewY,
  ) {
    final e = world.spawn();
    world.componentsOf<Position>().set(
      e,
      Position(rect.left + spacing * (i + 0.5), previewY),
    );
    world.componentsOf<eng.Sprite>().set(
      e,
      eng.Sprite(_panel, 'f11', scaleX: 0, scaleY: 0, zIndex: 161),
    );
    return d.add(e);
  }

  void _buildPage(World world) {
    for (final e in _pageEntities) {
      world.destroy(e);
    }
    _pageEntities.clear();
    _rowRects.clear();
    _pageToken++;
    if (_gridCategory) {
      _buildGrid(world);
    } else {
      _buildList(world);
    }
    _prev.setStyle(world, _page > 0 ? 'secondary' : 'disabled');
    _next.setStyle(world, _page < _pages - 1 ? 'secondary' : 'disabled');
    world.componentsOf<eng.Text>().get(_pageLabel)?.text =
        '${_page + 1} / $_pages';
  }

  void _buildList(World world) {
    final entries = _visible;
    final w = world.width.toDouble();
    final left = config.safeInset, right = w - config.safeInset;
    const rowH = 34.0, step = 38.0;
    final from = _page * _perPage;
    final to = (from + _perPage).clamp(0, entries.length);
    final token = _pageToken;
    for (var i = from; i < to; i++) {
      final entry = entries[i];
      final top = _listTop + (i - from) * step;
      final rect = Rect.fromLTWH(left, top, right - left, rowH);
      _rowRects[rect] = entry;
      final bgImages = entry.backgroundImages;
      if (bgImages != null && bgImages.isNotEmpty) {
        for (var l = 0; l < bgImages.length; l++) {
          final atlasId = _rowBgAtlasId(entry.id, l);
          final e = world.spawn();
          world.componentsOf<Position>().set(e, Position(rect.center.dx, rect.center.dy));
          world.componentsOf<eng.Sprite>().set(
            e,
            eng.Sprite(atlasId, 'full', scaleX: 0, scaleY: 0, zIndex: 9 + l),
          );
          _pageEntities.add(e);
          _loadRowBackground(world, bgImages[l], atlasId, e, rect, token);
        }
      }
      // A level's own scenery shows through a lighter wash; a plain row
      // (no art) keeps the fuller dark fill it always had.
      for (final e in eng.spawnPanelFrame(
        world,
        atlasId: _panel,
        rect: rect,
        source: const Size(96, 75),
        inset: 24,
        corner: 7,
        zIndex: 10,
      )) {
        world.componentsOf<eng.Sprite>().get(e)?.tintArgb = bgImages != null
            ? 0x90140A06
            : 0xE0140A06;
        _pageEntities.add(e);
      }
      final align = config.rtl
          ? eng.TextAlignment.right
          : eng.TextAlignment.left;
      final textX = config.rtl ? right - 6 : left + 6;
      final textW = right - left - 12;
      for (final (text, dy, size, color) in [
        (config.rtl ? entry.nameFa : entry.nameEn, 11.0, 7.0, 0xFFFFE38A),
        (
          config.rtl ? entry.subtitleFa : entry.subtitleEn,
          23.0,
          5.0,
          0xFFD8C48A,
        ),
      ]) {
        _pageEntities.add(
          eng.spawnWorldText(
            world,
            textX,
            top + dy,
            text,
            fontSize: size.toDouble(),
            colorArgb: color,
            zIndex: 14,
            maxWidth: textW,
            rtl: config.rtl ? true : null,
            align: align,
          ),
        );
      }
    }
  }

  void _buildGrid(World world) {
    final entries = _visible;
    final w = world.width.toDouble();
    final left = config.safeInset, right = w - config.safeInset;
    final cols = config.gridColumns;
    const gap = 4.0;
    final cellW = (right - left - gap * (cols - 1)) / cols;
    const cellH = 52.0, rowStep = cellH + gap;
    final from = _page * _perPage;
    final to = (from + _perPage).clamp(0, entries.length);
    final token = _pageToken;
    for (var i = from; i < to; i++) {
      final entry = entries[i];
      final slot = i - from;
      final col = slot % cols, row = slot ~/ cols;
      final cx = left + col * (cellW + gap) + cellW / 2;
      final top = _listTop + row * rowStep;
      final rect = Rect.fromLTWH(left + col * (cellW + gap), top, cellW, cellH);
      _rowRects[rect] = entry;
      for (final e in eng.spawnPanelFrame(
        world,
        atlasId: _panel,
        rect: rect,
        source: const Size(96, 75),
        inset: 24,
        corner: 7,
        zIndex: 10,
      )) {
        world.componentsOf<eng.Sprite>().get(e)?.tintArgb = 0xE0140A06;
        _pageEntities.add(e);
      }
      final artY = top + cellH * 0.38;
      final spriteEntity = world.spawn();
      world.componentsOf<Position>().set(spriteEntity, Position(cx, artY));
      world.componentsOf<eng.Sprite>().set(
        spriteEntity,
        eng.Sprite(_panel, 'f11', scaleX: 0, scaleY: 0, zIndex: 12),
      );
      _pageEntities.add(spriteEntity);
      _pageEntities.add(
        eng.spawnWorldText(
          world,
          cx,
          top + cellH - 10,
          config.rtl ? entry.nameFa : entry.nameEn,
          fontSize: 4.6,
          colorArgb: 0xFFFFE38A,
          zIndex: 14,
          maxWidth: cellW - 4,
        ),
      );
      final stem = entry.spriteStem;
      if (stem != null) {
        _loadGridArt(world, stem, entry.id, spriteEntity, token);
      }
    }
  }

  Future<void> _loadGridArt(
    World world,
    String stem,
    String entryId,
    EntityId spriteEntity,
    int token,
  ) async {
    final atlasId = _idleAtlasId(entryId);
    final sheet = await _ensureSheet(stem, 'idle', atlasId);
    if (token != _pageToken || sheet == null) return;
    final s = world.componentsOf<eng.Sprite>().get(spriteEntity);
    if (s == null) return;
    const worldHeight = 22.0;
    s.atlasId = atlasId;
    s.region = '0';
    s.scaleX = s.scaleY = worldHeight / 128;
    world.componentsOf<eng.AnimationState>().set(
      spriteEntity,
      _loopClip(sheet),
    );
  }

  Future<void> _loadRowBackground(
    World world,
    String path,
    String atlasId,
    EntityId spriteEntity,
    Rect rect,
    int token,
  ) async {
    final ok = await _ensureFullImage(path, atlasId);
    if (token != _pageToken || !ok) return;
    final s = world.componentsOf<eng.Sprite>().get(spriteEntity);
    if (s == null) return;
    s.atlasId = atlasId;
    // Nominal 480x320 (this project's portrait-parallax convention) until
    // `_fit` corrects it once the real decoded size is known.
    _fit.addStretch(spriteEntity, path, rect.width, rect.height, 480, 320);
  }

  /// Loads up to the first two of [entry]'s background layers (bottom layer
  /// first, matching [GlossaryEntry.backgroundImages]' own order) into
  /// [_levelPreviewEffect]'s portal — the level counterpart of the per-clip
  /// loop in [_loadDetailArt], called from there for an entry with no
  /// [GlossaryEntry.spriteStem]. A layer that fails to load is simply left
  /// out rather than shown blank; [token] guards the same way every other
  /// detail-dialog loader does.
  Future<void> _loadLevelPreview(
    World world,
    GlossaryEntry entry,
    int token,
  ) async {
    final wanted = entry.backgroundImages ?? const <String>[];
    final loaded = <String>[];
    for (var i = 0; i < wanted.length && i < 2; i++) {
      final atlasId = _rowBgAtlasId(entry.id, i);
      if (await _ensureFullImage(wanted[i], atlasId)) loaded.add(atlasId);
    }
    if (token != _detailToken) return;
    world.componentsOf<eng.ShaderEffect>().get(_levelPreviewEffect)?.images =
        loaded;
  }

  Future<void> _loadDetailArt(
    World world,
    GlossaryEntry entry,
    int token,
  ) async {
    final stem = entry.spriteStem;
    if (stem == null) {
      await _loadLevelPreview(world, entry, token);
    } else {
      world.componentsOf<eng.ShaderEffect>().get(_levelPreviewEffect)?.images =
          const [];
    }
    const clips = ['idle', 'attack', 'death'];
    // All three previews anchor to the idle clip's own first frame (loaded
    // first, below), so attack/death don't just stop sliding within
    // themselves but visibly "stand" in the same spot idle does — the point
    // a player's eye settles on between taps.
    eng.Pivot? reference;
    for (var i = 0; i < 3; i++) {
      final preview = _detailPreviews[i];
      preview.frames = const [];
      preview.offsetsX = const [];
      preview.offsetsY = const [];
      if (stem == null) {
        world.componentsOf<eng.Sprite>().get(preview.sprite)
          ?..scaleX = 0
          ..scaleY = 0;
        world.componentsOf<eng.Text>().get(preview.label)?.text = '';
        continue;
      }
      final atlasId = _clipAtlasId(entry.id, clips[i]);
      final sheet = await _ensureSheet(stem, clips[i], atlasId);
      if (token != _detailToken) return;
      final s = world.componentsOf<eng.Sprite>().get(preview.sprite);
      final l = world.componentsOf<eng.Text>().get(preview.label);
      if (sheet == null) {
        s
          ?..scaleX = 0
          ..scaleY = 0;
        l?.text = '';
        continue;
      }
      reference ??= sheet.pivots.first;
      const worldHeight = 26.0;
      if (s != null) {
        s.atlasId = atlasId;
        s.region = '0';
        s.scaleX = s.scaleY = worldHeight / 128;
      }
      preview.elapsed = 0;
      preview.frameIndex = 0;
      preview.frames = [for (var f = 0; f < sheet.frames; f++) '$f'];
      preview.offsetsX = [for (final p in sheet.pivots) reference.x - p.x];
      preview.offsetsY = [for (final p in sheet.pivots) reference.y - p.y];
      l?.text = preview.captionText;
    }
  }

  /// A paused world stops `eng.AnimationSystem` (it runs with `dt * timeScale`
  /// like every other system), but the dialog's previews must keep moving
  /// while the game behind it is frozen — so they're driven here by hand
  /// instead, from [update], which always gets real, unscaled `dt` (see
  /// `ModalDialog`'s own contract).
  void _advancePreviews(double dt, World world) {
    final sprites = world.componentsOf<eng.Sprite>();
    for (final preview in _detailPreviews) {
      if (preview.frames.isEmpty) continue;
      preview.elapsed += dt;
      while (preview.elapsed >= _previewFrameSeconds) {
        preview.elapsed -= _previewFrameSeconds;
        preview.frameIndex = (preview.frameIndex + 1) % preview.frames.length;
      }
      final s = sprites.get(preview.sprite);
      if (s == null) continue;
      s.region = preview.frames[preview.frameIndex];
      s.offsetX = preview.offsetsX[preview.frameIndex];
      s.offsetY = preview.offsetsY[preview.frameIndex];
    }
  }

  void _openDetail(World world, GlossaryEntry entry) {
    world.componentsOf<eng.Text>().get(_detailTitle!)?.text = config.rtl
        ? entry.nameFa
        : entry.nameEn;
    world.componentsOf<eng.Text>().get(_detailBody!)?.text = config.rtl
        ? entry.detailFa
        : entry.detailEn;
    final stats = config.rtl ? entry.statsFa : entry.statsEn;
    final texts = world.componentsOf<eng.Text>();
    final sprites = world.componentsOf<eng.Sprite>();
    for (var i = 0; i < _statCells.length; i++) {
      final cell = _statCells[i];
      final entryOf = stats != null && i < stats.length
          ? stats.entries.elementAt(i)
          : null;
      texts.get(cell.label)?.text = entryOf?.key ?? '';
      texts.get(cell.value)?.text = entryOf?.value ?? '';
      final panelSprite = sprites.get(cell.panel);
      if (panelSprite != null) {
        panelSprite.scaleX = entryOf != null ? cell.baseScaleX : 0;
        panelSprite.scaleY = entryOf != null ? cell.baseScaleY : 0;
      }
    }
    _detailToken++;
    _loadDetailArt(world, entry, _detailToken);
    _dialog?.open();
  }

  /// Zeroes every stat cell's panel (see why in [_buildStatCell]: unlike the
  /// rest of the dialog's content, they aren't parked off-screen by
  /// `ModalDialog` itself when it closes, so this scene hides them by hand).
  void _hideStatCells(World world) {
    final sprites = world.componentsOf<eng.Sprite>();
    for (final cell in _statCells) {
      sprites.get(cell.panel)
        ?..scaleX = 0
        ..scaleY = 0;
    }
  }

  @override
  void update(double dt, World world) {
    _dialog?.update(dt);
    if (_dialog?.isOpen ?? false) _advancePreviews(dt, world);
    _fit.apply(world);
  }

  @override
  void handleTap(
    World world,
    eng.SceneController scenes,
    Offset worldPosition,
  ) {
    final d = _dialog;
    if (d != null && d.isOpen) {
      if (d.closesOn(worldPosition)) {
        d.close();
        _hideStatCells(world);
      }
      return;
    }
    if (_back.rect.contains(worldPosition)) return config.onBack(scenes);
    if (_prev.rect.contains(worldPosition) && _page > 0) {
      _page--;
      return _buildPage(world);
    }
    if (_next.rect.contains(worldPosition) && _page < _pages - 1) {
      _page++;
      return _buildPage(world);
    }
    for (final b in _catButtons) {
      if (!b.rect.contains(worldPosition) || b.id == _category) continue;
      _category = b.id;
      _page = 0;
      for (final other in _catButtons) {
        other.setStyle(world, other.id == _category ? 'primary' : 'disabled');
      }
      return _buildPage(world);
    }
    for (final e in _rowRects.entries) {
      if (e.key.contains(worldPosition)) return _openDetail(world, e.value);
    }
  }
}

/// One of the detail dialog's idle/attack/death preview slots. Its frames are
/// advanced by hand in [GlossaryScene._advancePreviews] (not
/// `eng.AnimationState`/`AnimationSystem`, which freeze with the rest of the
/// world once the dialog pauses it) so the clip keeps playing while open.
class _AnimPreview {
  _AnimPreview({
    required this.sprite,
    required this.label,
    required this.captionText,
  });

  final EntityId sprite;
  final EntityId label;

  /// This slot's caption ('Idle'/'Attack'/'Death' in the active language),
  /// reapplied every time an entry with art opens (cleared for one without).
  final String captionText;

  /// This clip's region names ('0', '1', ...); empty while nothing is
  /// loaded/playing (the entry has no art, or this clip doesn't exist for it).
  List<String> frames = const [];
  int frameIndex = 0;
  double elapsed = 0;

  /// Per-frame `Sprite.offsetX`/`offsetY`, same length and order as
  /// [frames] — keeps the character standing in one spot instead of
  /// sliding as its cropped-per-pose frames change (see `_ensureSheet`).
  List<double> offsetsX = const [];
  List<double> offsetsY = const [];
}

/// A loaded clip sheet: its frame count and each frame's measured
/// [eng.Pivot] (see `_ensureSheet`).
class _Sheet {
  const _Sheet({required this.frames, required this.pivots});

  final int frames;
  final List<eng.Pivot> pivots;
}

/// One cell of the detail dialog's stat table: a background panel plus a
/// label/value pair, built once and reused for every entry that opens.
class _StatCell {
  const _StatCell({
    required this.panel,
    required this.baseScaleX,
    required this.baseScaleY,
    required this.label,
    required this.value,
  });

  final EntityId panel;

  /// The panel's scale when shown; toggled to 0 to hide a cell an entry
  /// with fewer stats than the table has slots doesn't use.
  final double baseScaleX, baseScaleY;
  final EntityId label;
  final EntityId value;
}
