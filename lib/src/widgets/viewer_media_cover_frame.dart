import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../viewer/media_card_chrome_scope.dart';

/// 用于 [MediaViewer] 内图片/视频的布局框。
///
/// 根据 [revealProgress] 在 **contain 居中** 与 **cover 顶对齐** 之间插值：
///
/// | [revealProgress] | 缩放 | 垂直对齐 |
/// |---|---|---|
/// | `0.0`（信息未展开） | `min(1, viewH/natH)`，整图可见（contain） | 居中 |
/// | `1.0`（信息默认高度） | `max(1, viewH/natH)`，铺满可视区（cover） | 贴顶 |
/// | `0…1` | 两者之间平滑插值 | 插值 |
///
/// **支持多种内容形态：**
/// - **图片**：包装 `Image` 组件，支持自然高比例。
/// - **视频**：包装 `VideoPlayer`，通常配合 `AspectRatio` 锁定比例，在 Frame 内缩放。
/// - **自定义布局**：可通过设置 [layoutChildToViewport] 为 `true` 让子组件撑满整个视口，
///   适合复杂的卡片、带装饰的 `Stack` 等场景。
///
/// **圆角联动：**
/// 若祖先存在 [MediaCardChromeScope]，圆角会作用在**实际绘制出来的图片外接矩形**上，
/// 半径来自 [MediaCardChromeScope.clipRadiusListenable]（内部 [ListenableBuilder] 更新，不整树重建）。
///
/// ```dart
/// pageBuilder: (context, pageCtx) {
///   return ViewerMediaCoverFrame(
///     revealProgress: pageCtx.infoRevealProgress,
///     child: Image.network(pageCtx.item.payload as String),
///   );
/// }
/// ```
///
/// 子组件**不要**再写死 [BoxFit]，交给本组件统一算缩放。
class ViewerMediaCoverFrame extends StatefulWidget {
  const ViewerMediaCoverFrame({
    required this.child,
    this.revealProgress,
    this.revealProgressListenable,
    this.layoutChildToViewport = false,
    super.key,
  });

  /// 静态进度值。若提供了 [revealProgressListenable]，则此值被忽略。
  final double? revealProgress;

  /// 动态进度监听器。
  ///
  /// 如果提供了此值，[ViewerMediaCoverFrame] 将在不重建 Widget 树的情况下
  /// 自动更新内部 RenderObject 的布局，解决高频重建导致的视频状态丢失问题。
  final ValueListenable<double>? revealProgressListenable;

  /// 是否按查看区视口的完整高度来布局子组件。
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

    return _CoverFrameRenderObjectWidget(
      screenWidth: MediaQuery.sizeOf(context).width,
      revealProgress: widget.revealProgress ?? 0,
      revealProgressListenable: widget.revealProgressListenable,
      clipRadius: clipRadiusListenable != null ? clipRadiusListenable.value : 0,
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

/// 实现 contain→cover + 垂直对齐插值的 [RenderObject]。
class RenderCoverFrame extends RenderProxyBox {
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
        _layoutChildToViewport = layoutChildToViewport;

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
    markNeedsPaint();
  }

  ValueListenable<double>? _clipRadiusListenable;
  ValueListenable<double>? get clipRadiusListenable => _clipRadiusListenable;
  set clipRadiusListenable(ValueListenable<double>? v) {
    if (_clipRadiusListenable == v) return;
    if (attached) _clipRadiusListenable?.removeListener(markNeedsPaint);
    _clipRadiusListenable = v;
    if (attached) _clipRadiusListenable?.addListener(markNeedsPaint);
    markNeedsPaint();
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

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _revealProgressListenable?.addListener(_onProgressChange);
    _clipRadiusListenable?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _revealProgressListenable?.removeListener(_onProgressChange);
    _clipRadiusListenable?.removeListener(markNeedsPaint);
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
      size = constraints.constrain(Size(viewW, 0));
      return;
    }

    if (_layoutChildToViewport) {
      child!.layout(
        BoxConstraints.tightFor(width: viewW, height: viewH),
        parentUsesSize: true,
      );
    } else {
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
    }

    // ── 核心修复：实施动态高度插值 ──
    // 如果有明确高度约束，我们让 Frame 的高度随 p 值从「内容高度」渐变到「视口高度」。
    // 这允许父级 _MediaViewportWrapper 的 Align 对齐逻辑在 p=0 时生效，
    // 同时在 p 增加时通过 Frame 的扩张支持 Cover 的溢出渲染。
    final double finalH;
    if (hasFiniteHeight && !_layoutChildToViewport) {
      final childH = child!.size.height;
      final p = _revealProgress.clamp(0.0, 1.0);
      
      // 插值高度：p=0 时为内容高，p=1 时为全屏高
      // 注意：对于长图（childH > viewH），插值会自动计算出合适的高度
      finalH = lerpDouble(childH, viewH, p)!;
    } else if (hasFiniteHeight) {
      finalH = viewH;
    } else {
      finalH = child?.size.height ?? 0;
    }

    size = constraints.constrain(Size(viewW, finalH));
  }

