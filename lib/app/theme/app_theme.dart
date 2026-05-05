import 'package:flutter/material.dart';

/// GmarketSans가 아직 잡히기 전·일부 글리프에서도 한글이 깨지지 않도록 시스템 한글 폰트를 둠.
const List<String> kKoreanFontFamilyFallback = [
  'Malgun Gothic',
  'Apple SD Gothic Neo',
  'Noto Sans CJK KR',
  'Noto Sans KR',
  'Roboto',
];

ThemeData buildAppTheme() {
  const primary = Color(0xFF3D8EF9);
  final scheme = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: Brightness.light,
  ).copyWith(primary: primary);

  final textBase = ThemeData(useMaterial3: true, colorScheme: scheme).textTheme;

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'GmarketSans',
    fontFamilyFallback: kKoreanFontFamilyFallback,
    textTheme: textBase.apply(
      fontFamily: 'GmarketSans',
      fontFamilyFallback: kKoreanFontFamilyFallback,
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
    appBarTheme: AppBarTheme(
      centerTitle: true,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 1,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 6,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
    ),
  );
}
