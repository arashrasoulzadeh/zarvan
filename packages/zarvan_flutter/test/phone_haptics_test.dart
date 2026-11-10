import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('each strength asks the platform for its own haptic type', () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            calls.add(call.arguments as String);
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    const motor = PhoneHaptics();
    motor.buzz(HapticStrength.light);
    motor.buzz(HapticStrength.medium);
    motor.buzz(HapticStrength.heavy);
    await Future<void>.delayed(Duration.zero);
    expect(calls, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.mediumImpact',
      'HapticFeedbackType.heavyImpact',
    ]);
  });
}
