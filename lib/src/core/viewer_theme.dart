import 'package:flutter/material.dart';

/// 查看器视觉与动画参数。
///
/// 通过 [MediaViewer.theme] 传入以覆盖默认。
class ViewerTheme {
  const ViewerTheme({
    this.backgroundColor = Colors.black,
    this.infoBackgroundColor,
    this.infoBorderRadius = const BorderRadius.vertical(
      top: Radius.circular(14),
    ),
    this.dragHandleColor,
    this.dragHandleSize = const Size(36, 4),
    this.infoShowDuration = const Duration(milliseconds: 320),
    this.infoHideDuration = const Duration(milliseconds: 260),
    this.dismissSnapBackDuration = const Duration(milliseconds: 300),
    this.infoShowCurve = Curves.easeOutCubic,
    this.infoHideCurve = Curves.easeInOutCubic,
    this.dismissSnapBackCurve = Curves.easeOutCubic,
  });

  // ── 背景 ───────────────────────────────────────────────────────────────────

  /// 查看器背景色；下拉关闭时透明度升高，便于透出下层路由。
  final Color backgroundColor;

  // ── 信息面板 ───────────────────────────────────────────────────────────────

  /// 信息面板背景色；为 null 时使用 [effectiveInfoBackground] 回退逻辑。
  final Color? infoBackgroundColor;

  /// 信息面板顶部圆角。
  final BorderRadius infoBorderRadius;

  /// 顶部拖动条颜色。
  final Color? dragHandleColor;

  /// 拖动条宽高。
  final Size dragHandleSize;

  // ── 动画时长 ───────────────────────────────────────────────────────────────

  /// 信息面板展开动画时长。
  final Duration infoShowDuration;

  /// 信息面板收起动画时长。
  final Duration infoHideDuration;

  /// 未达关闭阈值时下拉回弹动画时长。
  final Duration dismissSnapBackDuration;

  // ── 动画曲线 ───────────────────────────────────────────────────────────────

  /// 信息面板展开曲线。
  final Curve infoShowCurve;

  /// 信息面板收起曲线。
  final Curve infoHideCurve;

  /// 下拉回弹曲线。
  final Curve dismissSnapBackCurve;

  // ── 派生色 ─────────────────────────────────────────────────────────────────

  /// 实际使用的信息面板背景：若未指定 [infoBackgroundColor] 则用主题 `surface`。
  Color effectiveInfoBackground(BuildContext context) {
    if (infoBackgroundColor != null) return infoBackgroundColor!;
    final surface = Theme.of(context).colorScheme.surface;
    return surface;
  }

  /// 拖动条实际颜色。
  Color effectiveDragHandleColor(BuildContext context) {
    return dragHandleColor ??
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3);
  }

  ViewerTheme copyWith({
    Color? backgroundColor,
    Color? infoBackgroundColor,
    BorderRadius? infoBorderRadius,
    Color? dragHandleColor,
    Size? dragHandleSize,
    Duration? infoShowDuration,
    Duration? infoHideDuration,
    Duration? dismissSnapBackDuration,
    Curve? infoShowCurve,
    Curve? infoHideCurve,
    Curve? dismissSnapBackCurve,
  }) {
    return ViewerTheme(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      infoBackgroundColor: infoBackgroundColor ?? this.infoBackgroundColor,
      infoBorderRadius: infoBorderRadius ?? this.infoBorderRadius,
      dragHandleColor: dragHandleColor ?? this.dragHandleColor,
      dragHandleSize: dragHandleSize ?? this.dragHandleSize,
      infoShowDuration: infoShowDuration ?? this.infoShowDuration,
      infoHideDuration: infoHideDuration ?? this.infoHideDuration,
      dismissSnapBackDuration:
          dismissSnapBackDuration ?? this.dismissSnapBackDuration,
      infoShowCurve: infoShowCurve ?? this.infoShowCurve,
      infoHideCurve: infoHideCurve ?? this.infoHideCurve,
      dismissSnapBackCurve: dismissSnapBackCurve ?? this.dismissSnapBackCurve,
    );
  }
}
