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

    final effectiveListenable =
        widget.revealProgressListenable ?? InfoRevealScope.maybeOf(context);

    return _CoverFrameRenderObjectWidget(
      screenWidth: MediaQuery.sizeOf(context).width,
      revealProgress: widget.revealProgress ?? 0,
      revealProgressListenable: effectiveListenable,
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

        // scale：p=0 时 1.0，p=1 时 max(1, viewH/childH)
        final scaleAtP1 = math.max(1.0, viewH / childH);
        final scale = lerpDouble(1.0, scaleAtP1, p)!;
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

        // dx：水平居中
        final dx = (viewW - scaledW) / 2.0;
        // dy：p=0 居中，p=1 顶对齐
        final dyAtP0 = (viewH - childH) / 2.0;
        final dy = lerpDouble(dyAtP0, 0.0, p)!;

        // 通过 BoxParentData.offset 设置 child 的 layout 位置
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

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;

    final childParentData = child!.parentData as BoxParentData;
    final childOffset = childParentData.offset;

    if (_layoutChildToViewport || _cachedScale == 1.0) {
      // 无缩放：直接绘制（child 已通过 layout offset 定位）
      if (_cachedEffectiveRadius > 0.5) {
        final clipRect = Rect.fromLTWH(
          offset.dx + childOffset.dx,
          offset.dy + childOffset.dy,
          child!.size.width * _cachedScale,
          child!.size.height * _cachedScale,
        );
        context.canvas.save();
        context.canvas.clipRRect(
          RRect.fromRectAndRadius(
            clipRect,
            Radius.circular(_cachedEffectiveRadius),
          ),
        );
        context.paintChild(child!, offset + childOffset);
        context.canvas.restore();
      } else {
        context.canvas.save();
        context.canvas.clipRect(offset & size);
        context.paintChild(child!, offset + childOffset);
        context.canvas.restore();
      }
      return;
    }

    // 有缩放：child 已通过 layout offset 定位到正确位置，
    // 在此基础上应用 scale 变换（以 child 左上角为原点缩放）
    final paintOrigin = offset + childOffset;
    final scaledW = child!.size.width * _cachedScale;
    final scaledH = child!.size.height * _cachedScale;

    context.canvas.save();

    if (_cachedEffectiveRadius > 0.5) {
      context.canvas.clipRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(paintOrigin.dx, paintOrigin.dy, scaledW, scaledH),
          Radius.circular(_cachedEffectiveRadius),
        ),
      );
    } else {
      context.canvas.clipRect(offset & size);
    }

    context.canvas.translate(paintOrigin.dx, paintOrigin.dy);
    context.canvas.scale(_cachedScale, _cachedScale);
    context.paintChild(child!, Offset.zero);
    context.canvas.restore();
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
