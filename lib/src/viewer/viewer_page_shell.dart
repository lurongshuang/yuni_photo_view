import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/interaction_config.dart';
import '../core/viewer_item.dart';
import '../core/viewer_state.dart';
import '../core/viewer_theme.dart';
import '../info_sheet/info_sheet_controller.dart';

// ── Gesture mode ──────────────────────────────────────────────────────────────

enum _GestureMode {
  /// Not yet determined — waiting for enough delta.
  pending,

  /// Revealing or expanding the info sheet upward.
  expandInfo,

  /// Collapsing the info sheet downward.
  collapseInfo,

  /// Dismiss (viewer close) drag — content slides down.
  dismiss,

  /// Consumed by content (e.g., content is zoomed) — framework does nothing.
  consumed,
}

// ── Dismiss callbacks ─────────────────────────────────────────────────────────

typedef DismissUpdateCallback = void Function(double offset);
typedef DismissEndCallback = void Function(double offset, double velocityY);

// ── ViewerPageShell ───────────────────────────────────────────────────────────

/// The per-page composite: content + info sheet at the same layout level.
///
/// Both layers travel together when the user pages left/right.
/// Vertical gestures are captured here and routed to either the info sheet
/// controller or the dismiss handler (callbacks to the parent viewer).
class ViewerPageShell extends StatefulWidget {
  const ViewerPageShell({
    super.key,
    required this.index,
    required this.item,
    required this.infoController,
    required this.pageController,
    required this.config,
    required this.theme,
    required this.pageBuilder,
    this.infoBuilder,
    this.onDismissUpdate,
    this.onDismissEnd,
    this.screenHeight,
  });

  final int index;
  final ViewerItem item;
  final InfoSheetController infoController;
  final ViewerPageController pageController;
  final ViewerInteractionConfig config;
  final ViewerTheme theme;

  final ViewerPageBuilder pageBuilder;
  final ViewerInfoBuilder? infoBuilder;

  final DismissUpdateCallback? onDismissUpdate;
  final DismissEndCallback? onDismissEnd;

  /// Pre-supplied screen height to avoid MediaQuery look-ups in tight loops.
  final double? screenHeight;

  @override
  State<ViewerPageShell> createState() => _ViewerPageShellState();
}

class _ViewerPageShellState extends State<ViewerPageShell> {
  _GestureMode _gestureMode = _GestureMode.pending;
  double _dismissRawOffset = 0;

  // Key so we can call reset() on the zoom wrapper from the shell level
  // (e.g. when the page is re-activated after a swipe).
  final GlobalKey<_ZoomableMediaWrapperState> _zoomKey = GlobalKey();

  // ── Helpers ───────────────────────────────────────────────────────────────

  InfoSheetController get _info => widget.infoController;
  ViewerInteractionConfig get _cfg => widget.config;

  bool get _hasInfo =>
      widget.item.hasInfo &&
      widget.infoBuilder != null &&
      _cfg.enableInfoGesture;

  double _resolveScreenHeight(BuildContext ctx) =>
      widget.screenHeight ?? MediaQuery.of(ctx).size.height;

  // ── Gesture handlers ──────────────────────────────────────────────────────

  void _onDragStart(DragStartDetails details, double screenH) {
    _dismissRawOffset = 0;
    _gestureMode = _GestureMode.pending;
    _info.setScreenHeight(screenH);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final dy = details.delta.dy;

    // Resolve mode on first significant movement.
    if (_gestureMode == _GestureMode.pending) {
      if (dy.abs() < 3) return;

      if (dy < 0) {
        // Upward → show/expand info.
        _gestureMode = _hasInfo ? _GestureMode.expandInfo : _GestureMode.consumed;
      } else {
        // Downward.
        if (_info.state == InfoState.shown) {
          _gestureMode = _GestureMode.collapseInfo;
        } else if (widget.pageController.isZoomed || !_cfg.enableDismissGesture) {
          _gestureMode = _GestureMode.consumed;
        } else {
          _gestureMode = _GestureMode.dismiss;
        }
      }

      // Start info drag tracking when needed.
      if (_gestureMode == _GestureMode.expandInfo ||
          _gestureMode == _GestureMode.collapseInfo) {
        _info.startDrag();
      }
    }

    switch (_gestureMode) {
      case _GestureMode.expandInfo:
      case _GestureMode.collapseInfo:
        _info.updateDrag(dy);
        break;

      case _GestureMode.dismiss:
        _dismissRawOffset = (_dismissRawOffset + dy).clamp(0, double.infinity);
        widget.onDismissUpdate?.call(_dismissRawOffset);
        break;

      case _GestureMode.pending:
      case _GestureMode.consumed:
        break;
    }
  }

