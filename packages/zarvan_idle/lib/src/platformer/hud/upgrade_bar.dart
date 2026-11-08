import 'dart:ui' show Offset, Rect, Size;

import 'package:zarvan_core/zarvan_core.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart'
    as eng
    show Sprite, SpriteAtlas, Text, TextAlignment;

import 'package:zarvan_flutter/zarvan_flutter.dart' show ModalDialog;

import '../progress/hero_progress.dart';
import '../progress/hero_skill.dart';
import 'wave_strings.dart';
import 'world_text.dart';

/// Where the upgrade buttons and the retry button sit (world units).
class UpgradeLayout {
  const UpgradeLayout({
    this.y = 296,
    this.left = 18,
    this.right = 162,
    this.buttonWidth = 44,
    this.coinsY = 64,
    this.skillY = 262,
    this.retryX = 90,
    this.retryY = 196,
    this.retryWidth = 70,
    this.iconSize = 13,
    this.iconOnly = false,
    this.menu = false,
    this.menuX = 90,
    this.menuY = 308,
    this.menuWidth = 40,
    this.dialog = const Rect.fromLTRB(10, 70, 170, 250),
    this.frameCorner = 9,
    this.frameInset = 24,
    this.frameSource = const Size(96, 75),
    this.menuFontScale = 0.75,
    this.rowHeight = 28,
    this.rowButtonWidth = 34,
    this.blurSigma = 3,
    this.menuButton = true,
    this.showCoins = true,
    this.skillsOnDock = false,
    this.dockIconSize = 20,
    this.resultLift = 0,
    this.darkDialog = false,
    this.rtl = false,
  });

  /// Centre line of the upgrade buttons, and the span they spread across.
  final double y;
  final double left;
  final double right;
  final double buttonWidth;

  /// Where the coin counter is drawn, and the centre line of the skill row.
  final double coinsY;
  final double skillY;

  /// The retry button's centre and width.
  final double retryX;
  final double retryY;
  final double retryWidth;

  /// Width and height of a button's icon (world units).
  final double iconSize;

  /// Draws buttons that have an icon as the icon alone, centred, with at most
  /// a small number under it (cost, seconds left, charge). Words such as the
  /// label, `Ready` or `MAX` are left out so the row reads in any language.
  final bool iconOnly;

  /// Keeps the upgrade buttons out of sight behind one small menu button
  /// (drawn at [menuX], [menuY], [menuWidth] wide); tapping it opens or closes
  /// the panel of upgrades at [y]. Skills stay on screen in their own row.
  final bool menu;
  final double menuX;
  final double menuY;
  final double menuWidth;

  /// With [menu], the dialog's rectangle in world units. Every button (skills
  /// at [skillY], upgrades at [y]) sits inside it, under a title.
  final Rect dialog;

  /// Edge of the frame's corner pieces in world units, and the width in source
  /// pixels of the corner/edge border of the frame image (see
  /// `panelFrameAtlas`).
  final double frameCorner;
  final double frameInset;

  /// Size in pixels of the frame image (`ui_panel_9slice` is 96 x 75). Part of
  /// the layout, not read from the loaded image, because a replayed scene
  /// reuses the loaded assets and never sees the image itself.
  final Size frameSource;

  /// Text scale of the buttons inside the dialog, which are narrower than the
  /// stand-alone ones.
  final double menuFontScale;

  /// In the dialog every upgrade is one row: icon, name with its level and a
  /// description, and a small buy button with the price. Rows start at [y] and
  /// are [rowHeight] apart; the button is [rowButtonWidth] wide.
  final double rowHeight;
  final double rowButtonWidth;

  /// Blur (world units) the game behind the dialog fades to while it is open;
  /// 0 leaves the game sharp under the veil.
  final double blurSigma;

  /// With [menu], whether the small button that opens the dialog is drawn.
  /// Without it the dialog opens only through [UpgradeBar.toggleMenu] (a tab
  /// bar calls it).
  final bool menuButton;

