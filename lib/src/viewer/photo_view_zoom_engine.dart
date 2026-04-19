import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

import '../core/viewer_state.dart' show ViewerProgrammaticZoomKind;
import '../core/viewer_theme.dart';
import 'zoom_engine.dart';

/// [ZoomEngine] 的 photo_view 实现。
///
/// 封装了 [PhotoViewController]、[PhotoViewScaleStateController]、
/// [AnimationController] 以及双击/单击防抖逻辑。
///
/// 由 [_ZoomableMediaWrapper] 创建并持有，外部通过 [ZoomEngine] 接口调用。
class PhotoViewZoomEngine implements ZoomEngine {
  PhotoViewZoomEngine({
    required TickerProvider vsync,
    required ViewerTheme theme,
    required bool enableZoom,
    required bool enableDoubleTap,
  })  : _theme = theme,
        _enableZoom = enableZoom,
        _enableDoubleTap = enableDoubleTap {
    _photoCtrl = PhotoViewController()
      ..outputStateStream.listen(_onPhotoViewState);
    _scaleStateCtrl = PhotoViewScaleStateController();
    _animCtrl = AnimationController(
      vsync: vsync,
      duration: theme.zoomDuration,
    )..addListener(_onAnimTick);
  }

  final ViewerTheme _theme;
  final bool _enableZoom;
  final bool _enableDoubleTap;

  late final PhotoViewController _photoCtrl;
  late final PhotoViewScaleStateController _scaleStateCtrl;
  late final AnimationController _animCtrl;

  /// 与 PhotoView 可视区域一致，用于取视口中心的全局坐标。
  final GlobalKey _photoViewportKey = GlobalKey();

  Animation<double>? _scaleAnim;
  Animation<Offset>? _positionAnim;

  Offset _lastGlobalTapPosition = Offset.zero;

  /// 防止双击触发单击回调的防抖标志位。
  bool _doubleTapGuard = false;

  static const double _kMinScale = 1.0;
  static const double _kMaxScale = 5.0;
  static const double _kDoubleTapScale = 2.5;

  // ── ZoomEngine 回调属性 ────────────────────────────────────────────────────

  @override
  VoidCallback? onSingleTap;

  @override
  VoidCallback? onDoubleTap;

  @override
  ValueChanged<double>? onScaleChanged;

  // ── 内部辅助 ───────────────────────────────────────────────────────────────

  bool get _isZoomed => (_photoCtrl.scale ?? _kMinScale) > 1.02;

  void _onPhotoViewState(PhotoViewControllerValue value) {
    final s = value.scale ?? _kMinScale;
    onScaleChanged?.call(s);
  }

  void _onAnimTick() {
    if (_scaleAnim != null && _positionAnim != null) {
      _photoCtrl.updateMultiple(
        scale: _scaleAnim!.value,
        position: _positionAnim!.value,
      );
    }
  }

