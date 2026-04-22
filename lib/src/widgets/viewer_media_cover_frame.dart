import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../viewer/media_card_chrome_scope.dart';

/// 用于 [MediaViewer] 内媒体内容的布局框。
///
/// 根据 [revealProgress] 在 **自然尺寸居中** 与 **填满视口顶对齐** 之间插值：
///
/// | [revealProgress] | 行为 |
/// |---|---|
/// | `0.0`（信息未展开） | child 以自然尺寸（scale=1）居中显示 |
/// | `1.0`（信息展开） | 若 child 高度不足视口，放大至填满；若已足够，保持 scale=1，顶对齐 |
/// | `0…1` | 两者之间平滑插值 |
///
/// **设计原则：不干涉 child 内部的 BoxFit 或布局逻辑。**
///
/// child 在宽度等于视口宽度、高度无限的约束下自然布局，
/// `ViewerMediaCoverFrame` 通过 **layout offset**（而非 canvas.translate）
/// 设置 child 的位置，确保 VideoPlayer 等原生 Surface 也能正确定位。
///
/// ```dart
/// pageBuilder: (context, pageCtx) {
///   return ViewerMediaCoverFrame(
///     revealProgress: pageCtx.infoRevealProgress,
///     child: Image.network(url, fit: BoxFit.contain),
///   );
/// }
/// ```
class ViewerMediaCoverFrame extends StatefulWidget {
  const ViewerMediaCoverFrame({
    required this.child,
    this.revealProgress,
    this.revealProgressListenable,
    this.layoutChildToViewport = false,
    super.key,
  });

  /// 静态进度值（0.0～1.0+）。若提供了 [revealProgressListenable]，则此值被忽略。
  final double? revealProgress;

  /// 动态进度监听器。推荐使用此字段以避免高频重建（如视频播放时）。
  final ValueListenable<double>? revealProgressListenable;

  /// 为 true 时，child 以视口完整尺寸（tight）布局，不做缩放变换。
  /// 适合需要撑满整个视口的自定义布局（如渐变卡片）。
  final bool layoutChildToViewport;

  final Widget child;

  @override
  State<ViewerMediaCoverFrame> createState() => _ViewerMediaCoverFrameState();
}

class _ViewerMediaCoverFrameState extends State<ViewerMediaCoverFrame> {
  @override
  Widget build(BuildContext context) {
    final scope = MediaCardChromeScope.maybeOf(context);
    final clipRadiusListenable = scope?.clipRadiusListenable;
    final clipRadiusSnapshot = clipRadiusListenable?.value ?? 0.0;

    final effectiveListenable =
        widget.revealProgressListenable ?? InfoRevealScope.maybeOf(context);

    return _CoverFrameRenderObjectWidget(
      screenWidth: MediaQuery.sizeOf(context).width,
      revealProgress: widget.revealProgress ?? 0,
      revealProgressListenable: effectiveListenable,
      clipRadius: clipRadiusSnapshot,
      clipRadiusListenable: clipRadiusListenable,
      layoutChildToViewport: widget.layoutChildToViewport,
      child: widget.child,
    );
  }
}

// ---------------------------------------------------------------------------

class _CoverFrameRenderObjectWidget extends SingleChildRenderObjectWidget {
  const _CoverFrameRenderObjectWidget({
    required this.screenWidth,
    required this.revealProgress,
    this.revealProgressListenable,
    required this.clipRadius,
    this.clipRadiusListenable,
    required this.layoutChildToViewport,
    required super.child,
  });

  final double screenWidth;
  final double revealProgress;
  final ValueListenable<double>? revealProgressListenable;
  final double clipRadius;
  final ValueListenable<double>? clipRadiusListenable;
  final bool layoutChildToViewport;

