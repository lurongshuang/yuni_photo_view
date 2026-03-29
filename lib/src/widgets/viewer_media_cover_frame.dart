import 'dart:ui' show lerpDouble;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A layout frame designed for image and video content inside [MediaViewer].
///
/// Applies a **contain → cover + top-lock** semantic driven by [revealProgress]:
///
/// | [revealProgress] | Scale | Vertical alignment |
/// |---|---|---|
/// | `0.0` (info hidden) | `min(1, viewH/natH)` — full image visible (contain) | centered |
/// | `1.0` (info shown) | `max(1, viewH/natH)` — fills the viewport (cover) | top-locked |
/// | `0…1` transition | smoothly interpolated between the two states | |
///
/// **Scale rules per case:**
/// - Landscape / short image (`natH < viewH`): contain=1× (natural size), cover=scale-up to fill.
/// - Portrait / tall image (`natH ≥ viewH`): contain=scale-down to fit, cover=1× (no downscale).
///
/// ## Usage
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
/// Pass the image **without** an explicit [BoxFit] — let [ViewerMediaCoverFrame]
/// own the scale decision.
class ViewerMediaCoverFrame extends SingleChildRenderObjectWidget {
  const ViewerMediaCoverFrame({
    required Widget child,
    required this.revealProgress,
    super.key,
  }) : super(child: child);

  /// Driven by [ViewerPageContext.infoRevealProgress].
  /// - `0.0` → contain + centered
  /// - `1.0` → cover + top-locked
  final double revealProgress;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderCoverFrame(
      screenWidth: MediaQuery.sizeOf(context).width,
      revealProgress: revealProgress,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderCoverFrame renderObject,
  ) {
    renderObject
      ..screenWidth = MediaQuery.sizeOf(context).width
      ..revealProgress = revealProgress;
  }
}

// ---------------------------------------------------------------------------

/// RenderObject that implements the contain→cover+top-lock paint logic.
class RenderCoverFrame extends RenderProxyBox {
  RenderCoverFrame({
    required double screenWidth,
    required double revealProgress,
  })  : _screenWidth = screenWidth,
        _revealProgress = revealProgress;

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
    // Layout doesn't change — only paint transform changes.
    markNeedsPaint();
  }

  // ── Layout ────────────────────────────────────────────────────────────────

  @override
  void performLayout() {
    final viewW = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : _screenWidth;
    final viewH = constraints.maxHeight.isFinite ? constraints.maxHeight : 0.0;

    // Lay child at tight viewport width so it reports its width-constrained
    // natural height (width × imageH/imageW).
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

    // Self fills the viewport.
    size = Size(viewW, viewH > 0 ? viewH : (child?.size.height ?? 0));
  }

  // ── Paint ─────────────────────────────────────────────────────────────────

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

    // contain: min(1, viewH/natH)  — shows full image (may letterbox)
    // cover:   max(1, viewH/natH)  — fills viewport (may crop)
    final containScale = (viewH / natH).clamp(0.0, 1.0);
    final coverScale = (viewH / natH).clamp(1.0, double.infinity);
    final scale = lerpDouble(containScale, coverScale, p)!;

    final scaledH = natH * scale;
    // Vertical: lerp from center-align to top-align.
    final centerDy = (viewH - scaledH) / 2.0;
    final dy = lerpDouble(centerDy, 0.0, p)!;

    // Horizontal: always center (natW == viewW after layout, so dx == 0).
    // Keep the explicit formula in case of sub-pixel rounding.
    final scaledW = viewW * scale;
    final dx = (viewW - scaledW) / 2.0;

    context.canvas.save();
    // Clip to the viewport rectangle so scaled content doesn't bleed outside.
    context.canvas.clipRect(offset & size);
    context.canvas.translate(offset.dx + dx, offset.dy + dy);
    context.canvas.scale(scale, scale);
    context.paintChild(child!, Offset.zero);
    context.canvas.restore();
  }

  // ── Hit testing ───────────────────────────────────────────────────────────

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    // Inverse the paint transform so taps land on the correct child region.
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

    final transformed = Offset(
      (position.dx - dx) / scale,
      (position.dy - dy) / scale,
    );

    return result.addWithPaintOffset(
      offset: Offset(dx, dy),
      position: position,
      hitTest: (result, _) =>
          child!.hitTest(result, position: transformed),
    );
  }
}
