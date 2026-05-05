import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/focus_flow_app.dart';
import 'core/timezone/app_timezones.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initializeAppTimeZones();
  await _preloadBundledFonts();
  runApp(
    const ProviderScope(
      child: FocusFlowApp(),
    ),
  );
}

/// 첫 프레임 전에 번들 폰트를 읽어 두어, 초기 레이아웃에서 한글이 □로 잠깐 보이는 현상을 줄임.
Future<void> _preloadBundledFonts() async {
  await Future.wait([
    rootBundle.load('assets/fonts/GmarketSansTTFLight.ttf'),
    rootBundle.load('assets/fonts/GmarketSansTTFMedium.ttf'),
    rootBundle.load('assets/fonts/GmarketSansTTFBold.ttf'),
  ]);
}
