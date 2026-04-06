import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

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
/// **分情况：**
/// - 横向/较矮图（`natH < viewH`）：contain 常为 1×，cover 为放大铺满。
/// - 竖向/较高图（`natH ≥ viewH`）：contain 为缩小适配，cover 常为 1×（不再缩小）。
///
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
class ViewerMediaCoverFrame extends StatelessWidget {
  const ViewerMediaCoverFrame({
    required this.child,
    required this.revealProgress,
    super.key,
  });

  /// 一般传入 [ViewerPageContext.infoRevealProgress]。
  final double revealProgress;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scope = MediaCardChromeScope.maybeOf(context);
    if (scope == null) {
      return _CoverFrameRenderObjectWidget(
        screenWidth: MediaQuery.sizeOf(context).width,
        revealProgress: revealProgress,
        clipRadius: 0,
        child: child,
      );
    }

    return ListenableBuilder(
      listenable: scope.clipRadiusListenable,
      builder: (context, mediaChild) {
        return _CoverFrameRenderObjectWidget(
          screenWidth: MediaQuery.sizeOf(context).width,
          revealProgress: revealProgress,
          clipRadius: scope.clipRadiusListenable.value,
          child: mediaChild!,
        );
      },
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------

class _CoverFrameRenderObjectWidget extends SingleChildRenderObjectWidget {
  const _CoverFrameRenderObjectWidget({
    required this.screenWidth,
    required this.revealProgress,
    required this.clipRadius,
    required super.child,
  });

  final double screenWidth;
  final double revealProgress;
  final double clipRadius;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderCoverFrame(
      screenWidth: screenWidth,
      revealProgress: revealProgress,
      clipRadius: clipRadius,
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
      ..clipRadius = clipRadius;
  }
}

// ---------------------------------------------------------------------------

/// 实现 contain→cover + 垂直对齐插值的 [RenderObject]。
class RenderCoverFrame extends RenderProxyBox {
  RenderCoverFrame({
    required double screenWidth,
    required double revealProgress,
    double clipRadius = 0,
  })  : _screenWidth = screenWidth,
        _revealProgress = revealProgress,
        _clipRadius = clipRadius;

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
    markNeedsPaint();
  }

  double _clipRadius;
  set clipRadius(double v) {
    if (_clipRadius == v) return;
    _clipRadius = v;
    markNeedsPaint();
  }

  // ── 布局 ────────────────────────────────────────────────────────────────

  @override
  void performLayout() {
    final viewW =
        constraints.maxWidth.isFinite ? constraints.maxWidth : _screenWidth;
    final viewH = constraints.maxHeight.isFinite ? constraints.maxHeight : 0.0;

    if (child != null) {
      child!.layout(
        BoxConstraints(
          minWidth: viewW,
          maxWidth: viewW,
          minHeight: 0,
          maxHeight: double.infinity,
        ),
        parentUsesSize: true,
      );
    }

    size = Size(viewW, viewH > 0 ? viewH : (child?.size.height ?? 0));
  }

  // ── 绘制 ────────────────────────────────────────────────────────────────

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;

    final viewW = size.width;
    final viewH = size.height;
    final natH = child!.size.height;

    if (natH <= 0 || viewW <= 0 || viewH <= 0) {
      context.paintChild(child!, offset);
      return;
    }

    final p = _revealProgress.clamp(0.0, 1.0);

    final containScale = (viewH / natH).clamp(0.0, 1.0);
    final coverScale = (viewH / natH).clamp(1.0, double.infinity);
    final scale = lerpDouble(containScale, coverScale, p)!;

    final scaledH = natH * scale;
    final centerDy = (viewH - scaledH) / 2.0;
    final dy = lerpDouble(centerDy, 0.0, p)!;

    final scaledW = viewW * scale;
    final dx = (viewW - scaledW) / 2.0;

    context.canvas.save();

    final imgRect = Rect.fromLTWH(dx, dy, scaledW, scaledH).shift(offset);
    final effectiveR = _clipRadius <= 0
        ? 0.0
        : math.min(_clipRadius, math.min(scaledW, scaledH) / 2.0);

    if (effectiveR > 0.5) {
      context.canvas.clipRRect(
        RRect.fromRectAndRadius(imgRect, Radius.circular(effectiveR)),
      );
    } else {
      context.canvas.clipRect(offset & size);
    }

    context.canvas.translate(offset.dx + dx, offset.dy + dy);
    context.canvas.scale(scale, scale);
    context.paintChild(child!, Offset.zero);
    context.canvas.restore();
  }

  // ── 命中测试 ────────────────────────────────────────────────────────────

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final viewW = size.width;
    final viewH = size.height;
    final natH = child?.size.height ?? 0;

    if (natH <= 0 || viewH <= 0) {
      return super.hitTestChildren(result, position: position);
    }

    final p = _revealProgress.clamp(0.0, 1.0);
    final containScale = (viewH / natH).clamp(0.0, 1.0);
    final coverScale = (viewH / natH).clamp(1.0, double.infinity);
    final scale = lerpDouble(containScale, coverScale, p)!;

    final scaledH = natH * scale;
    final centerDy = (viewH - scaledH) / 2.0;
    final dy = lerpDouble(centerDy, 0.0, p)!;
    final dx = (viewW - viewW * scale) / 2.0;

    final scaledW = viewW * scale;
    final imgRect = Rect.fromLTWH(dx, dy, scaledW, scaledH);
    if (!imgRect.contains(position)) {
      return false;
    }

    final effectiveR = _clipRadius <= 0
        ? 0.0
        : math.min(_clipRadius, math.min(scaledW, scaledH) / 2.0);
    if (effectiveR > 0.5) {
      final rr = RRect.fromRectAndRadius(
        imgRect,
        Radius.circular(effectiveR),
      );
      if (!rr.contains(position)) {
        return false;
      }
    }

    final transformed = Offset(
      (position.dx - dx) / scale,
      (position.dy - dy) / scale,
    );

    return result.addWithPaintOffset(
      offset: Offset(dx, dy),
      position: position,
      hitTest: (result, _) => child!.hitTest(result, position: transformed),
    );
  }
}
