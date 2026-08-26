import 'package:flutter/material.dart';

/// 按压时轻微缩放的反馈包装（emil 框架：scale 0.97，~140ms ease-out）。
///
/// 用 [Listener] 监听指针按下/抬起，可包裹任意已有可点击组件（IconButton、
/// FilledButton、卡片等），不会与它们内置的 InkWell 水波纹冲突。
/// 只动 transform（GPU 友好）；尊重系统「减少动画」设置。
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.scale = 0.97,
  });

  final Widget child;

  /// 按压时的目标缩放，默认 0.97（emil 推荐 0.95~0.98）。
  final double scale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _set(bool pressed) {
    if (_pressed != pressed) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1.0,
        duration: reduce ? Duration.zero : const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
