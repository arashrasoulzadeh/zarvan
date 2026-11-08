import 'dart:ui' show Rect, Size;

import 'package:zarvan_core/zarvan_core.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart'
    show ModalDialog, Sprite, Text, TextAlignment;

/// Where and how the end-of-run popup (victory or defeat) is drawn.
class ResultPopupStyle {
  const ResultPopupStyle({
    this.rect = const Rect.fromLTRB(16, 60, 164, 256),
    this.bannerWidth = 118,
    this.bannerHeight = 36,
    this.rtl = false,
    this.frameCorner = 9,
    this.frameInset = 24,
    this.frameSource = const Size(96, 75),
    this.z = 150,
    this.blurSigma = 3,
  });

  /// The panel's rectangle in world units; the banner hangs from its top, the
  /// retry button is placed by `UpgradeLayout.retryY` near its bottom.
  final Rect rect;

  /// Size of the scroll banner that carries the title.
  final double bannerWidth;
  final double bannerHeight;

  /// Mirrors the reward row for a right-to-left language.
  final bool rtl;
  final double frameCorner;
  final double frameInset;
  final Size frameSource;

  /// Draw order of the panel (see [ModalDialog.z]); the retry button must sit
  /// above it (`UpgradeLayout.resultLift`).
  final int z;

  /// Blur of the fight behind the popup.
  final double blurSigma;
}

/// The end-of-run popup: a [ModalDialog] (so the fight behind it is blurred and
/// paused like any other dialog) with a scroll banner ("VICTORY" / "DEFEAT"),
/// a message, a reward row and room for the retry button. Built when [show] is
/// called, once per finished run; call [update] every frame for its fade.
class ResultPopup {
  ResultPopup(
    this.world, {
    required this.frameAtlasId,
    this.scrollAtlasId,
    this.currencyAtlasId,
    this.currencyCell = 32,
    this.goldIcon = 0,
    this.style = const ResultPopupStyle(),
  });

  final World world;

  /// Atlas of the panel frame (`panelFrameAtlas`).
  final String frameAtlasId;

  /// Atlas whose region `full` is the parchment banner (`ui_dialog_scroll`).
  final String? scrollAtlasId;

  /// Atlas of the currency icons, for the coin on the reward row.
  final String? currencyAtlasId;
  final double currencyCell;
  final int goldIcon;
  final ResultPopupStyle style;

  /// The underlying dialog, null until [show].
  ModalDialog? dialog;

  /// Whether [show] has been called.
  bool get visible => dialog != null;

  /// Fades the popup; call every frame with real time.
  void update(double dt) => dialog?.update(dt);

  /// Draws the popup (idempotent). [title] is on the banner, [message] the
  /// line under it, [detail] an optional smaller line, and [reward] the text
  /// next to the coin (e.g. `+2,480`); null leaves the reward row out.
  void show({
    required String title,
    required String message,
    String? detail,
    String? reward,
  }) {
    if (visible) return;
    final r = style.rect;
    final d = dialog = ModalDialog.spawn(
      world,
      rect: r,
      z: style.z,
      frameAtlasId: frameAtlasId,
      frameSource: style.frameSource,
      frameInset: style.frameInset,
      frameCorner: style.frameCorner,
      blurSigma: style.blurSigma,
      closable: false,
      rtl: style.rtl,
    );
    final cx = r.center.dx;
    final bannerY = r.top + style.bannerHeight / 2 + 4;
    if (scrollAtlasId != null) {
      final banner = world.spawn();
      world.componentsOf<Position>().set(banner, Position(cx, bannerY));
      world.componentsOf<Sprite>().set(
        banner,
        Sprite(
          scrollAtlasId!,
          'full',
          scaleX: style.bannerWidth / 128,
          scaleY: style.bannerHeight / 78,
          zIndex: style.z + 10,
        ),
      );
      d.add(banner);
    }
    d.addText(
      cx,
      bannerY,
      title,
      10,
      0xFF5A2E12,
      maxWidth: style.bannerWidth - 24,
    );
    d.addText(cx, r.top + 66, message, 6.4, 0xFFF6E7B4, maxWidth: r.width - 24);
    if (detail != null) {
      d.addText(cx, r.top + 82, detail, 5, 0xFFD8C48A, maxWidth: r.width - 24);
    }
    if (reward != null) {
      const iconSize = 14.0;
      final y = r.top + 104;
      final iconX = style.rtl ? cx + 20 : cx - 30;
      if (currencyAtlasId != null) {
        final icon = world.spawn();
        world.componentsOf<Position>().set(icon, Position(iconX, y));
        world.componentsOf<Sprite>().set(
          icon,
          Sprite(
            currencyAtlasId!,
            '$goldIcon',
            scaleX: iconSize / currencyCell,
            scaleY: iconSize / currencyCell,
            zIndex: style.z + 10,
          ),
        );
        d.add(icon);
      }
      final label = d.addText(
        style.rtl ? iconX - 11 : iconX + 11,
        y,
        reward,
        9,
        0xFFFFE38A,
        maxWidth: 60,
      );
      world.componentsOf<Text>().get(label)
        ?..align = style.rtl ? TextAlignment.right : TextAlignment.left
        // Digits and a plus sign read left to right even in Persian.
        ..rtl = false;
    }
    d.open();
  }
}
