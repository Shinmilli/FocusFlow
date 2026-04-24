import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const seed = Color(0xFF2D6A4F);
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(centerTitle: true),
  );
}
