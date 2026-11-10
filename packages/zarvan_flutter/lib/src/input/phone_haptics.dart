import 'package:flutter/services.dart' show HapticFeedback, MethodChannel;

/// How strong a vibration the phone's motor should play.
enum HapticStrength { light, medium, heavy }

/// The phone's vibration motor behind one call, so a game that imports no
/// Flutter itself (like `adad_bazi`, whose `lib/` is lint-checked for that)
/// can still buzz. Where there is no motor (web, desktop) the platform simply
/// ignores the request.
class PhoneHaptics {
  const PhoneHaptics();

  static const _native = MethodChannel('zarvan_flutter/haptics');

  /// Plays one vibration of [strength]. Never throws: a missing motor must
  /// not stop a game.
  void buzz(HapticStrength strength) {
    try {
      _native.invokeMethod<void>('buzz', strength.name).catchError((_) {});
      switch (strength) {
        case HapticStrength.light:
          HapticFeedback.selectionClick();
        case HapticStrength.medium:
          HapticFeedback.mediumImpact();
        case HapticStrength.heavy:
          HapticFeedback.heavyImpact();
      }
    } catch (_) {}
  }
}
