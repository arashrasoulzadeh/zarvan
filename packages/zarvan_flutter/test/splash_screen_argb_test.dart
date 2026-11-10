import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart';

void main() {
  test('SplashConfig.fromArgb maps integers to colours and keeps the rest', () {
    final c = SplashConfig.fromArgb(
      title: 'Adad Bazi',
      backgroundArgb: 0xFF101820,
      accentArgb: 0xFFFF8A1F,
      showEngineVersion: false,
      minDuration: const Duration(milliseconds: 800),
    );
    expect(c.title, 'Adad Bazi');
    expect(c.backgroundColor, const Color(0xFF101820));
    expect(c.accentColor, const Color(0xFFFF8A1F));
    expect(c.showEngineVersion, isFalse);
    expect(c.minDuration, const Duration(milliseconds: 800));
    expect(SplashConfig.fromArgb().backgroundColor, isNull);
    expect(SplashConfig.fromArgb().logo, isNull);
    final withLogo = SplashConfig.fromArgb(
      logoAsset: 'assets/branding/logo.png',
    );
    expect(withLogo.logo, isA<AssetImage>());
    expect(
      (withLogo.logo! as AssetImage).assetName,
      'assets/branding/logo.png',
    );
  });
}