  /// Whether the "Coins N" label is drawn at [coinsY]; a currency bar shows
  /// the coins instead.
  final bool showCoins;

  /// With [menu], keeps the skills on screen as bare icons (with the cooldown
  /// or charge under them) in their own row at [skillY] instead of moving them
  /// into the dialog. Each icon is [dockIconSize] world units.
  final bool skillsOnDock;
  final double dockIconSize;

  /// Extra draw-order of the retry and ascend buttons, so they sit above a
  /// result popup drawn behind them.
  final int resultLift;

  /// Draws the dialog as a dark panel with light text (the frame image darkened
  /// by a tint) instead of the parchment look.
  final bool darkDialog;

  /// Mirrors the dialog's rows (icon and text on the right, buy button on the
  /// left, close button top-left) for a right-to-left language.
  final bool rtl;
}

/// The `ui_button_atlas` sheet: cells of [cellWidth] x [cellHeight] with
/// [gap] between them; one row per style, the first column is the normal state.
class ButtonSheet {
  const ButtonSheet._();

  static const cellWidth = 96.0;
  static const cellHeight = 44.0;
  static const gap = 4.0;

  /// Row names in sheet order.
  static const styles = ['primary', 'secondary', 'disabled'];

  /// Region rectangles by style name (normal state).
  static Map<String, Rect> regions() => {
    for (var row = 0; row < styles.length; row++)
      styles[row]: Rect.fromLTWH(gap, row * cellHeight, cellWidth, cellHeight),
  };
}

/// The in-world upgrade buttons, the coin counter and the retry button of a
/// wave-combat scene. Buttons are ordinary entities (a sprite and two labels);
/// [hit] maps a tap to what it pressed.
class UpgradeBar {
  UpgradeBar.spawn(
    World world, {
    required this.atlasId,
    this.iconAtlasId,
    this.iconCellSize = 32,
    this.frameAtlasId,
    required this.upgrades,
    required this.progress,
    this.layout = const UpgradeLayout(),
    this.skills = const [],
    this.strings = const WaveStrings(),
  }) {
    final span = layout.right - layout.left;
    if (layout.menu && (upgrades.isNotEmpty || skills.isNotEmpty)) {
      final r = layout.dialog;
      _dialog = ModalDialog.spawn(
        world,
        rect: r,
        z: _sprite + _dialogLift - 10,
        frameAtlasId: frameAtlasId,
        frameSource: layout.frameSource,
        frameInset: layout.frameInset,
        frameCorner: layout.frameCorner,
        dark: layout.darkDialog,
        blurSigma: layout.blurSigma,
        title: strings.upgradesMenu,
        rtl: layout.rtl,
      );
    }
    for (var i = 0; i < upgrades.length; i++) {
      if (layout.menu) {
        _buttons.add(_spawnRow(world, i));
        continue;
      }
      final cx = layout.left + span * (i + 0.5) / upgrades.length;
      _buttons.add(
        _spawnButton(
          world,
          cx,
          layout.y,
          layout.buttonWidth,
          icon: upgrades[i].icon,
          iconOnly: layout.iconOnly,
        ),
      );
    }
    for (var i = 0; i < skills.length; i++) {
      final cx = layout.left + span * (i + 0.5) / skills.length;
      final b = _dockSkills
          ? _spawnBare(
              world,
              cx,
              layout.skillY,
              span / skills.length,
              skills[i].icon,
            )
          : _spawnButton(
              world,
              cx,
              layout.skillY,
              layout.menu ? span / skills.length * 0.92 : layout.buttonWidth,
              icon: skills[i].icon,
              fontScale: layout.menu ? layout.menuFontScale : 1,
              iconOnly: !layout.menu && layout.iconOnly,
              lift: layout.menu ? _dialogLift : 0,
            );
      _skillButtons.add(b);
      if (layout.menu && !_dockSkills) _adopt(b);
    }
    if (layout.showCoins) {
      _coins = _text(world, 90, layout.coinsY, 5.2, 0xFFFFE7A0);
    }
    if (_dialog != null && layout.menuButton) {
      final m = _spawnButton(
        world,
        layout.menuX,
        layout.menuY,
        layout.menuWidth,
        iconOnly: false,
      );
      _menu = m;
      world.componentsOf<eng.Text>().get(m.top)?.text = strings.upgradesMenu;
      world.componentsOf<eng.Text>().get(m.bottom)?.text = '';
      world.componentsOf<eng.Sprite>().get(m.sprite)?.region = 'secondary';
      // The label is the only text, so it sits in the middle of the button.
      world.componentsOf<Position>().get(m.top)?.y = layout.menuY;
    }
    sync(world);
  }

