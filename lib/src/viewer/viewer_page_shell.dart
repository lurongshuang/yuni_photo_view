import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

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
    this.onContentTap,
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

  /// Called on a single tap on the content area (not info sheet).
  /// Used by [MediaViewer] to toggle the top/bottom bar visibility.
  /// When null, single taps are not consumed by the shell.
  final VoidCallback? onContentTap;

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
        // GestureDetector does not register a VerticalDragRecognizer and lets
        // PhotoView's ScaleGestureRecognizer handle single-finger pan.
        //
        // Single-tap bar toggle is intentionally NOT placed here — see
        // _ZoomableMediaWrapper.onSingleTap. Relying on PhotoView's own
        // TapGestureRecognizer (via onTapUp) avoids the gesture-arena conflict
        // that prevented onTap from ever firing in this outer GestureDetector.
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
              // Single-tap is detected via PhotoView's internal TapGestureRecognizer
              // (onTapUp), which naturally defers to DoubleTapGestureRecognizer
              // when a double-tap occurs. This avoids the gesture-arena conflict
              // that existed when we used an outer GestureDetector(onTap).
              onSingleTap: _cfg.enableTapToToggleBars ? widget.onContentTap : null,
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

/// Wraps business content in a [PhotoView.customChild] to provide
/// pinch-to-zoom, double-tap zoom/restore, and bounded panning.
///
/// Using [PhotoView.customChild] instead of [InteractiveViewer] ensures that
/// the gesture recognizer participates in the [PhotoViewGestureDetectorScope]
/// that wraps the [PageView] in [MediaViewer], completely eliminating the
/// conflict between horizontal page-swiping and two-finger pinch-to-zoom.
///
/// Zoom state is reported back to [ViewerPageController] so the parent shell
/// can block dismiss gestures and disable PageView paging while zoomed.
class _ZoomableMediaWrapper extends StatefulWidget {
  const _ZoomableMediaWrapper({
    super.key,
    required this.child,
    required this.enabled,
    required this.enableDoubleTap,
    required this.pageController,
    this.onSingleTap,
  });

  final Widget child;
  final bool enabled;
  final bool enableDoubleTap;
  final ViewerPageController pageController;

  /// Called when a confirmed single tap on the content area is detected.
  ///
  /// PhotoView's internal [TapGestureRecognizer] and [DoubleTapGestureRecognizer]
  /// already coordinate correctly: [onSingleTap] fires only for genuine single
  /// taps, never for the first tap of a double-tap sequence.
  final VoidCallback? onSingleTap;

  @override
  State<_ZoomableMediaWrapper> createState() => _ZoomableMediaWrapperState();
}