  // ── 绘制 ────────────────────────────────────────────────────────────────

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;

    final geometry = _computeGeometry();
    if (geometry == null) {
      context.paintChild(child!, offset);
      return;
    }

    context.canvas.save();

    final imgRect = geometry.paintRect.shift(offset);
    if (geometry.effectiveRadius > 0.5) {
      context.canvas.clipRRect(
        RRect.fromRectAndRadius(
          imgRect,
          Radius.circular(geometry.effectiveRadius),
        ),
      );
    } else {
      context.canvas.clipRect(offset & size);
    }

    context.canvas.translate(
      offset.dx + geometry.dx,
      offset.dy + geometry.dy,
    );
    context.canvas.scale(geometry.scale, geometry.scale);
    context.paintChild(child!, Offset.zero);
    context.canvas.restore();
  }

  // ── 命中测试 ────────────────────────────────────────────────────────────

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    if (child == null) return false;

    final geometry = _computeGeometry();
    if (geometry == null) {
      return super.hitTestChildren(result, position: position);
    }

    if (!geometry.paintRect.contains(position)) {
      return false;
    }

    if (geometry.effectiveRadius > 0.5) {
      final rr = RRect.fromRectAndRadius(
        geometry.paintRect,
        Radius.circular(geometry.effectiveRadius),
      );
      if (!rr.contains(position)) {
        return false;
      }
    }

    final transformed = Offset(
      (position.dx - geometry.dx) / geometry.scale,
      (position.dy - geometry.dy) / geometry.scale,
    );

    return result.addWithPaintOffset(
      offset: Offset(geometry.dx, geometry.dy),
      position: position,
      hitTest: (result, _) => child!.hitTest(result, position: transformed),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final geometry = _computeGeometry();
    if (geometry == null) return;
    transform.translateByDouble(geometry.dx, geometry.dy, 0, 1);
    transform.scaleByDouble(geometry.scale, geometry.scale, 1, 1);
  }

  _CoverFrameGeometry? _computeGeometry() {
    final childBox = child;
    if (childBox == null || !childBox.hasSize) return null;

    final childW = childBox.size.width;
    final childH = childBox.size.height;
    if (childW <= 0 || childH <= 0) return null;

    // 获取视口原始参考高度（锚点高度）
    // 注意：如果我们当前 size 已经处于插值中，我们需要用最高的 viewH 进行计算
    final viewportW = size.width;
    final viewportH = constraints.maxHeight.isFinite ? constraints.maxHeight : size.height;

    final p = _revealProgress.clamp(0.0, 1.0);

    // 1. 计算 Scale
    final containScale = math.min(1.0, math.min(viewportW / childW, viewportH / childH));
    final coverScale = math.max(viewportW / childW, viewportH / childH);
    final scale = lerpDouble(containScale, coverScale, p)!;

    // 2. 计算相对于当前 size 的偏移量 dy
    // 由于我们的 size 已随 p 在插值中（由 performLayout 计算），
    // 在子组件高度等于 container 宽度契合高度时，dy 保持 0。
    // 在需要剪裁（如长图或 Cover）时，dy 提供内部对齐。
    
    final scaledW = childW * scale;
    final scaledH = childH * scale;

    // 在 p=0 时，由于 size.height 此时通常等于 scaledH (在非长图下)，
    // dy 为 0 恰好能让内容在 Frame 内部顶部对齐，而此时 Frame 正由父级居中。
    final dx = (size.width - scaledW) / 2.0;
    final dy = (size.height - scaledH) / 2.0;

    final effectiveRadius = _clipRadius <= 0
        ? 0.0
        : math.min(_clipRadius, math.min(scaledW, scaledH) / 2.0);

    return _CoverFrameGeometry(
      dx: dx,
      dy: dy,
      scale: scale,
      paintRect: Rect.fromLTWH(dx, dy, scaledW, scaledH),
      effectiveRadius: effectiveRadius,
    );
  }
}

class _CoverFrameGeometry {
  const _CoverFrameGeometry({
    required this.dx,
    required this.dy,
    required this.scale,
    required this.paintRect,
    required this.effectiveRadius,
  });

  final double dx;
  final double dy;
  final double scale;
  final Rect paintRect;
  final double effectiveRadius;
}