  static const _sprite = 120;
  static const _label = 125;

  ModalDialog? _dialog;

  bool get _dockSkills => layout.menu && layout.skillsOnDock;

  final String atlasId;

  /// Atlas of the icon strip (regions `0`, `1`, ...), or null for no icons.
  final String? iconAtlasId;

  /// Atlas of the dialog frame (see `panelFrameAtlas`), or null for a plain
  /// dialog with no art.
  final String? frameAtlasId;

  /// Edge of one icon frame in the strip, in pixels.
  final double iconCellSize;
  final List<HeroUpgrade> upgrades;
  final HeroProgress progress;
  final UpgradeLayout layout;

  /// Active skills drawn as a second row of buttons above the upgrades.
  final List<HeroSkill> skills;
  final WaveStrings strings;

  final _buttons = <_Button>[];
  final _skillButtons = <_Button>[];
  _Button? _ascend;
  EntityId? _coins;
  _Button? _retry;
  _Button? _menu;
  final _rowTitles = <EntityId>[];

  /// Draw-order boost of the dialog's contents, so it covers the captions and
  /// damage numbers of the fight behind it.
  static const _dialogLift = 40;

  /// What [hit] returns for the retry and ascend buttons, and the prefix of a
  /// skill's id.
  static const retryAction = 'retry';
  static const ascendAction = 'ascend';
  static const skillPrefix = 'skill:';

  /// What [hit] returns for the menu button (see [UpgradeLayout.menu]).
  static const menuAction = 'menu';

  /// One upgrade of the dialog: icon and text on the left, a small buy button
  /// with the price on the right; a tap anywhere on the row buys.
  _Button _spawnRow(World world, int i) {
    final u = upgrades[i];
    final r = layout.dialog;
    final y = layout.y + i * layout.rowHeight;
    final bw = layout.rowButtonWidth;
    final rtl = layout.rtl;
    double mx(double x) => rtl ? r.left + r.right - x : x;
    final button = _spawnButton(
      world,
      mx(r.right - 8 - bw / 2),
      y,
      bw,
      fontScale: layout.menuFontScale,
      iconOnly: false,
      lift: _dialogLift,
    );
    // Only the price is written, so it sits in the middle of the button.
    world.componentsOf<Position>().get(button.top)?.y = y;
    if (iconAtlasId != null && u.icon != null) {
      final icon = world.spawn();
      final scale = layout.iconSize / iconCellSize;
      world.componentsOf<Position>().set(icon, Position(mx(r.left + 16), y));
      world.componentsOf<eng.Sprite>().set(
        icon,
        eng.Sprite(
          iconAtlasId!,
          '${u.icon}',
          scaleX: scale,
          scaleY: scale,
          zIndex: _label + _dialogLift,
        ),
      );
      _dialog?.add(icon);
    }
    final textLeft = r.left + 30;
    final width = r.right - 8 - bw - 6 - textLeft;
    // Mirrored, the text hangs from its right edge and the box is flipped.
    final textX = rtl ? mx(textLeft) : textLeft;
    final title = _text(
      world,
      textX,
      y - 5,
      4.6,
      layout.darkDialog ? 0xFFFFE7A0 : 0xFF3A2410,
      lift: _dialogLift,
    );
    final desc = _text(
      world,
      textX,
      y + 4,
      3.5,
      layout.darkDialog ? 0xFFD8C48A : 0xFF6A5034,
      lift: _dialogLift,
    );
    final texts = world.componentsOf<eng.Text>();
    for (final e in [title, desc]) {
      texts.get(e)
        ?..align = rtl ? eng.TextAlignment.right : eng.TextAlignment.left
        ..rtl = rtl ? true : null
        ..maxWidth = width;
    }
    texts.get(desc)?.text = u.description ?? '';
    _rowTitles.add(title);
    _dialog
      ?..add(title)
      ..add(desc);
    _adopt(button);
    return _Button(
      button.sprite,
      button.top,
      button.bottom,
      Rect.fromLTRB(
        r.left + 4,
        y - layout.rowHeight / 2,
        r.right - 4,
        y + layout.rowHeight / 2,
      ),
    );
  }