  @override
  RenderObject createRenderObject(BuildContext context) {
    final _l = clipRadiusListenable; // 局部变量以触发类型晋升
    return RenderCoverFrame(
      screenWidth: screenWidth,
      revealProgress: revealProgress,
      revealProgressListenable: revealProgressListenable,
      clipRadius: clipRadius,
      clipRadiusListenable: clipRadiusListenable,
      layoutChildToViewport: layoutChildToViewport,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderCoverFrame renderObject,
  ) {
    final oldClipR = renderObject._clipRadius;
    final oldListenable = renderObject._clipRadiusListenable;
    final sameListenable = identical(oldListenable, clipRadiusListenable);
    renderObject
      ..screenWidth = screenWidth
      ..revealProgress = revealProgress
      ..revealProgressListenable = revealProgressListenable
      ..clipRadius = clipRadius
      ..clipRadiusListenable = clipRadiusListenable
      ..layoutChildToViewport = layoutChildToViewport;
  }
}

// ---------------------------------------------------------------------------

/// 实现上滑填满变换的 [RenderObject]。
///
/// **关键设计**：使用 [RenderShiftedBox] 而非 [RenderProxyBox]，
/// 通过 [BoxParentData.offset] 设置 child 的 **layout 位置**（而非 canvas.translate），
/// 确保 VideoPlayer 等依赖原生 Surface 的 widget 也能正确定位。
///
/// **变换逻辑（仅在 layoutChildToViewport=false 时生效）：**
///
/// child 在 `(viewW, ∞)` 约束下自然布局，得到自然高度 `childH`。
///
/// - p=0：scale=1，child 以自然尺寸居中（若 childH < viewH，上下有留白）
/// - p=1：scale = max(1, viewH/childH)，child 放大到填满视口高度，顶对齐
///         若 childH >= viewH，scale=1，只做顶对齐（无留白，无需放大）
/// - 中间值：线性插值
class RenderCoverFrame extends RenderShiftedBox {
  RenderCoverFrame({
    required double screenWidth,
    required double revealProgress,
    ValueListenable<double>? revealProgressListenable,
    double clipRadius = 0,
    ValueListenable<double>? clipRadiusListenable,
    bool layoutChildToViewport = false,
  })  : _screenWidth = screenWidth,
        _revealProgress = revealProgress,
        _revealProgressListenable = revealProgressListenable,
        _clipRadius = clipRadius,
        _clipRadiusListenable = clipRadiusListenable,
        _layoutChildToViewport = layoutChildToViewport,
        super(null);

  double _screenWidth;

  set screenWidth(double v) {
    if (_screenWidth == v) return;
    _screenWidth = v;
    markNeedsLayout();
  }

  double _revealProgress;

  set revealProgress(double v) {
    if (_revealProgress == v) return;
    _revealProgress = v;
    markNeedsLayout();
  }

  ValueListenable<double>? _revealProgressListenable;

  ValueListenable<double>? get revealProgressListenable =>
      _revealProgressListenable;

  set revealProgressListenable(ValueListenable<double>? v) {
    if (_revealProgressListenable == v) return;
    if (attached) _revealProgressListenable?.removeListener(_onProgressChange);
    _revealProgressListenable = v;
    if (attached) _revealProgressListenable?.addListener(_onProgressChange);
    _onProgressChange();
  }

  double _clipRadius;

  set clipRadius(double v) {
    if (_clipRadius == v) return;
    _clipRadius = v;
    markNeedsLayout();
  }

  ValueListenable<double>? _clipRadiusListenable;

  ValueListenable<double>? get clipRadiusListenable => _clipRadiusListenable;

  set clipRadiusListenable(ValueListenable<double>? v) {
    if (_clipRadiusListenable == v) return;
    if (attached) _clipRadiusListenable?.removeListener(_onClipRadiusChange);
    _clipRadiusListenable = v;
    if (attached) _clipRadiusListenable?.addListener(_onClipRadiusChange);
    _onClipRadiusChange();
  }

  void _onClipRadiusChange() {
    final newRadius = _clipRadiusListenable?.value ?? _clipRadius;
    if (_clipRadius == newRadius) return;
    _clipRadius = newRadius;
    markNeedsLayout();
  }

  void _onProgressChange() {
    final v = _revealProgressListenable?.value ?? _revealProgress;
    if (_revealProgress == v) return;
    _revealProgress = v;
    markNeedsLayout();
  }

  bool _layoutChildToViewport;

  bool get layoutChildToViewport => _layoutChildToViewport;

