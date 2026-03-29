import 'package:flutter/material.dart';

import '../core/interaction_config.dart';
import '../core/viewer_controller.dart';
import '../core/viewer_item.dart';
import '../core/viewer_state.dart';
import '../core/viewer_theme.dart';
import '../info_sheet/info_sheet_controller.dart';
import 'viewer_page_shell.dart';

// ── MediaViewer ───────────────────────────────────────────────────────────────

/// The main viewer widget.
///
/// ## Layout
/// ```
/// Stack
///  ├── Background (fades out during dismiss)
///  ├── Transform.translate → PageView.builder
///  │     └── ViewerPageShell(index)  ← content + info, same layer
///  ├── TopOverlay     (fixed position, alpha-only dismiss linkage)
///  └── BottomOverlay  (fixed position, alpha-only dismiss linkage)
/// ```
///
/// ## Usage
/// ```dart
/// MediaViewer(
///   items: myItems,
///   initialIndex: 2,
///   pageBuilder: (ctx, pageCtx) => Image.network(pageCtx.item.payload),
///   infoBuilder: (ctx, pageCtx) => MyInfoWidget(pageCtx.item),
///   topBarBuilder: (ctx, barCtx) => MyTopBar(barCtx),
/// )
/// ```
///
/// Or push it as a route (recommended for full-screen use):
/// ```dart
/// MediaViewer.open(context, items: myItems, ...);
/// ```
class MediaViewer extends StatefulWidget {
  const MediaViewer({
    super.key,
    required this.items,
    required this.pageBuilder,
    this.initialIndex = 0,
    this.infoBuilder,
    this.topBarBuilder,
    this.bottomBarBuilder,
    this.overlayBuilder,
    this.controller,
    this.config = const ViewerInteractionConfig(),
    this.theme = const ViewerTheme(),
    this.onPageChanged,
    this.onInfoStateChanged,
    this.onDismiss,
  });

  /// The ordered list of items to display.
  final List<ViewerItem> items;

  /// Builds the content for each page. Required.
  final ViewerPageBuilder pageBuilder;

  /// Index of the page to display on open.
  final int initialIndex;

  /// Builds the info sheet content per page.
  /// Return a widget; the framework wraps it in the sheet surface.
  /// When null, info gestures are globally disabled.
  final ViewerInfoBuilder? infoBuilder;

  /// Builds the fixed top-bar overlay (not translated during dismiss).
  final ViewerBarBuilder? topBarBuilder;

  /// Builds the fixed bottom-bar overlay (not translated during dismiss).
  final ViewerBarBuilder? bottomBarBuilder;

  /// Additional overlay drawn above everything (not alpha-linked to dismiss).
  final ViewerOverlayBuilder? overlayBuilder;

  /// External controller for programmatic control.
  final MediaViewerController? controller;

  final ViewerInteractionConfig config;
  final ViewerTheme theme;

  /// Called whenever the visible page index changes.
  final ValueChanged<int>? onPageChanged;

  /// Called whenever the current page's info state changes.
  final ValueChanged<InfoState>? onInfoStateChanged;

  /// Called when the viewer is about to be dismissed by gesture.
  final VoidCallback? onDismiss;

  /// Push the viewer as a full-screen route.
  static Future<T?> open<T>(
    BuildContext context, {
    required List<ViewerItem> items,
    required ViewerPageBuilder pageBuilder,
    int initialIndex = 0,
    ViewerInfoBuilder? infoBuilder,
    ViewerBarBuilder? topBarBuilder,
    ViewerBarBuilder? bottomBarBuilder,
    ViewerOverlayBuilder? overlayBuilder,
    MediaViewerController? controller,
    ViewerInteractionConfig config = const ViewerInteractionConfig(),
    ViewerTheme theme = const ViewerTheme(),
    ValueChanged<int>? onPageChanged,
    ValueChanged<InfoState>? onInfoStateChanged,
    VoidCallback? onDismiss,
  }) {
    // Import ViewerRoute via relative path resolved at call-site.
    // Use a transparent ModalRoute so the previous page is visible during dismiss.
    return Navigator.of(context).push<T>(
      _ViewerPageRoute<T>(
        builder: (_) => MediaViewer(
          items: items,
          pageBuilder: pageBuilder,
          initialIndex: initialIndex,
          infoBuilder: infoBuilder,
          topBarBuilder: topBarBuilder,
          bottomBarBuilder: bottomBarBuilder,
          overlayBuilder: overlayBuilder,
          controller: controller,
          config: config,
          theme: theme,
          onPageChanged: onPageChanged,
          onInfoStateChanged: onInfoStateChanged,
          onDismiss: onDismiss,
        ),
      ),
    );
  }

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

// ── _MediaViewerState ─────────────────────────────────────────────────────────

class _MediaViewerState extends State<MediaViewer>
    with TickerProviderStateMixin {
  // Pager
  late PageController _pageController;
  int _currentIndex = 0;

  // Per-page info controllers (lazily created, kept alive).
  final Map<int, InfoSheetController> _infoControllers = {};

  // Per-page page controllers (zoom reporting).
  final Map<int, ViewerPageController> _pageControllers = {};

  // Dismiss animation
  late AnimationController _dismissSnapController;
  final ValueNotifier<double> _dismissOffset = ValueNotifier(0);
  double _dismissSnapFrom = 0;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, _itemCount - 1);
    _pageController = PageController(initialPage: _currentIndex);

