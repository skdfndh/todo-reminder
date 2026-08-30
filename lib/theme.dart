import 'package:flutter/material.dart';

import 'models/task.dart';
import 'utils/motion.dart';

/// 「暖纸手账」配色。
class AppColors {
  AppColors._();

  static const paper = Color(0xFFF6F3EE); // 页面底色
  static const surface = Color(0xFFFFFFFF); // 卡片表面
  static const ink = Color(0xFF26241F); // 主文字/主色
  static const muted = Color(0xFF8A857C); // 次要文字
  static const line = Color(0xFFE8E3DA); // 描边

  static const high = Color(0xFFE5484D); // 重要性·高
  static const medium = Color(0xFFE8890C); // 重要性·中
  static const low = Color(0xFF5B7A9D); // 重要性·低

  static const highTint = Color(0xFFFDEAEC);
  static const mediumTint = Color(0xFFFCF1E0);
  static const lowTint = Color(0xFFEAF0F6);
  static const overdueTint = Color(0xFFF0EEE9);
}

/// 重要性主色。
Color priorityColor(Priority p) => switch (p) {
  Priority.high => AppColors.high,
  Priority.medium => AppColors.medium,
  Priority.low => AppColors.low,
};

/// 重要性淡色底（框内涂色）。
Color priorityTint(Priority p) => switch (p) {
  Priority.high => AppColors.highTint,
  Priority.medium => AppColors.mediumTint,
  Priority.low => AppColors.lowTint,
};

ThemeData buildAppTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.ink,
        brightness: Brightness.light,
        surface: AppColors.surface,
      ).copyWith(
        primary: AppColors.ink,
        onPrimary: AppColors.surface,
        onSurface: AppColors.ink,
        onSurfaceVariant: AppColors.muted,
        outline: AppColors.line,
        surface: AppColors.paper,
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.paper,
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        animationDuration: AppMotion.pressDuration,
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        animationDuration: AppMotion.pressDuration,
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ),
  );
}

ThemeData buildDarkAppTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.high,
        brightness: Brightness.dark,
      ).copyWith(
        primary: const Color(0xFFF3EEE7),
        onPrimary: const Color(0xFF201E1A),
        surface: const Color(0xFF201E1A),
        onSurface: const Color(0xFFF3EEE7),
        onSurfaceVariant: const Color(0xFFCFC7BC),
        outline: const Color(0xFF514C45),
        surfaceContainerHighest: const Color(0xFF2B2925),
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFF201E1A),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(animationDuration: AppMotion.pressDuration),
    ),
  );
}