  set layoutChildToViewport(bool v) {
    if (_layoutChildToViewport == v) return;
    _layoutChildToViewport = v;
    markNeedsLayout();
  }

  // 缓存 scale，供 paint 使用（layout 已设置 offset，paint 只需处理 scale）
  double _cachedScale = 1.0;
  double _cachedEffectiveRadius = 0.0;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _revealProgressListenable?.addListener(_onProgressChange);
    _clipRadiusListenable?.addListener(_onClipRadiusChange);
    // 注册监听器后立即同步当前 listenable 值。
    // 当发生 GlobalKey reparent（如翻页时 _zoomKey 引起的子树移动）时，
    // build() 中读取的 clipRadius 快照值可能是陈旧的 0，
    // attach 后如果 listenable 没有新通知，_clipRadius 将永远是 0，导致圆角不生效。
    _onClipRadiusChange();
    _onProgressChange();
  }

  @override
  void detach() {
    _revealProgressListenable?.removeListener(_onProgressChange);
    _clipRadiusListenable?.removeListener(_onClipRadiusChange);
    super.detach();
  }

  // ── 布局 ────────────────────────────────────────────────────────────────

  @override
  void performLayout() {
    final viewW =
        constraints.maxWidth.isFinite ? constraints.maxWidth : _screenWidth;
    final hasFiniteHeight = constraints.maxHeight.isFinite;
    final viewH = hasFiniteHeight ? constraints.maxHeight : 0.0;

    if (child == null) {
      size = constraints.constrain(Size(viewW, viewH));
      _cachedScale = 1.0;
      _cachedEffectiveRadius = 0.0;
      return;
    }

    if (_layoutChildToViewport) {
      // layoutChildToViewport 模式：child 撑满整个视口，不做变换。
      child!.layout(
        BoxConstraints.tightFor(width: viewW, height: viewH),
        parentUsesSize: true,
      );
      final childParentData = child!.parentData as BoxParentData;
      childParentData.offset = Offset.zero;
      _cachedScale = 1.0;
      _cachedEffectiveRadius = 0.0;
    } else {
      // 正常模式：child 在宽度等于视口宽度、高度无限的约束下自然布局。
      child!.layout(
        BoxConstraints(
          minWidth: 0,
          maxWidth: viewW,
          minHeight: 0,
          maxHeight: double.infinity,
        ),
        parentUsesSize: true,
      );

      if (child!.size.height <= 0 || !child!.size.height.isFinite) {
        child!.layout(
          BoxConstraints.tightFor(width: viewW),
          parentUsesSize: true,
        );
      }

      final childW = child!.size.width;
      final childH = child!.size.height;

      if (childW > 0 && childH > 0 && viewH > 0) {
        final p = _revealProgress.clamp(0.0, 1.0);

        // scaleAtP0：p=0 时的状态。
        // 实现「基于窄边（Contain）」：如果 childH > viewH (纵向长图)，则缩放到 viewH/childH 以一眼看全。
        final scaleAtP0 = childH > viewH ? (viewH / childH) : 1.0;

        // scaleAtP1：p=1 时的状态。
        // 实现「填满（Cover）」：确保至少填满视口高度。
        final scaleAtP1 = math.max(1.0, viewH / childH);

        final scale = lerpDouble(scaleAtP0, scaleAtP1, p)!;
        _cachedScale = 1.0; // 不再用 canvas.scale，始终为 1.0

        final scaledW = childW * scale;
        final scaledH = childH * scale;

        // 以放大后的尺寸重新布局 child，确保 VideoPlayer Surface 也以正确尺寸渲染
        if (scale != 1.0) {
          child!.layout(
            BoxConstraints.tightFor(
              width: scaledW,
              height: scaledH,
            ),
            parentUsesSize: true,
          );
        }

        // 计算两个极端状态下的理想 dy 偏移量
        // p=0 时：垂直居中 (基于缩放后的高度)
        final scaledHAtP0 = childH * scaleAtP0;
        final dyAtP0 = (viewH - scaledHAtP0) / 2.0;
        // p=1 时：顶部对齐
        const dyAtP1 = 0.0;

        // dx：始终水平居中
        final dx = (viewW - scaledW) / 2.0;
        // dy：在居中和顶对齐之间线性插值
        final dy = lerpDouble(dyAtP0, dyAtP1, p)!;

        final childParentData = child!.parentData as BoxParentData;
        childParentData.offset = Offset(dx, dy);

        _cachedEffectiveRadius = _clipRadius <= 0
            ? 0.0
            : math.min(_clipRadius, math.min(scaledW, scaledH) / 2.0);
      } else {
        final childParentData = child!.parentData as BoxParentData;
        childParentData.offset = Offset.zero;
        _cachedScale = 1.0;
        _cachedEffectiveRadius = 0.0;
      }
    }

    // Frame 始终占满视口
    size = constraints.constrain(Size(viewW, viewH));
  }