    _dismissSnapController = AnimationController(
      vsync: this,
      duration: widget.theme.dismissSnapBackDuration,
    )..addListener(() {
        final t =
            widget.theme.dismissSnapBackCurve.transform(_dismissSnapController.value);
        _dismissOffset.value = _dismissSnapFrom * (1 - t);
      });

    widget.controller?.attachCallbacks(
      jumpToPage: _jumpToPage,
      showInfo: _showCurrentInfo,
      hideInfo: _hideCurrentInfo,
    );

    // Listen to the initial page's zoom state so PageView physics can update.
    _pageCtrlAt(_currentIndex).addListener(_onCurrentPageZoomChanged);
  }

  @override
  void didUpdateWidget(MediaViewer old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      widget.controller?.attachCallbacks(
        jumpToPage: _jumpToPage,
        showInfo: _showCurrentInfo,
        hideInfo: _hideCurrentInfo,
      );
    }
  }

  @override
  void dispose() {
    _pageCtrlAt(_currentIndex).removeListener(_onCurrentPageZoomChanged);
    for (final c in _infoControllers.values) {
      c.dispose();
    }
    for (final c in _pageControllers.values) {
      c.dispose();
    }
    _dismissOffset.dispose();
    _dismissSnapController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  int get _itemCount => widget.items.length;

  ViewerItem _itemAt(int i) => widget.items[i];

  InfoSheetController _infoCtrlAt(int i) {
    return _infoControllers.putIfAbsent(
      i,
      () => InfoSheetController(
        vsync: this,
        config: widget.config,
        theme: widget.theme,
      ),
    );
  }

  ViewerPageController _pageCtrlAt(int i) {
    return _pageControllers.putIfAbsent(i, ViewerPageController.new);
  }

  InfoSheetController get _currentInfoCtrl => _infoCtrlAt(_currentIndex);

  // Rebuild when current page zoom changes so PageView physics updates.
  void _onCurrentPageZoomChanged() => setState(() {});

  // ── Page change ───────────────────────────────────────────────────────────

  void _onPageChanged(int index) {
    // Re-subscribe zoom listener to the new page's controller.
    _pageCtrlAt(_currentIndex).removeListener(_onCurrentPageZoomChanged);
    _currentIndex = index;
    _pageCtrlAt(_currentIndex).addListener(_onCurrentPageZoomChanged);

    widget.controller?.updateIndex(index);
    widget.controller?.updateInfoState(_currentInfoCtrl.state);
    widget.onPageChanged?.call(index);
    setState(() {}); // Rebuild bar context.
  }

  void _jumpToPage() {
    final target = widget.controller?.pendingJumpIndex ?? 0;
    _pageController.animateToPage(
      target.clamp(0, _itemCount - 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  void _showCurrentInfo() => _currentInfoCtrl.show();
  void _hideCurrentInfo() => _currentInfoCtrl.hide();

  // ── Dismiss handling ──────────────────────────────────────────────────────

  void _onDismissUpdate(double offset) {
    _dismissSnapController.stop();
    _dismissOffset.value = offset;
    final progress = _dismissProgress(offset);
    widget.controller?.updateDismissProgress(progress);
  }

  void _onDismissEnd(double offset, double velocityY) {
    final cfg = widget.config;
    final shouldDismiss = offset > cfg.dismissDistanceThreshold ||
        velocityY > cfg.dismissVelocityThreshold;

    if (shouldDismiss) {
      widget.onDismiss?.call();
      if (mounted) Navigator.of(context).pop();
    } else {
      _snapDismissBack(offset);
    }
  }

  void _snapDismissBack(double fromOffset) {
    _dismissSnapFrom = fromOffset;
    _dismissSnapController.forward(from: 0).then((_) {
      _dismissOffset.value = 0;
      widget.controller?.updateDismissProgress(0);
    });
  }

  double _dismissProgress(double offset) {
    final range = MediaQuery.of(context).size.height * 0.4;
    return (offset / range).clamp(0.0, 1.0);
  }

  // ── Bar context builder ───────────────────────────────────────────────────

  ViewerBarContext _barCtx(double dismissProgress) => ViewerBarContext(
        index: _currentIndex,
        item: _itemAt(_currentIndex),
        infoState: _currentInfoCtrl.state,
        dismissProgress: dismissProgress,
        config: widget.config,
      );

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;

    return ValueListenableBuilder<double>(
      valueListenable: _dismissOffset,
      builder: (ctx, rawOffset, _) {
        final progress = _dismissProgress(rawOffset);
        final contentDy =
            rawOffset * widget.config.viewerDismissDownDamping;
        final bgAlpha = (1.0 - progress).clamp(0.0, 1.0);
        final barAlpha = widget.config.barsFadeWithDismissProgress
            ? bgAlpha
            : 1.0;

        return Stack(
          children: [
            // ── Background ────────────────────────────────────────────────
            // Fades out so the previous route shows through (ViewerRoute is
            // non-opaque).
            Positioned.fill(
              child: ColoredBox(
                  color: widget.theme.backgroundColor.withValues(alpha: bgAlpha),
              ),
            ),

            // ── Paged content (translated during dismiss) ─────────────────
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(0, contentDy),
                child: PageView.builder(
                  controller: _pageController,
                  // Disable paging while zoomed so InteractiveViewer can pan.
                  physics: _pageCtrlAt(_currentIndex).isZoomed
                      ? const NeverScrollableScrollPhysics()
                      : (widget.config.enableHorizontalPaging
                          ? const BouncingScrollPhysics()
                          : const NeverScrollableScrollPhysics()),
                  onPageChanged: _onPageChanged,
                  itemCount: _itemCount,
                  itemBuilder: (_, i) => ViewerPageShell(
                    key: ValueKey('page_$i'),
                    index: i,
                    item: _itemAt(i),
                    infoController: _infoCtrlAt(i),
                    pageController: _pageCtrlAt(i),
                    config: widget.config,
                    theme: widget.theme,
                    pageBuilder: widget.pageBuilder,
                    infoBuilder: widget.infoBuilder,
                    screenHeight: screenH,
                    onDismissUpdate: _onDismissUpdate,
                    onDismissEnd: _onDismissEnd,
                  ),
                ),
              ),
            ),

            // ── Top bar (fixed, alpha only) ────────────────────────────────
            if (widget.topBarBuilder != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: barAlpha,
                  child: widget.topBarBuilder!(ctx, _barCtx(progress)),
                ),
              ),

            // ── Bottom bar (fixed, alpha only) ────────────────────────────
            if (widget.bottomBarBuilder != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: barAlpha,
                  child: widget.bottomBarBuilder!(ctx, _barCtx(progress)),
                ),
              ),

            // ── Extra overlay ─────────────────────────────────────────────
            if (widget.overlayBuilder != null)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: false,
                  child: widget.overlayBuilder!(ctx, _barCtx(progress)),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── _ViewerPageRoute ──────────────────────────────────────────────────────────

/// A transparent modal route that lets the previous page show through.
/// This enables the "see-through background during dismiss" effect and
/// keeps Hero animations working correctly.
class _ViewerPageRoute<T> extends PageRoute<T> {
  _ViewerPageRoute({required this.builder});

  final WidgetBuilder builder;

  @override
  bool get opaque => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 280);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    // Wrap in a transparent Material so that Material-dependent widgets used
    // inside topBarBuilder / pageBuilder (Chip, ListTile, etc.) work without
    // the business needing to provide their own Material ancestor.
    return Material(
      type: MaterialType.transparency,
      child: builder(context),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // No framework transition — the MediaViewer manages its own entry/exit
    // animation via the background colour and content offset.
    // Hero animations work because the route is non-opaque and we don't
    // replace the hero with a fade here.
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
      child: child,
    );
  }
}