  PhotoViewScaleState _handleDoubleTap(PhotoViewScaleState currentState) {
    if (!_enableDoubleTap) {
      return currentState;
    }

    // 设置防抖标志，阻止本次 onTapUp 触发 onSingleTap
    _doubleTapGuard = true;
    // 在下一帧重置，确保本帧的 onTapUp 已处理完
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _doubleTapGuard = false;
    });

    onDoubleTap?.call();
    _runDoubleTapAnimation();
    return currentState;
  }

  void _runDoubleTapAnimation() {
    // 动画进行中忽略新的双击，防止重复启动动画
    if (_animCtrl.isAnimating) return;
    _animCtrl.stop();
    final currentScale = _photoCtrl.scale ?? _kMinScale;
    final currentPosition = _photoCtrl.position;

    final double targetScale;
    final Offset targetPosition;

    if (_isZoomed) {
      targetScale = _kMinScale;
      targetPosition = Offset.zero;
    } else {
      const s = _kDoubleTapScale;
      targetScale = s;

      final box =
          _photoViewportKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        // 1. 获取视口在屏幕上的绝对物理中心
        final viewportCenterGlobal = box.localToGlobal(
          Offset(box.size.width / 2, box.size.height / 2),
        );

        // 2. 计算点击点相对于视口中心的绝对物理矢量 (V)
        final V = _lastGlobalTapPosition - viewportCenterGlobal;

        // 3. 应用不动点平移公式：P2 = V - (V - P1) * (S2 / S1)
        final S1 = currentScale;
        final S2 = targetScale;
        final P1 = currentPosition;

        targetPosition = V - (V - P1) * (S2 / S1);
      } else {
        targetPosition = Offset.zero;
      }
    }

    final curved = CurvedAnimation(
      parent: _animCtrl,
      curve: _theme.zoomCurve,
    );
    _scaleAnim =
        Tween<double>(begin: currentScale, end: targetScale).animate(curved);
    _positionAnim = Tween<Offset>(begin: currentPosition, end: targetPosition)
        .animate(curved);

    _scaleStateCtrl.scaleState = targetScale > _kMinScale
        ? PhotoViewScaleState.zoomedIn
        : PhotoViewScaleState.initial;

    _animCtrl.forward(from: 0);
  }

  void _applyStepScale(double factor) {
    _animCtrl.stop();
    final cur = _photoCtrl.scale ?? _kMinScale;
    final next = (cur * factor).clamp(_kMinScale, _kMaxScale);
    if ((next - cur).abs() < 0.002) return;
    final pos = _photoCtrl.position;
    final ratio = next / cur;

    // PhotoView 内部 position (pos) 实际上就是相对于视口中心的偏移矢量。
    // 要实现基于中心的不动点缩放，逻辑上 V = Offset.zero。
    // 应用公式 P2 = V - (V - P1) * (S2 / S1) => P2 = P1 * ratio。
    final newPos = pos * ratio;

    _photoCtrl.updateMultiple(scale: next, position: newPos);
    _scaleStateCtrl.scaleState = next > _kMinScale + 0.02
        ? PhotoViewScaleState.zoomedIn
        : PhotoViewScaleState.initial;
  }

  void _programmaticResetScale() {
    _animCtrl.stop();
    _photoCtrl.updateMultiple(scale: _kMinScale, position: Offset.zero);
    _scaleStateCtrl.scaleState = PhotoViewScaleState.initial;
    onScaleChanged?.call(_kMinScale);
  }

  // ── ZoomEngine 接口实现 ────────────────────────────────────────────────────

  @override
  Widget build(
    BuildContext context, {
    required Widget child,
    required bool enabled,
  }) {
    // 当不应响应手势时（如信息面板即将拉起），如果当前处于放大状态，立即重置 PhotoView
    if (!enabled && _isZoomed) {
      _animCtrl.stop();
      _photoCtrl.updateMultiple(scale: _kMinScale, position: Offset.zero);
      _scaleStateCtrl.scaleState = PhotoViewScaleState.initial;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onScaleChanged?.call(_kMinScale);
      });
    }

    return Listener(
      onPointerDown: (event) {
        _lastGlobalTapPosition = event.position;
      },
      child: SizedBox.expand(
        key: _photoViewportKey,
        child: PhotoView.customChild(
          controller: _photoCtrl,
          scaleStateController: _scaleStateCtrl,
          tightMode: true,
          minScale: _kMinScale,
          maxScale: _kMaxScale,
          initialScale: _kMinScale,
          backgroundDecoration:
              const BoxDecoration(color: Colors.transparent),
          gestureDetectorBehavior: HitTestBehavior.translucent,
          disableGestures: !enabled,
          onTapUp: (_, details, __) {
            if (enabled && !_doubleTapGuard) {
              onSingleTap?.call();
            }
          },
          scaleStateCycle: _handleDoubleTap,
          child: child,
        ),
      ),
    );
  }

  @override
  void requestProgrammaticZoom(ViewerProgrammaticZoomKind kind) {
    if (!_enableZoom) return;
    switch (kind) {
      case ViewerProgrammaticZoomKind.zoomIn:
        _applyStepScale(1.2);
      case ViewerProgrammaticZoomKind.zoomOut:
        _applyStepScale(1 / 1.2);
      case ViewerProgrammaticZoomKind.reset:
        _programmaticResetScale();
    }
  }

  @override
  void reset() {
    _programmaticResetScale();
  }

  @override
  void dispose() {
    _animCtrl.removeListener(_onAnimTick);
    _photoCtrl.dispose();
    _scaleStateCtrl.dispose();
    _animCtrl.dispose();
  }
}
