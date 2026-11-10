import 'package:zarvan_core/zarvan_core.dart';

import '../rendering/text.dart';

/// Spawns a centred text entity at world position ([x], [y]).
///
/// World space on purpose: positions are world units and the text scales with
/// the camera, so a layout authored for one world size stays put at any window
/// size (screen-space text positions are raw pixels). [fontFamily] and
/// [shadowArgb] style it (see `Text`). [align] makes [x] the
/// left or right edge instead of the centre; [rtl] forces text direction.
EntityId spawnWorldText(
  World world,
  double x,
  double y,
  String text, {
  required double fontSize,
  required int colorArgb,
  required int zIndex,
  double? maxWidth,
  bool? rtl,
  TextAlignment align = TextAlignment.center,
  String? fontFamily,
  int? shadowArgb,
}) {
  final id = world.spawn();
  world.componentsOf<Position>().set(id, Position(x, y));
  world.componentsOf<Text>().set(
    id,
    Text(
      text,
      fontSize: fontSize,
      colorArgb: colorArgb,
      align: align,
      screenSpace: false,
      zIndex: zIndex,
      maxWidth: maxWidth,
      rtl: rtl,
      fontFamily: fontFamily,
      shadowArgb: shadowArgb,
    ),
  );
  return id;
}
