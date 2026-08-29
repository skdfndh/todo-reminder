import 'package:flutter/material.dart';

/// 全局交互动效节奏：快速反馈、低频页面切换稍留余韵。
class AppMotion {
  AppMotion._();

  static const easeOut = Cubic(0.16, 1, 0.3, 1);
  static const easeInOut = Cubic(0.65, 0, 0.35, 1);
  static const pressDuration = Duration(milliseconds: 120);
  static const stateDuration = Duration(milliseconds: 160);
  static const sheetDuration = Duration(milliseconds: 220);

  static const sheetStyle = AnimationStyle(
    duration: sheetDuration,
    reverseDuration: Duration(milliseconds: 160),
  );
}
