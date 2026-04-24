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
    this.mediaCardInsetTop = 0,
    this.mediaCardInsetBottom = 0,
    this.mediaCardInsetLeft = 0,
    this.mediaCardInsetRight = 0,
    this.mediaCardBorderRadius = 0,
    this.mediaCardAnimationDuration = const Duration(milliseconds: 280),
    this.mediaCardAnimationCurve = Curves.easeInOutCubic,
    this.barsToggleDuration = const Duration(milliseconds: 200),
    this.barsToggleCurve = Curves.easeOutCubic,
    this.zoomDuration = const Duration(milliseconds: 250),
    this.zoomCurve = Curves.easeInOutCubic,
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

  /// 顶栏、底栏均显示且当前页未缩放时，主内容区距视口顶部的间距。
  final double mediaCardInsetTop;

  /// 顶栏、底栏均显示且当前页未缩放时，主内容区距视口底部的间距。
  final double mediaCardInsetBottom;

  /// 顶栏、底栏均显示且当前页未缩放时，主内容区距视口左侧的间距。
  final double mediaCardInsetLeft;

  /// 顶栏、底栏均显示且当前页未缩放时，主内容区距视口右侧的间距。
  final double mediaCardInsetRight;

  /// 由四个方向间距合成的 [EdgeInsets]，供内部动画使用。
  EdgeInsets get mediaCardInset => EdgeInsets.fromLTRB(
        mediaCardInsetLeft,
        mediaCardInsetTop,
        mediaCardInsetRight,
        mediaCardInsetBottom,
      );

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

  /// 单击内容切换顶栏、底栏显隐的时长。
  final Duration barsToggleDuration;

  /// [barsToggleDuration] 使用的曲线。
  final Curve barsToggleCurve;

  /// 双击缩放动画的时长。
  final Duration zoomDuration;

  /// [zoomDuration] 使用的曲线。
  final Curve zoomCurve;

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
    double? mediaCardInsetTop,
    double? mediaCardInsetBottom,
    double? mediaCardInsetLeft,
    double? mediaCardInsetRight,
    double? mediaCardBorderRadius,
    Duration? mediaCardAnimationDuration,
    Curve? mediaCardAnimationCurve,
    Duration? barsToggleDuration,
    Curve? barsToggleCurve,
    Duration? zoomDuration,
    Curve? zoomCurve,
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
      mediaCardInsetTop: mediaCardInsetTop ?? this.mediaCardInsetTop,
      mediaCardInsetBottom: mediaCardInsetBottom ?? this.mediaCardInsetBottom,
      mediaCardInsetLeft: mediaCardInsetLeft ?? this.mediaCardInsetLeft,
      mediaCardInsetRight: mediaCardInsetRight ?? this.mediaCardInsetRight,
      mediaCardBorderRadius:
          mediaCardBorderRadius ?? this.mediaCardBorderRadius,
      mediaCardAnimationDuration:
          mediaCardAnimationDuration ?? this.mediaCardAnimationDuration,
      mediaCardAnimationCurve:
          mediaCardAnimationCurve ?? this.mediaCardAnimationCurve,
      barsToggleDuration: barsToggleDuration ?? this.barsToggleDuration,
      barsToggleCurve: barsToggleCurve ?? this.barsToggleCurve,
      zoomDuration: zoomDuration ?? this.zoomDuration,
      zoomCurve: zoomCurve ?? this.zoomCurve,
    );
  }
}
