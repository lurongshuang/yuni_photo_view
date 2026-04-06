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
    this.mediaCardInset = EdgeInsets.zero,
    this.mediaCardBorderRadius = 0,
    this.mediaCardAnimationDuration = const Duration(milliseconds: 280),
    this.mediaCardAnimationCurve = Curves.easeInOutCubic,
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

  // ── 主内容「卡片」外框（相册风格）──────────────────────────────────────────

  /// 顶栏、底栏均显示且当前页未缩放时，主内容区相对视口的外边距。
  ///
  /// 与 [mediaCardBorderRadius] 同时为默认零时，不启用该效果。
  ///
  /// **实现位置**：在 PhotoView 缩放层**之外**包裹，边距与圆角不随双指缩放变形。
  final EdgeInsets mediaCardInset;

  /// 与 [mediaCardInset] 同时生效：圆角作用在 [ViewerMediaCoverFrame] 绘制的**图片外接矩形**上，
  /// 而非整段视口高度（避免「整屏灰块套小图」）。
  ///
  /// 自定义媒体请用 [MediaCardChromeScope] 读取插值半径后自行 [ClipRRect]。
  final double mediaCardBorderRadius;

  /// 在「卡片模式」与「铺满视口」之间过渡的时长。
  ///
  /// 当用户隐藏顶底栏或内容进入放大状态（[ViewerPageController.isZoomed]）时，
  /// 边距与圆角动画归零；恢复栏显且缩放回默认后还原。
  final Duration mediaCardAnimationDuration;

  /// [mediaCardAnimationDuration] 使用的曲线。
  final Curve mediaCardAnimationCurve;

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
    EdgeInsets? mediaCardInset,
    double? mediaCardBorderRadius,
    Duration? mediaCardAnimationDuration,
    Curve? mediaCardAnimationCurve,
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
      mediaCardInset: mediaCardInset ?? this.mediaCardInset,
      mediaCardBorderRadius:
          mediaCardBorderRadius ?? this.mediaCardBorderRadius,
      mediaCardAnimationDuration:
          mediaCardAnimationDuration ?? this.mediaCardAnimationDuration,
      mediaCardAnimationCurve:
          mediaCardAnimationCurve ?? this.mediaCardAnimationCurve,
    );
  }
}
