import 'package:flutter/material.dart';

import 'motion.dart';

/// 统一的页面过渡：淡入 + 轻微上滑（emil 框架：低频操作标准动画）。
///
/// 进入 250ms、退出 150ms（退出快于进入）。系统开启「减少动画」时只保留
/// 极短的淡入、去掉位移。
Route<T> fadeSlideRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final reduce = MediaQuery.disableAnimationsOf(context);
      if (reduce) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: AppMotion.easeOut),
          child: child,
        );
      }
      final curve = CurvedAnimation(
        parent: animation,
        curve: AppMotion.easeOut,
        reverseCurve: AppMotion.easeInOut,
      );
      return FadeTransition(
        opacity: curve,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.018),
            end: Offset.zero,
          ).animate(curve),
          child: child,
        ),
      );
    },
  );
}
