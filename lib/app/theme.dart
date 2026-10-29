import 'package:flutter/material.dart';

/// Material 3 主题，桌面端收紧一点密度。
ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF5E7A4B),
    brightness: brightness,
  );
  return ThemeData(
    colorScheme: scheme,
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
}