  // ── 绘制 ────────────────────────────────────────────────────────────────
  //
  // ⚠️ 关键：必须使用 context.pushClipRRect() 而非 canvas.clipRRect()。
  //
  // canvas.clipRRect() 只作用于当前 canvas 层。PhotoView 内部会创建
  // RepaintBoundary，产生独立的合成层（composited layer）。canvas 级裁剪
  // 无法穿透合成层边界，导致圆角对 PhotoView 子树无效（视觉上无圆角）。
  //
  // context.pushClipRRect() 会将裁剪信息下推到合成层，正确作用于整个子树。

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;

    final childParentData = child!.parentData as BoxParentData;
    final childOffset = childParentData.offset;

    // _cachedScale 始终为 1.0（尺寸通过 layout 控制，不用 canvas.scale），
    // 因此只需一个绘制路径。
    if (_cachedEffectiveRadius > 0.5) {
      // 有圆角：pushClipRRect 确保合成子层也被裁剪。
      // childRect 为 child 在本地坐标系中的矩形（相对于 offset）。
      final childRect = childOffset & child!.size;
      context.pushClipRRect(
        needsCompositing,
        offset,
        childRect,
        RRect.fromRectAndRadius(
          childRect,
          Radius.circular(_cachedEffectiveRadius),
        ),
        (ctx, o) => ctx.paintChild(child!, o + childOffset),
      );
    } else {
      // 无圆角：pushClipRect 防止 child 溢出到 frame 之外。
      context.pushClipRect(
        needsCompositing,
        offset,
        Offset.zero & size,
        (ctx, o) => ctx.paintChild(child!, o + childOffset),
      );
    }
  }

  // ── 命中测试 ────────────────────────────────────────────────────────────

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (child == null) return false;

    final childParentData = child!.parentData as BoxParentData;
    final childOffset = childParentData.offset;
    final scale = _cachedScale;

    // 将点击坐标转换到 child 的本地坐标系
    final localPos = Offset(
      (position.dx - childOffset.dx) / scale,
      (position.dy - childOffset.dy) / scale,
    );

    // 检查是否在 child 范围内
    if (localPos.dx < 0 ||
        localPos.dy < 0 ||
        localPos.dx > child!.size.width ||
        localPos.dy > child!.size.height) {
      return false;
    }

    return result.addWithPaintOffset(
      offset: childOffset,
      position: position,
      hitTest: (result, _) => child!.hitTest(result, position: localPos),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final childParentData = child.parentData as BoxParentData;
    final offset = childParentData.offset;
    transform.translateByDouble(offset.dx, offset.dy, 0, 1);
    if (_cachedScale != 1.0) {
      transform.scaleByDouble(_cachedScale, _cachedScale, 1, 1);
    }
  }
}

// ---------------------------------------------------------------------------

/// 由 [ViewerPageShell] 注入，让 [ViewerMediaCoverFrame] 在用户未提供
/// [ViewerMediaCoverFrame.revealProgressListenable] 时自动订阅框架的进度通知器。
class InfoRevealScope extends InheritedWidget {
  const InfoRevealScope({
    super.key,
    required this.listenable,
    required super.child,
  });

  final ValueListenable<double> listenable;

  static ValueListenable<double>? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<InfoRevealScope>()
        ?.listenable;
  }

  @override
  bool updateShouldNotify(InfoRevealScope oldWidget) {
    return oldWidget.listenable != listenable;
  }
}