  void _onDragEnd(DragEndDetails details) {
    final velocityY = details.velocity.pixelsPerSecond.dy;

    switch (_gestureMode) {
      case _GestureMode.expandInfo:
      case _GestureMode.collapseInfo:
        _info.endDrag(velocityY);
        break;

      case _GestureMode.dismiss:
        widget.onDismissEnd?.call(_dismissRawOffset, velocityY);
        _dismissRawOffset = 0;
        break;

      case _GestureMode.pending:
      case _GestureMode.consumed:
        break;
    }

    _gestureMode = _GestureMode.pending;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenH = _resolveScreenHeight(context);

    // Proactively set the screen height so that InfoSheetController.show()
    // targets the correct extent even before the first drag gesture fires
    // (e.g. when show() is called programmatically right after a page swipe).
    _info.setScreenHeight(screenH);

    return ListenableBuilder(
      listenable: widget.pageController,
      builder: (ctx, _) {
        final isZoomed = widget.pageController.isZoomed;
        // When content is zoomed, null out the drag callbacks so that the
        // GestureDetector does not register a VerticalDragRecognizer.
        // This lets InteractiveViewer's ScaleGestureRecognizer win the arena
        // and handle single-finger pan on the zoomed content.
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragStart: isZoomed ? null : (d) => _onDragStart(d, screenH),
          onVerticalDragUpdate: isZoomed ? null : _onDragUpdate,
          onVerticalDragEnd: isZoomed ? null : _onDragEnd,
          child: ListenableBuilder(
            listenable: _info,
            builder: (ctx2, _) => _buildLayout(ctx2, screenH),
          ),
        );
      },
    );
  }

  Widget _buildLayout(BuildContext ctx, double screenH) {
    final sheetH = _info.sheetHeight;
    final contentH = (screenH - sheetH).clamp(0.0, screenH);
    final revealProgress = _info.revealProgress;
    final screenW = MediaQuery.of(ctx).size.width;

    final pageCtx = ViewerPageContext(
      index: widget.index,
      item: widget.item,
      infoState: _info.state,
      infoRevealProgress: revealProgress,
      availableSize: Size(screenW, contentH),
      config: _cfg,
      pageController: widget.pageController,
    );

    return Stack(
      children: [
        // ── Media viewport (top) ──────────────────────────────────────────
        // The height shrinks as the info sheet rises.
        // Content is always anchored to the top — the framework clips at bottom.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: contentH,
          child: _MediaViewportWrapper(
            revealProgress: revealProgress,
            child: _ZoomableMediaWrapper(
              key: _zoomKey,
              enabled: _cfg.enableZoom && revealProgress < 0.05,
              enableDoubleTap: _cfg.enableDoubleTapZoom,
              pageController: widget.pageController,
              child: widget.pageBuilder(ctx, pageCtx),
            ),
          ),
        ),

        // ── Info sheet (bottom, same layer as content) ─────────────────────
        if (_hasInfo && sheetH > 0)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: sheetH,
            child: Opacity(
              opacity: _info.contentOpacity,
              child: _InfoSheetSurface(
                theme: widget.theme,
                infoController: _info,
                child: widget.infoBuilder!(ctx, pageCtx),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Media viewport wrapper ────────────────────────────────────────────────────

/// Wraps the business content with a dynamically interpolated alignment.
///
/// - When [revealProgress] == 0 (info hidden): content is **centred** in the
///   full-screen viewport — the natural default for photo/video viewing.
/// - As [revealProgress] increases toward 1 (info at default half-screen):
///   the alignment smoothly shifts to **topCenter** so the media top edge
///   locks to the viewport top edge.
/// - Beyond 1 (sheet expanded further): alignment stays at topCenter.
///
/// [ClipRect] ensures content that is taller than the (shrinking) viewport
/// is clipped at the bottom rather than overflowing onto the info sheet.
class _MediaViewportWrapper extends StatelessWidget {
  const _MediaViewportWrapper({
    required this.child,
    required this.revealProgress,
  });

  final Widget child;

  /// 0.0 = info hidden (center), 1.0+ = info shown (topCenter).
  final double revealProgress;

  @override
  Widget build(BuildContext context) {
    // Alignment.center  → (0,  0)
    // Alignment.topCenter → (0, -1)
    // Interpolate the Y component from 0 → -1 as revealProgress goes 0 → 1.
    final alignY = -(revealProgress.clamp(0.0, 1.0));
    return ClipRect(
      child: Align(
        alignment: Alignment(0, alignY),
        child: child,
      ),
    );
  }
}

// ── Zoomable media wrapper ────────────────────────────────────────────────────

/// Wraps business content in an [InteractiveViewer] to provide pinch-to-zoom
/// and double-tap zoom/restore, when enabled by [ViewerInteractionConfig].
///
/// When [enabled] is false (e.g. while info panel is open), gestures are
/// passed through to the underlying content.
///
/// Zoom state is reported back to [ViewerPageController] so the parent shell
/// can block dismiss gestures while content is zoomed.
class _ZoomableMediaWrapper extends StatefulWidget {
  const _ZoomableMediaWrapper({
    super.key,
    required this.child,
    required this.enabled,
    required this.enableDoubleTap,
    required this.pageController,
  });

  final Widget child;
  final bool enabled;
  final bool enableDoubleTap;
  final ViewerPageController pageController;

  @override
  State<_ZoomableMediaWrapper> createState() => _ZoomableMediaWrapperState();
}

class _ZoomableMediaWrapperState extends State<_ZoomableMediaWrapper>
    with SingleTickerProviderStateMixin {
  late final TransformationController _transformCtrl;
  late final AnimationController _animCtrl;
  Animation<Matrix4>? _animation;

  Offset _doubleTapPosition = Offset.zero;

  static const double _kMinScale = 1.0;
  static const double _kMaxScale = 5.0;
  static const double _kDoubleTapScale = 2.5;

  @override
  void initState() {
    super.initState();
    _transformCtrl = TransformationController();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(() {
        if (_animation != null) {
          _transformCtrl.value = _animation!.value;
          _reportScale();
        }
      });
  }

  @override
  void didUpdateWidget(_ZoomableMediaWrapper old) {
    super.didUpdateWidget(old);
    // When zoom transitions from enabled → disabled (info starting to show),
    // instantly reset to 1× so that if InteractiveViewer re-enters the tree
    // (enabled flips back to true) it doesn't carry a stale 2× transform.
    if (old.enabled && !widget.enabled && _isZoomed) {
      _animCtrl.stop();
      _transformCtrl.value = Matrix4.identity();
      _reportScale();
    }
  }

  @override
  void dispose() {
    _transformCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  double get _currentScale => _transformCtrl.value.getMaxScaleOnAxis();

  bool get _isZoomed => _currentScale > 1.02;

  void _reportScale() {
    widget.pageController.reportContentScale(_currentScale);
  }

  void _animateTo(Matrix4 target) {
    _animCtrl.stop();
    _animation = Matrix4Tween(
      begin: _transformCtrl.value,
      end: target,
    ).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOutCubic),
    );
    _animCtrl.forward(from: 0);
  }

  /// Resets to 1x with animation. Called externally (e.g. on page switch).
  void resetZoom() {
    if (_isZoomed) _animateTo(Matrix4.identity());
  }

  // ── Double-tap ────────────────────────────────────────────────────────────

  void _onDoubleTapDown(TapDownDetails details) {
    _doubleTapPosition = details.localPosition;
  }

  void _onDoubleTap() {
    if (_isZoomed) {
      _animateTo(Matrix4.identity());
    } else {
      // Zoom in centred on the tap position.
      const s = _kDoubleTapScale;
      // Translate so the tapped point stays in place after scaling.
      final dx = -_doubleTapPosition.dx * (s - 1);
      final dy = -_doubleTapPosition.dy * (s - 1);
      // Build the matrix: translate(dx, dy) then scale(s).
      final zoom = Matrix4.translationValues(dx, dy, 0)
        ..scaleByDouble(s, s, 1.0, 1.0);
      _animateTo(zoom);
    }
  }

  // ── Interaction callbacks ─────────────────────────────────────────────────

  void _onInteractionUpdate(ScaleUpdateDetails details) {
    _reportScale();
  }

  void _onInteractionEnd(ScaleEndDetails details) {
    _reportScale();
    // If user pinched below 1x, snap back.
    if (_currentScale < _kMinScale) {
      _animateTo(Matrix4.identity());
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      // Zoom disabled (info open, or config flag off) — pass through content.
      return widget.child;
    }

    Widget viewer = InteractiveViewer(
      transformationController: _transformCtrl,
      minScale: _kMinScale,
      maxScale: _kMaxScale,
      // Do not clip — the outer ClipRect in _MediaViewportWrapper handles that.
      clipBehavior: Clip.none,
      // Allow panning beyond the viewport boundary when zoomed so the user
      // can inspect any part of the image.
      boundaryMargin: EdgeInsets.all(
        math.max(MediaQuery.of(context).size.width,
            MediaQuery.of(context).size.height),
      ),
      onInteractionUpdate: _onInteractionUpdate,
      onInteractionEnd: _onInteractionEnd,
      child: widget.child,
    );

    if (widget.enableDoubleTap) {
      viewer = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onDoubleTapDown: _onDoubleTapDown,
        onDoubleTap: _onDoubleTap,
        child: viewer,
      );
    }

    return viewer;
  }
}

// ── Info sheet surface ────────────────────────────────────────────────────────

/// The visible info sheet: rounded top corners, drag handle, and content.
class _InfoSheetSurface extends StatefulWidget {
  const _InfoSheetSurface({
    required this.theme,
    required this.infoController,
    required this.child,
  });

  final ViewerTheme theme;
  final InfoSheetController infoController;
  final Widget child;

  @override
  State<_InfoSheetSurface> createState() => _InfoSheetSurfaceState();
}

class _InfoSheetSurfaceState extends State<_InfoSheetSurface> {
  final GlobalKey _contentKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Measure content after first layout.
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureContent());
  }

  void _measureContent() {
    final ctx = _contentKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    widget.infoController.setMeasuredContentHeight(box.size.height);
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final bg = theme.effectiveInfoBackground(context);
    final handleColor = theme.effectiveDragHandleColor(context);

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: theme.infoBorderRadius,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle pill
            SizedBox(
              height: 28,
              child: Center(
                child: Container(
                  width: theme.dragHandleSize.width,
                  height: theme.dragHandleSize.height,
                  decoration: BoxDecoration(
                    color: handleColor,
                    borderRadius: BorderRadius.circular(theme.dragHandleSize.height / 2),
                  ),
                ),
              ),
            ),

            // Business info content — measured after layout.
            Flexible(
              child: SingleChildScrollView(
                // Scrolling is handled by the framework's gesture routing.
                // Disable native scroll physics to avoid conflicts.
                physics: const NeverScrollableScrollPhysics(),
                child: KeyedSubtree(
                  key: _contentKey,
                  child: widget.child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