  /// Hands a button's entities to the dialog so they hide, fade and blur-cover
  /// with it.
  void _adopt(_Button b) {
    final d = _dialog;
    if (d == null) return;
    d
      ..add(b.sprite)
      ..add(b.top)
      ..add(b.bottom);
    if (b.icon != null) d.add(b.icon!);
  }

  /// A skill drawn as its icon alone on the dock (no button art): the number
  /// under it is the cooldown or charge, and a dimmed icon means not ready.
  _Button _spawnBare(
    World world,
    double cx,
    double cy,
    double width,
    int? icon,
  ) {
    final size = layout.dockIconSize;
    EntityId? iconSprite;
    if (icon != null && iconAtlasId != null) {
      iconSprite = world.spawn();
      final s = size / iconCellSize;
      world.componentsOf<Position>().set(iconSprite, Position(cx, cy - 3));
      world.componentsOf<eng.Sprite>().set(
        iconSprite,
        eng.Sprite(iconAtlasId!, '$icon', scaleX: s, scaleY: s, zIndex: _label),
      );
    }
    return _Button(
      world.spawn(),
      _text(world, cx, cy - 3, 4.6, 0xFFFFFFFF),
      _text(world, cx, cy + size * 0.5 + 1, 4.4, 0xFFFFE7A0),
      Rect.fromCenter(center: Offset(cx, cy), width: width, height: size * 1.7),
      icon: iconSprite,
      iconOnly: true,
      bare: true,
    );
  }

  _Button _spawnButton(
    World world,
    double cx,
    double cy,
    double width, {
    double fontScale = 1,
    int? icon,
    bool? iconOnly,
    int lift = 0,
  }) {
    final scale = width / ButtonSheet.cellWidth;
    final hasIcon = icon != null && iconAtlasId != null;
    // Text moves right so the icon and the label share the button.
    final compact = hasIcon && (iconOnly ?? layout.iconOnly);
    final textX = hasIcon && !compact ? cx + width * 0.14 : cx;
    final sprite = world.spawn();
    world.componentsOf<Position>().set(sprite, Position(cx, cy));
    world.componentsOf<eng.Sprite>().set(
      sprite,
      eng.Sprite(
        atlasId,
        'primary',
        scaleX: scale,
        scaleY: scale,
        zIndex: _sprite + lift,
      ),
    );
    final height = ButtonSheet.cellHeight * scale;
    EntityId? iconSprite;
    if (hasIcon) {
      iconSprite = world.spawn();
      final s = layout.iconSize / iconCellSize;
      world.componentsOf<Position>().set(
        iconSprite,
        Position(
          compact ? cx : cx - width * 0.3,
          compact ? cy - height * 0.1 : cy,
        ),
      );
      world.componentsOf<eng.Sprite>().set(
        iconSprite,
        eng.Sprite(
          iconAtlasId!,
          '$icon',
          scaleX: s,
          scaleY: s,
          zIndex: _label + lift,
        ),
      );
    }
    return _Button(
      sprite,
      _text(
        world,
        textX,
        cy - height * 0.14,
        4.6 * fontScale,
        0xFFFFFFFF,
        lift: lift,
      ),
      _text(
        world,
        textX,
        compact ? cy + height * 0.3 : cy + height * 0.16,
        4.6 * fontScale,
        0xFFFFE7A0,
        lift: lift,
      ),
      Rect.fromCenter(center: Offset(cx, cy), width: width, height: height),
      icon: iconSprite,
      iconOnly: compact,
    );
  }