class _ZoomableMediaWrapperState extends State<_ZoomableMediaWrapper>
    with SingleTickerProviderStateMixin {
  late final PhotoViewController _photoCtrl;
  late final PhotoViewScaleStateController _scaleStateCtrl;
  late final AnimationController _animCtrl;

  // Used to animate double-tap zoom/restore via the PhotoViewController.
  Animation<double>? _scaleAnim;
  Animation<Offset>? _positionAnim;

  // Tap position captured via PhotoView's own onTapDown; updated on every
  // pointer-down so the last value is the second-tap position when
  // scaleStateCycle fires.
  Offset _lastTapPosition = Offset.zero;

  static const double _kMinScale = 1.0;
  static const double _kMaxScale = 5.0;
  static const double _kDoubleTapScale = 2.5;

  @override
  void initState() {
    super.initState();
    _photoCtrl = PhotoViewController()
      ..outputStateStream.listen(_onPhotoViewState);
    _scaleStateCtrl = PhotoViewScaleStateController();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(_onAnimTick);
    debugPrint('[Viewer][Zoom] initState enableDoubleTap=${widget.enableDoubleTap}');
  }

  @override
  void didUpdateWidget(_ZoomableMediaWrapper old) {
    super.didUpdateWidget(old);
    // When zoom is disabled (info panel opening), snap back to 1× immediately.
    if (old.enabled && !widget.enabled && _isZoomed) {
      debugPrint('[Viewer][Zoom] disabled while zoomed — snap to 1×');
      _animCtrl.stop();
      _photoCtrl.updateMultiple(scale: _kMinScale, position: Offset.zero);
      _scaleStateCtrl.scaleState = PhotoViewScaleState.initial;
      widget.pageController.reportContentScale(_kMinScale);
    }
  }

  @override
  void dispose() {
    _animCtrl.removeListener(_onAnimTick);
    _photoCtrl.dispose();
    _scaleStateCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool get _isZoomed => (_photoCtrl.scale ?? _kMinScale) > 1.02;

  void _onPhotoViewState(PhotoViewControllerValue value) {
    final s = value.scale ?? _kMinScale;
    widget.pageController.reportContentScale(s);
  }

  void _onAnimTick() {
    if (_scaleAnim != null && _positionAnim != null) {
      _photoCtrl.updateMultiple(
        scale: _scaleAnim!.value,
        position: _positionAnim!.value,
      );
    }
  }

  // ── Double-tap (driven via PhotoView's own scaleStateCycle) ───────────────
  //
  // We do NOT wrap PhotoView.customChild in an outer GestureDetector(onDoubleTap)
  // because PhotoView always registers its own DoubleTapGestureRecognizer
  // internally (handleDoubleTap is always non-null).  The inner recogniser wins
  // the gesture arena every time, so an outer one is never called.
  //
  // Instead we hook into PhotoView's native mechanism:
  //   • onTapDown  → captures the latest tap position (updated on every down,
  //                  so the value at scaleStateCycle call-time is the second
  //                  tap's position — exactly what we want for zoom centering).
  //   • scaleStateCycle → intercepts the double-tap event and triggers our
  //                  custom animation; returns the SAME state so PhotoView
  //                  itself does not animate anything.

  void _onPhotoViewTapDown(
    BuildContext _,
    TapDownDetails details,
    PhotoViewControllerValue __,
  ) {
    _lastTapPosition = details.localPosition;
    debugPrint('[Viewer][Zoom] ✅ onTapDown at $_lastTapPosition');
  }

  /// Called by PhotoView's internal [TapGestureRecognizer] only for confirmed
  /// single taps — never fires when a double-tap is detected (the arena is won
  /// by [DoubleTapGestureRecognizer] in that case, so [TapGestureRecognizer]
  /// is rejected and [onTapUp] is not invoked).
  void _onPhotoViewTapUp(
    BuildContext _,
    TapUpDetails details,
    PhotoViewControllerValue __,
  ) {
    debugPrint('[Viewer][Zoom] ✅ onTapUp → single tap confirmed → calling onSingleTap');
    widget.onSingleTap?.call();
  }

  /// Called by PhotoView on every double-tap (scaleStateCycle hook).
  /// Drives our custom zoom animation and returns the SAME state so
  /// PhotoView does not independently change its own transform.
  PhotoViewScaleState _handleDoubleTap(PhotoViewScaleState currentState) {
    debugPrint(
        '[Viewer][Zoom] ✅ _handleDoubleTap called currentState=$currentState isZoomed=$_isZoomed');

    if (!widget.enableDoubleTap) {
      debugPrint('[Viewer][Zoom] double-tap disabled — ignoring');
      return currentState; // no-op
    }

    _runDoubleTapAnimation();
    // Return current state so PhotoView does NOT independently animate.
    return currentState;
  }

  void _runDoubleTapAnimation() {
    _animCtrl.stop();
    final currentScale = _photoCtrl.scale ?? _kMinScale;
    final currentPosition = _photoCtrl.position;

    final double targetScale;
    final Offset targetPosition;

    if (_isZoomed) {
      targetScale = _kMinScale;
      targetPosition = Offset.zero;
      debugPrint('[Viewer][Zoom] double-tap → restore to 1×');
    } else {
      const s = _kDoubleTapScale;
      targetScale = s;
      // PhotoView's effective rendering is: viewport_pos = scale * child_pos + position
      // (the Center widget and Transform.alignment:center terms cancel each other out,
      // leaving a simple scale-from-top-left model).
      //
      // To keep the tapped pixel at its original viewport position after zooming:
      //   tap = s * tap + targetPosition  →  targetPosition = -tap * (s - 1)
      targetPosition = Offset(
        -_lastTapPosition.dx * (s - 1),
        -_lastTapPosition.dy * (s - 1),
      );
      debugPrint(
          '[Viewer][Zoom] double-tap → zoom ${s}x at $_lastTapPosition targetPos=$targetPosition');
    }

    final curved = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeInOutCubic,
    );
    _scaleAnim =
        Tween<double>(begin: currentScale, end: targetScale).animate(curved);
    _positionAnim =
        Tween<Offset>(begin: currentPosition, end: targetPosition).animate(curved);

    // Keep the scale state controller in sync so PhotoView's internal state
    // is consistent (prevents PhotoView from launching its own animation).
    _scaleStateCtrl.scaleState = targetScale > _kMinScale
        ? PhotoViewScaleState.zoomedIn
        : PhotoViewScaleState.initial;

    _animCtrl.forward(from: 0);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return PhotoView.customChild(
      controller: _photoCtrl,
      scaleStateController: _scaleStateCtrl,
      // tightMode: child receives tight constraints = viewport size.
      // This makes PhotoView's boundary clamping work correctly without
      // needing to pass an explicit childSize.
      tightMode: true,
      minScale: _kMinScale,
      maxScale: _kMaxScale,
      initialScale: _kMinScale,
      backgroundDecoration: const BoxDecoration(color: Colors.transparent),
      gestureDetectorBehavior: HitTestBehavior.translucent,
      // Hook into PhotoView's own tap pipeline:
      // onTapDown → capture tap position (for double-tap centering)
      // onTapUp   → confirmed single tap (fires only when double-tap did NOT occur)
      // scaleStateCycle → intercept double-tap, run our animation
      onTapDown: _onPhotoViewTapDown,
      onTapUp: widget.onSingleTap != null ? _onPhotoViewTapUp : null,
      scaleStateCycle: _handleDoubleTap,
      child: widget.child,
    );
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
        // Clip the child to the Container's (animated) height so that when the
        // info sheet is only partially revealed the content does not paint
        // outside its allocated area.
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: theme.infoBorderRadius,
        ),
        // OverflowBox gives the Column a much larger maxHeight than the tight
        // constraint coming from the Positioned ancestor (which equals sheetH,
        // potentially only a few pixels during animation start).  This prevents
        // RenderFlex from throwing an overflow assertion while the Container's
        // clipBehavior takes care of the actual visual clipping.
        child: OverflowBox(
          minHeight: 0,
          maxHeight: 10000,
          alignment: Alignment.topCenter,
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
                      borderRadius:
                          BorderRadius.circular(theme.dragHandleSize.height / 2),
                    ),
                  ),
                ),
              ),

              // Business info content — measured after layout.
              Flexible(
                child: SingleChildScrollView(
                  // Scrolling is handled by the shell's gesture routing.
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
      ),
    );
  }
}
