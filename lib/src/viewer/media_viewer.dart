import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';

import '../core/interaction_config.dart';
import '../core/viewer_controller.dart';
import '../core/viewer_item.dart';
import '../core/viewer_state.dart';
import '../core/viewer_theme.dart';
import '../info_sheet/info_sheet_controller.dart';
import 'viewer_page_shell.dart';

// ── MediaViewer ───────────────────────────────────────────────────────────────

/// 全屏媒体查看主组件。
///
/// ## 层级结构
/// ```
/// Stack
///  ├── 背景（下拉关闭时变淡，透出下层路由）
///  ├── Transform.translate → PageView.builder
///  │     └── ViewerPageShell（每页：主内容 + 信息面板同层）
///  ├── 顶栏（固定，可随关闭进度改透明度）
///  └── 底栏（固定，可随关闭进度改透明度）
/// ```
///
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
/// 推荐全屏时用路由打开：
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
    this.pageOverlayBuilder,
    this.topBarBuilder,
    this.bottomBarBuilder,
    this.overlayBuilder,
    this.controller,
    this.config = const ViewerInteractionConfig(),
    this.theme = const ViewerTheme(),
    this.onPageChanged,
    this.onInfoStateChanged,
    this.onDismiss,
    this.onBarsVisibilityChanged,
  });

  /// 要展示的数据列表。
  final List<ViewerItem> items;

  /// 每一页主内容，必填。
  final ViewerPageBuilder pageBuilder;

  /// 打开时默认显示的下标。
  final int initialIndex;

  /// 每一页信息面板内部；为 null 时全局关闭上滑信息手势。
  final ViewerInfoBuilder? infoBuilder;

  /// 单页叠加层（不随缩放动），在全局顶底栏之下；某页不需要可返回 null。
  final ViewerPageOverlayBuilder? pageOverlayBuilder;

  /// 顶部固定栏；下拉关闭时本身不位移，可配透明度联动。
  final ViewerBarBuilder? topBarBuilder;

  /// 底部固定栏。
  final ViewerBarBuilder? bottomBarBuilder;

  /// 叠在所有层之上的浮层（默认不参与下拉关闭的透明度联动，由业务自控）。
  final ViewerOverlayBuilder? overlayBuilder;

  /// 可选外部控制器，用于跳转页、显隐信息/顶底栏等。
  final MediaViewerController? controller;

  final ViewerInteractionConfig config;
  final ViewerTheme theme;

  /// 当前页下标变化时回调。
  final ValueChanged<int>? onPageChanged;

  /// 当前页信息面板枚举状态变化时回调。
  final ValueChanged<InfoState>? onInfoStateChanged;

  /// 手势判定即将关闭查看器时回调（在 [Navigator.pop] 之前）。
  final VoidCallback? onDismiss;

  /// 顶底栏显隐切换时回调（单击内容区等）；参数为当前是否显示。
  final ValueChanged<bool>? onBarsVisibilityChanged;

  /// 以半透明路由压入 [MediaViewer]（便于下拉透出下层、Hero 正常）。
  static Future<T?> open<T>(
    BuildContext context, {
    required List<ViewerItem> items,
    required ViewerPageBuilder pageBuilder,
    int initialIndex = 0,
    ViewerInfoBuilder? infoBuilder,
    ViewerPageOverlayBuilder? pageOverlayBuilder,
    ViewerBarBuilder? topBarBuilder,
    ViewerBarBuilder? bottomBarBuilder,
    ViewerOverlayBuilder? overlayBuilder,
    MediaViewerController? controller,
    ViewerInteractionConfig config = const ViewerInteractionConfig(),
    ViewerTheme theme = const ViewerTheme(),
    ValueChanged<int>? onPageChanged,
    ValueChanged<InfoState>? onInfoStateChanged,
    VoidCallback? onDismiss,
    ValueChanged<bool>? onBarsVisibilityChanged,
  }) {
    return Navigator.of(context).push<T>(
      _ViewerPageRoute<T>(
        builder: (_) => MediaViewer(
          items: items,
          pageBuilder: pageBuilder,
          initialIndex: initialIndex,
          infoBuilder: infoBuilder,
          pageOverlayBuilder: pageOverlayBuilder,
          topBarBuilder: topBarBuilder,
          bottomBarBuilder: bottomBarBuilder,
          overlayBuilder: overlayBuilder,
          controller: controller,
          config: config,
          theme: theme,
          onPageChanged: onPageChanged,
          onInfoStateChanged: onInfoStateChanged,
          onDismiss: onDismiss,
          onBarsVisibilityChanged: onBarsVisibilityChanged,
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
  // 横向翻页
  late PageController _pageController;
  int _currentIndex = 0;

  // 每页一个信息面板控制器（懒创建，常驻）。
  final Map<int, InfoSheetController> _infoControllers = {};

  // 每页一个缩放上报控制器。
  final Map<int, ViewerPageController> _pageControllers = {};

  // 未达关闭阈值时的回弹动画
  late AnimationController _dismissSnapController;
  final ValueNotifier<double> _dismissOffset = ValueNotifier(0);
  double _dismissSnapFrom = 0;

  // 顶底栏显隐（单击内容切换）
  bool _barsVisible = true;

  // ── 生命周期 ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, _itemCount - 1);
    _pageController = PageController(initialPage: _currentIndex);

    _dismissSnapController = AnimationController(
      vsync: this,
      duration: widget.theme.dismissSnapBackDuration,
    )..addListener(() {
        final t = widget.theme.dismissSnapBackCurve
            .transform(_dismissSnapController.value);
        _dismissOffset.value = _dismissSnapFrom * (1 - t);
      });

    widget.controller?.attachCallbacks(
      jumpToPage: _jumpToPage,
      showInfo: _showCurrentInfo,
      hideInfo: _hideCurrentInfo,
      setBarsVisible: _setBarsVisibleFromController,
    );

    // 监听首页的缩放，以便切换 PageView 的 physics。
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
        setBarsVisible: _setBarsVisibleFromController,
      );
    }
  }

  @override
  void dispose() {
    // 关闭查看器时始终恢复系统栏，与当前栏显隐无关。
    if (widget.config.enableSystemUiToggle) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
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

  // ── 工具 ─────────────────────────────────────────────────────────────────

  ViewerInteractionConfig get _cfg => widget.config;

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

  // 缩放跨越阈值时触发 rebuild，更新 PageView 是否可横滑。
  void _onCurrentPageZoomChanged() => setState(() {});

  // ── 翻页 ─────────────────────────────────────────────────────────────────

  void _onPageChanged(int index) {
    _pageCtrlAt(_currentIndex).removeListener(_onCurrentPageZoomChanged);
    _currentIndex = index;
    _pageCtrlAt(_currentIndex).addListener(_onCurrentPageZoomChanged);

    widget.controller?.updateIndex(index);
    widget.controller?.updateInfoState(_currentInfoCtrl.state);
    widget.onPageChanged?.call(index);
    setState(() {}); // 刷新顶底栏上下文
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

  // ── 下拉关闭 ────────────────────────────────────────────────────────────

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

  // ── 顶底栏（单击内容切换）────────────────────────────────────────────────

  void _toggleBars() {
    setState(() => _barsVisible = !_barsVisible);
    widget.controller?.updateBarsVisible(_barsVisible);
    widget.onBarsVisibilityChanged?.call(_barsVisible);
    _applySystemUi(_barsVisible);
  }

  /// 由 [MediaViewerController.showBars] / [hideBars] / [setBarsVisible] 调用。
  void _setBarsVisibleFromController(bool visible) {
    if (_barsVisible == visible) return;
    setState(() => _barsVisible = visible);
    widget.onBarsVisibilityChanged?.call(_barsVisible);
    _applySystemUi(_barsVisible);
  }

  void _applySystemUi(bool barsVisible) {
    if (!_cfg.enableSystemUiToggle) return;
    if (barsVisible) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  // ── 构造顶底栏上下文 ─────────────────────────────────────────────────────

  ViewerBarContext _barCtx(double dismissProgress) => ViewerBarContext(
        index: _currentIndex,
        item: _itemAt(_currentIndex),
        infoState: _currentInfoCtrl.state,
        dismissProgress: dismissProgress,
        config: widget.config,
        barsVisible: _barsVisible,
        infoRevealProgress: _currentInfoCtrl.revealProgress,
        isZoomed: _pageCtrlAt(_currentIndex).isZoomed,
      );

  // ── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;

    // 同时监听下拉位移与当前页信息控制器：拖动关闭与信息面板动画都会刷新顶底栏。
    // Listenable.merge 在每次 build 新建，但 build 仅由 setState 触发，开销可接受。
    return ListenableBuilder(
      listenable: Listenable.merge([_dismissOffset, _currentInfoCtrl]),
      builder: (ctx, _) {
        final rawOffset = _dismissOffset.value;
        final progress = _dismissProgress(rawOffset);
        final contentDy = rawOffset * widget.config.viewerDismissDownDamping;
        final bgAlpha = (1.0 - progress).clamp(0.0, 1.0);
        final barAlpha =
            widget.config.barsFadeWithDismissProgress ? bgAlpha : 1.0;

        return Stack(
          children: [
            // 背景（路由非不透明，可透出下层）
            Positioned.fill(
              child: ColoredBox(
                color: widget.theme.backgroundColor.withValues(alpha: bgAlpha),
              ),
            ),

            // 分页内容（随下拉平移）
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(0, contentDy),
                // 与壳内 PhotoView.customChild 配合：双指缩放优先于 PageView 横滑。
                child: PhotoViewGestureDetectorScope(
                  axis: Axis.horizontal,
                  child: PageView.builder(
                    controller: _pageController,
                    // 放大时禁止横滑，单指拖动交给 PhotoView。
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
                      pageOverlayBuilder: widget.pageOverlayBuilder,
                      barsVisible: _barsVisible,
                      dismissProgress: progress,
                      screenHeight: screenH,
                      onDismissUpdate: _onDismissUpdate,
                      onDismissEnd: _onDismissEnd,
                      onContentTap:
                          _cfg.enableTapToToggleBars ? _toggleBars : null,
                    ),
                  ),
                ),
              ),
            ),

            // 顶栏：外层 Opacity 跟下拉进度；内层 AnimatedOpacity 跟单击显隐。
            // IgnorePointer：隐藏时不抢点击。
            if (widget.topBarBuilder != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  ignoring: !_barsVisible,
                  child: Opacity(
                    opacity: barAlpha,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      opacity: _barsVisible ? 1.0 : 0.0,
                      child: widget.topBarBuilder!(ctx, _barCtx(progress)),
                    ),
                  ),
                ),
              ),

            if (widget.bottomBarBuilder != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  ignoring: !_barsVisible,
                  child: Opacity(
                    opacity: barAlpha,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      opacity: _barsVisible ? 1.0 : 0.0,
                      child: widget.bottomBarBuilder!(ctx, _barCtx(progress)),
                    ),
                  ),
                ),
              ),

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

/// 非不透明路由：下拉时可透出上一页，且利于 Hero。
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
    // 透明 Material：顶栏、pageBuilder 里用 ListTile、Chip 等不必再包一层。
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
    // 进退场由 MediaViewer 自己用背景与位移表现；此处仅轻量淡入，避免挡 Hero。
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