  EntityId _text(
    World world,
    double x,
    double y,
    double size,
    int color, {
    int lift = 0,
  }) => spawnWorldText(
    world,
    x,
    y,
    '',
    fontSize: size,
    colorArgb: color,
    zIndex: _label + lift,
  );

  void _set(World world, _Button b, String region, String top, String bottom) {
    if (b.bare) {
      final sprite = b.icon == null
          ? null
          : world.componentsOf<eng.Sprite>().get(b.icon!);
      sprite?.tintArgb = region == 'disabled' ? 0x99303030 : null;
      world.componentsOf<eng.Text>().get(b.top)?.text = '';
      world.componentsOf<eng.Text>().get(b.bottom)?.text = bottom;
      return;
    }
    world.componentsOf<eng.Sprite>().get(b.sprite)?.region = region;
    final iconOnly = b.iconOnly;
    world.componentsOf<eng.Text>().get(b.top)?.text = iconOnly ? '' : top;
    world.componentsOf<eng.Text>().get(b.bottom)?.text =
        iconOnly && !bottom.contains(RegExp(r'\d')) ? '' : bottom;
  }

  /// Refreshes labels and styles from [progress]: affordable upgrades look
  /// active, the rest disabled, a maxed one reads MAX.
  void sync(World world) {
    final coins = _coins;
    if (coins != null) {
      world.componentsOf<eng.Text>().get(coins)?.text = strings.coinsLabel(
        progress.coins,
      );
    }
    for (var i = 0; i < upgrades.length; i++) {
      final u = upgrades[i];
      final level = progress.levelOf(u);
      if (layout.menu) {
        final b = _buttons[i];
        final texts = world.componentsOf<eng.Text>();
        texts.get(_rowTitles[i])?.text = '${u.label}  $level';
        texts.get(b.top)?.text = progress.isMaxed(u)
            ? strings.max
            : '${progress.costOf(u)}';
        texts.get(b.bottom)?.text = '';
        world
            .componentsOf<eng.Sprite>()
            .get(b.sprite)
            ?.region = progress.isMaxed(u)
            ? 'secondary'
            : progress.canBuy(u)
            ? 'primary'
            : 'disabled';
        continue;
      }
      if (progress.isMaxed(u)) {
        _set(world, _buttons[i], 'secondary', '${u.label} $level', strings.max);
      } else {
        _set(
          world,
          _buttons[i],
          progress.canBuy(u) ? 'primary' : 'disabled',
          '${u.label} $level',
          '${progress.costOf(u)}',
        );
      }
    }
  }

  /// Refreshes the skill buttons: ready ones are active, those cooling down
  /// show the seconds left.
  void syncSkills(
    World world,
    SkillCooldowns cooldowns, {
    double ultimate = 0,
  }) {
    for (var i = 0; i < skills.length; i++) {
      final s = skills[i];
      if (s.ultimate) {
        // Charged by play, not by a timer: show the meter.
        final full = ultimate >= 1;
        _set(
          world,
          _skillButtons[i],
          full ? 'primary' : 'disabled',
          s.label,
          full ? strings.ready : '${(ultimate * 100).floor()}%',
        );
        continue;
      }
      final left = cooldowns.remaining(s);
      _set(
        world,
        _skillButtons[i],
        left > 0 ? 'disabled' : 'primary',
        s.label,
        left > 0 ? '${left.ceil()}s' : strings.ready,
      );
    }
  }

  /// Shows the ascend (prestige) button under the retry one (idempotent).
  void showAscend(World world, {String? label}) {
    if (_ascend != null) return;
    final b = _spawnButton(
      world,
      layout.retryX,
      layout.retryY + layout.retryWidth * 0.5,
      layout.retryWidth,
      fontScale: 1.5,
      lift: layout.resultLift,
    );
    _ascend = b;
    _set(world, b, 'secondary', label ?? strings.ascend, '');
    world.componentsOf<Position>().get(b.top)?.y = b.rect.center.dy;
  }

  /// Shows the retry button (idempotent).
  void showRetry(World world, {String? label}) {
    if (_retry != null) return;
    final b = _spawnButton(
      world,
      layout.retryX,
      layout.retryY,
      layout.retryWidth,
      fontScale: 1.5,
      lift: layout.resultLift,
    );
    _retry = b;
    world.componentsOf<eng.Text>().get(b.bottom)?.text = '';
    _set(world, b, 'primary', label ?? strings.retry, '');
    world.componentsOf<Position>().get(b.top)?.y = b.rect.center.dy;
  }

  bool get retryVisible => _retry != null;

  bool get ascendVisible => _ascend != null;

  /// What a tap at [worldPosition] pressed: an upgrade's `id`, [retryAction],
  /// or null for nothing.
  String? hit(Offset worldPosition) {
    final retry = _retry;
    if (retry != null && retry.rect.contains(worldPosition)) return retryAction;
    final ascend = _ascend;
    if (ascend != null && ascend.rect.contains(worldPosition)) {
      return ascendAction;
    }
    final menu = _menu;
    if (menu != null && menu.rect.contains(worldPosition)) return menuAction;
    final open = dialogOpen;
    if (_dockSkills && !open) {
      for (var i = 0; i < _skillButtons.length; i++) {
        if (_skillButtons[i].rect.contains(worldPosition)) {
          return '$skillPrefix${skills[i].id}';
        }
      }
    }
    if (layout.menu && !open) return null;
    // Open: the X and any tap outside the dialog close it.
    if (open && _dialog!.closesOn(worldPosition)) return menuAction;
    for (var i = 0; i < _skillButtons.length && !_dockSkills; i++) {
      if (_skillButtons[i].rect.contains(worldPosition)) {
        return '$skillPrefix${skills[i].id}';
      }
    }
    for (var i = 0; i < _buttons.length; i++) {
      if (_buttons[i].rect.contains(worldPosition)) return upgrades[i].id;
    }
    return null;
  }

  /// Whether the dialog is showing (always true without a menu).
  bool get menuOpen => !layout.menu || dialogOpen;

  /// Whether a [UpgradeLayout.menu] dialog is open; the engine's
  /// [ModalDialog] has then paused the world and blurred the fight.
  bool get dialogOpen => _dialog?.isOpen ?? false;

  /// The dialog of a [UpgradeLayout.menu] bar, or null without one.
  ModalDialog? get dialog => _dialog;

  /// Opens or closes the dialog of a [UpgradeLayout.menu] bar. It fades in
  /// and out; call [update] every frame for that.
  void toggleMenu(World world) => _dialog?.toggle();

  /// Closes the dialog if it is open.
  void closeMenu() => _dialog?.close();

  /// How long the dialog and the veil behind it take to fade.
  static const fadeSeconds = ModalDialog.fadeSeconds;

  /// Moves the fade along (real time, so it runs while the game is paused).
  void update(World world, double dt) => _dialog?.update(dt);

  /// The atlas to register under [atlasId] for a loaded sheet image.
  static eng.SpriteAtlas atlasFor(eng.SpriteAtlas sheet) =>
      eng.SpriteAtlas(sheet.image, ButtonSheet.regions());
}

class _Button {
  _Button(
    this.sprite,
    this.top,
    this.bottom,
    this.rect, {
    this.icon,
    this.iconOnly = false,
    this.bare = false,
  });

  /// A dock skill: no button sprite, only an icon and a number.
  final bool bare;

  /// Whether only the icon (and a number) is drawn; see [UpgradeLayout.iconOnly].
  final bool iconOnly;
  final EntityId sprite;

  /// The icon sprite, if this button has one.
  final EntityId? icon;
  final EntityId top;
  final EntityId bottom;
  final Rect rect;
}
