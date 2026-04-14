import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';

import '../core/interaction_config.dart';
import '../core/viewer_controller.dart';
import '../core/viewer_desktop.dart';
import '../core/viewer_desktop_chrome.dart';
import '../core/viewer_item.dart';
import '../core/viewer_state.dart';
import '../core/viewer_theme.dart';
import '../info_sheet/info_sheet_controller.dart';
import '../widgets/default_viewer_desktop_chrome.dart';
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
///
/// **桌面端**：设置 [ViewerInteractionConfig.desktopUiMode] 为 [ViewerDesktopUiMode.auto]
///（Windows / macOS / Linux 默认）或 [ViewerDesktopUiMode.force]（如 Web 大屏）后，会显示
/// 翻页与缩放等控件，并默认关闭横向滑动翻页、下拉关闭与信息面板上滑（可通过
/// `desktopAllowSwipePaging` 等逐项打开）。默认顶栏可用 [desktopChromeBuilder] **整体替换**；
/// 上下文 [ViewerDesktopChromeContext] 提供关闭、翻页、信息、缩放等全部回调。
/// [MediaViewerController] 另提供 [MediaViewerController.zoomContentIn] 等供外部工具栏调用。
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
    this.backgroundBuilder,
    this.controller,
    this.config = const ViewerInteractionConfig(),
    this.theme = const ViewerTheme(),
    this.onPageChanged,
    this.onInfoStateChanged,
    this.onDismiss,
    this.onBarsVisibilityChanged,
    this.desktopChromeBuilder,
    this.underMediaBuilder,
  })  : onLoadMore = null,
        initialHasMore = false,
        loadThreshold = 0;

  /// 分页模式构造函数。
  const MediaViewer.paging({
    super.key,
    required List<ViewerItem> initialItems,
    required this.onLoadMore,
    required this.pageBuilder,
    this.initialIndex = 0,
    this.initialHasMore = true,
    this.loadThreshold = 2,
    this.infoBuilder,
    this.pageOverlayBuilder,
    this.topBarBuilder,
    this.bottomBarBuilder,
    this.overlayBuilder,
    this.backgroundBuilder,
    this.controller,
    this.config = const ViewerInteractionConfig(),
    this.theme = const ViewerTheme(),
    this.onPageChanged,
    this.onInfoStateChanged,
    this.onDismiss,
    this.onBarsVisibilityChanged,
    this.desktopChromeBuilder,
    this.underMediaBuilder,
  }) : items = initialItems;

  /// 要展示的基础数据列表（分页模式下为初始数据）。
  final List<ViewerItem> items;

  /// 分页加载回调：返回新数据及是否还有更多。
  ///
  /// 调用时机：当 [loadThreshold] 满足且当前未在加载中。
  /// 参数为当前查看器列表中已知的最后一项（可用于业务锚点分析）。
  final Future<PagingResult> Function(ViewerItem lastItem)? onLoadMore;

  /// 初始的分页状态。
  final bool initialHasMore;

  /// 触发预拉取的阈值（默认 2：即滑动到倒数第 2 张时开始加载下一页）。
  final int loadThreshold;

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

  /// 自定义每一页的底层背景（不随内容缩放/位移）。
  final ViewerBackgroundBuilder? backgroundBuilder;

  /// 在媒体缩放层之下、背景层之上的叠加层。
  final ViewerPageOverlayBuilder? underMediaBuilder;

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

  /// 桌面模式（[ViewerInteractionConfig.usesDesktopUi]）下的控件区。
  ///
  /// 为 `null` 时使用 [DefaultViewerDesktopChrome]；返回 [SizedBox.shrink] 可完全隐藏。
  final ViewerDesktopChromeBuilder? desktopChromeBuilder;

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
    ViewerBackgroundBuilder? backgroundBuilder,
    MediaViewerController? controller,
    ViewerInteractionConfig config = const ViewerInteractionConfig(),
    ViewerTheme theme = const ViewerTheme(),
    ValueChanged<int>? onPageChanged,
    ValueChanged<InfoState>? onInfoStateChanged,
    VoidCallback? onDismiss,
    ValueChanged<bool>? onBarsVisibilityChanged,
    ViewerDesktopChromeBuilder? desktopChromeBuilder,
    ViewerPageOverlayBuilder? underMediaBuilder,
  }) {
    return Navigator.of(context).push<T>(
      _ViewerPageRoute<T>(
        builder: (_) => MediaViewer(
          items: items,
          pageBuilder: pageBuilder,
          initialIndex: initialIndex,
          infoBuilder: infoBuilder,
          pageOverlayBuilder: pageOverlayBuilder,
          backgroundBuilder: backgroundBuilder,
          underMediaBuilder: underMediaBuilder,
          controller: controller,
          config: config,
          theme: theme,
          onPageChanged: onPageChanged,
          onInfoStateChanged: onInfoStateChanged,
          onDismiss: onDismiss,
          onBarsVisibilityChanged: onBarsVisibilityChanged,
          topBarBuilder: topBarBuilder,
          bottomBarBuilder: bottomBarBuilder,
          overlayBuilder: overlayBuilder,
          desktopChromeBuilder: desktopChromeBuilder,
        ),
      ),
    );
  }

  /// 开启具备分页能力的查看器。
  static Future<T?> openPaging<T>(
    BuildContext context, {
    required List<ViewerItem> initialItems,
    required Future<PagingResult> Function(ViewerItem lastItem) onLoadMore,
    required ViewerPageBuilder pageBuilder,
    int initialIndex = 0,
    bool initialHasMore = true,
    int loadThreshold = 2,
    ViewerInfoBuilder? infoBuilder,
    ViewerPageOverlayBuilder? pageOverlayBuilder,
    ViewerBarBuilder? topBarBuilder,
    ViewerBarBuilder? bottomBarBuilder,
    ViewerOverlayBuilder? overlayBuilder,
    ViewerBackgroundBuilder? backgroundBuilder,
    MediaViewerController? controller,
    ViewerInteractionConfig config = const ViewerInteractionConfig(),
    ViewerTheme theme = const ViewerTheme(),
    ValueChanged<int>? onPageChanged,
    ValueChanged<InfoState>? onInfoStateChanged,
    VoidCallback? onDismiss,
    ValueChanged<bool>? onBarsVisibilityChanged,
    ViewerDesktopChromeBuilder? desktopChromeBuilder,
    ViewerPageOverlayBuilder? underMediaBuilder,
  }) {
    return Navigator.of(context).push<T>(
      _ViewerPageRoute<T>(
        builder: (_) => MediaViewer.paging(
          initialItems: initialItems,
          onLoadMore: onLoadMore,
          pageBuilder: pageBuilder,
          initialIndex: initialIndex,
          initialHasMore: initialHasMore,
          loadThreshold: loadThreshold,
          infoBuilder: infoBuilder,
          pageOverlayBuilder: pageOverlayBuilder,
          backgroundBuilder: backgroundBuilder,
          underMediaBuilder: underMediaBuilder,
          controller: controller,
          config: config,
          theme: theme,
          onPageChanged: onPageChanged,
          onInfoStateChanged: onInfoStateChanged,
          onDismiss: onDismiss,
          onBarsVisibilityChanged: onBarsVisibilityChanged,
          topBarBuilder: topBarBuilder,
          bottomBarBuilder: bottomBarBuilder,
          overlayBuilder: overlayBuilder,
          desktopChromeBuilder: desktopChromeBuilder,
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

  // 镜像同步状态中心
  InfoState _mirroredInfoState = InfoState.hidden;
  bool _isBroadcastingInfoState = false;

  // 分页管理
  late List<ViewerItem> _internalItems;
  late bool _hasMore;
  bool _isLoadingMore = false;

  // ── 生命周期 ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _internalItems = List.from(widget.items);
    _hasMore = widget.initialHasMore;
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

    _attachControllerCallbacks();

    // 监听首页的缩放，以便切换 PageView 的 physics。
    _pageCtrlAt(_currentIndex).addListener(_onCurrentPageZoomChanged);
  }

  @override
  void didUpdateWidget(MediaViewer old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      _attachControllerCallbacks();
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

  int get _itemCount => _internalItems.length;

  ViewerItem _itemAt(int i) => _internalItems[i];

  InfoSheetController _infoCtrlAt(int i) {
    return _infoControllers.putIfAbsent(
      i,
      () => InfoSheetController(
        vsync: this,
        config: widget.config,
        theme: widget.theme,
        initialState: widget.config.infoSyncMode == InfoSyncMode.mirrored
            ? _mirroredInfoState
            : InfoState.hidden,
      )..addListener(() {
          if (widget.config.infoSyncMode != InfoSyncMode.mirrored) return;
          if (_isBroadcastingInfoState) return;

          final ctrl = _infoControllers[i];
          if (ctrl == null) return;

          // 仅同步稳定的状态（动画结束或被命令式调用后）
          if (ctrl.state != _mirroredInfoState && !ctrl.isDragging) {
            _broadcastInfoState(ctrl.state);
          }
        }),
    );
  }

  void _broadcastInfoState(InfoState newState) {
    _mirroredInfoState = newState;
    _isBroadcastingInfoState = true;
    try {
      for (final ctrl in _infoControllers.values) {
        if (ctrl.state != newState) {
          if (newState == InfoState.shown) {
            ctrl.show(animated: false);
          } else {
            ctrl.hide(animated: false);
          }
        }
      }
    } finally {
      _isBroadcastingInfoState = false;
    }
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

    // 分页判定：滑到临近末尾触发加载
    if (widget.onLoadMore != null && _hasMore && !_isLoadingMore) {
      if (_itemCount - 1 - index <= widget.loadThreshold) {
        _triggerLoadMore();
      }
    }

    widget.controller?.updateIndex(index);
    widget.controller?.updateInfoState(_currentInfoCtrl.state);
    widget.onPageChanged?.call(index);
    setState(() {}); // 刷新顶底栏上下文
  }

  Future<void> _triggerLoadMore() async {
    if (_isLoadingMore) return;
    _isLoadingMore = true;
    try {
      final lastItem = _internalItems.last;
      final result = await widget.onLoadMore!(lastItem);
      if (mounted) {
        setState(() {
          _internalItems.addAll(result.items);
          _hasMore = result.hasMore;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  void _appendItemsFromController(List<ViewerItem> newItems) {
    setState(() {
      _internalItems.addAll(newItems);
    });
  }

  void _attachControllerCallbacks() {
    widget.controller?.attachCallbacks(
      jumpToPage: _jumpToPage,
      showInfo: _showCurrentInfo,
      hideInfo: _hideCurrentInfo,
      setBarsVisible: _setBarsVisibleFromController,
      zoomContentIn: _requestZoomInOnCurrentPage,
      zoomContentOut: _requestZoomOutOnCurrentPage,
      resetContentZoom: _requestZoomResetOnCurrentPage,
      appendItems: _appendItemsFromController,
    );
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

  void _requestZoomInOnCurrentPage() => _pageCtrlAt(_currentIndex)
      .requestProgrammaticZoom(ViewerProgrammaticZoomKind.zoomIn);

  void _requestZoomOutOnCurrentPage() => _pageCtrlAt(_currentIndex)
      .requestProgrammaticZoom(ViewerProgrammaticZoomKind.zoomOut);

  void _requestZoomResetOnCurrentPage() => _pageCtrlAt(_currentIndex)
      .requestProgrammaticZoom(ViewerProgrammaticZoomKind.reset);

  void _animateToPreviousPage() {
    if (_currentIndex <= 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  void _animateToNextPage() {
    if (_currentIndex >= _itemCount - 1) return;
    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  void _toggleInfoFromChrome() {
    final c = _currentInfoCtrl;
    if (c.state == InfoState.shown) {
      c.hide();
    } else {
      c.show();
    }
    widget.onInfoStateChanged?.call(c.state);
    widget.controller?.updateInfoState(c.state);
  }

  void _closeViewerFromChrome() {
    widget.onDismiss?.call();
    if (mounted) Navigator.of(context).pop();
  }

  ViewerDesktopChromeContext _desktopChromeContext(double dismissProgress) {
    final pc = _pageCtrlAt(_currentIndex);
    final item = _itemAt(_currentIndex);
    final hasInfoPanel = item.hasInfo && widget.infoBuilder != null;
    final scale = pc.contentScale;
    const maxS = 5.0;
    return ViewerDesktopChromeContext(
      itemCount: _itemCount,
      currentIndex: _currentIndex,
      currentItem: item,
      closeViewer: _closeViewerFromChrome,
      goToPrevious: _animateToPreviousPage,
      goToNext: _animateToNextPage,
      canGoToPrevious: _currentIndex > 0,
      canGoToNext: _currentIndex < _itemCount - 1,
      toggleInfo: _toggleInfoFromChrome,
      infoState: _currentInfoCtrl.state,
      hasInfoPanel: hasInfoPanel,
      zoomIn: _requestZoomInOnCurrentPage,
      zoomOut: _requestZoomOutOnCurrentPage,
      contentScale: scale,
      canZoomIn: _cfg.enableZoom && scale < maxS - 0.05,
      canZoomOut: _cfg.enableZoom && scale > 1.03,
      controller: widget.controller,
      config: widget.config,
      theme: widget.theme,
      barsVisible: _barsVisible,
      isZoomed: pc.isZoomed,
      dismissProgress: dismissProgress,
    );
  }

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

  bool get _currentHasInfoPanel =>
      _itemAt(_currentIndex).hasInfo && widget.infoBuilder != null;

  ViewerBarContext _barCtx(double dismissProgress) => ViewerBarContext(
        index: _currentIndex,
        itemCount: _itemCount,
        item: _itemAt(_currentIndex),
        infoState: _currentInfoCtrl.state,
        dismissProgress: dismissProgress,
        config: widget.config,
        barsVisible: _barsVisible,
        infoRevealProgress: _currentInfoCtrl.revealProgress,
        isZoomed: _pageCtrlAt(_currentIndex).isZoomed,
        usesDesktopUi: widget.config.usesDesktopUi,
      );

  // ── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    debugPrint('[ViewerLog] MediaViewer.build called');
    final screenH = MediaQuery.of(context).size.height;
    final shellCfg = widget.config.resolveForShell();

    // ── 1. 内容主层（含平移与缩放/分页控制） ──
    final contentLayer = ValueListenableBuilder<double>(
      valueListenable: _dismissOffset,
      builder: (context, rawOffset, _) {
        final progress = _dismissProgress(rawOffset);
        final contentDy = rawOffset * widget.config.viewerDismissDownDamping;

        return Positioned.fill(
          child: Transform.translate(
            offset: Offset(0, contentDy),
            child: ListenableBuilder(
              listenable: _pageCtrlAt(_currentIndex),
              builder: (ctx, _) {
                debugPrint('[ViewerLog] MediaViewer PageView layer rebuild (dismiss: $progress, zoom: ${_pageCtrlAt(_currentIndex).isZoomed})');
                return PhotoViewGestureDetectorScope(
                  axis: Axis.horizontal,
                  child: PageView.builder(
                    controller: _pageController,
                    physics: _pageCtrlAt(_currentIndex).isZoomed
                        ? const NeverScrollableScrollPhysics()
                        : (shellCfg.enableHorizontalPaging
                            ? const BouncingScrollPhysics()
                            : const NeverScrollableScrollPhysics()),
                    onPageChanged: _onPageChanged,
                    itemCount: _itemCount,
                    itemBuilder: (_, i) => ViewerPageShell(
                      key: ValueKey('page_$i'),
                      index: i,
                      itemCount: _itemCount,
                      item: _itemAt(i),
                      infoController: _infoCtrlAt(i),
                      pageController: _pageCtrlAt(i),
                      config: shellCfg,
                      theme: widget.theme,
                      pageBuilder: widget.pageBuilder,
                      infoBuilder: widget.infoBuilder,
                      pageOverlayBuilder: widget.pageOverlayBuilder,
                      backgroundBuilder: widget.backgroundBuilder,
                      underMediaBuilder: widget.underMediaBuilder,
                      barsVisible: _barsVisible,
                      dismissProgress: progress,
                      screenHeight: screenH,
                      onDismissUpdate: _onDismissUpdate,
                      onDismissEnd: _onDismissEnd,
                      onContentTap: _cfg.enableTapToToggleBars ? _toggleBars : null,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );

    // ── 2. 根布局 ──
    Widget stack = Stack(
      children: [
        // 背景层：仅监听下拉位移
        ValueListenableBuilder<double>(
          valueListenable: _dismissOffset,
          builder: (context, rawOffset, _) {
            final progress = _dismissProgress(rawOffset);
            final bgAlpha = (1.0 - progress).clamp(0.0, 1.0);
            return Positioned.fill(
              child: ColoredBox(
                color: widget.theme.backgroundColor.withValues(alpha: bgAlpha),
              ),
            );
          },
        ),

        // 内容平移与分页层
        contentLayer,

        // Desktop UI 层
        if (widget.config.usesDesktopUi)
          ListenableBuilder(
            listenable: Listenable.merge([_dismissOffset, _currentInfoCtrl]),
            builder: (context, _) {
              final progress = _dismissProgress(_dismissOffset.value);
              return Positioned.fill(
                child: widget.desktopChromeBuilder != null
                    ? widget.desktopChromeBuilder!(
                        context,
                        _desktopChromeContext(progress),
                      )
                    : DefaultViewerDesktopChrome(
                        desktopCtx: _desktopChromeContext(progress),
                      ),
              );
            },
          ),

        // 顶底栏层：监听多方状态
        ListenableBuilder(
          listenable: Listenable.merge([
            _dismissOffset,
            _currentInfoCtrl,
            _pageCtrlAt(_currentIndex),
            if (widget.controller != null) widget.controller!,
          ]),
          builder: (ctx, _) {
            final progress = _dismissProgress(_dismissOffset.value);
            final bgAlpha = (1.0 - progress).clamp(0.0, 1.0);
            final barAlpha =
                widget.config.barsFadeWithDismissProgress ? bgAlpha : 1.0;

            return Stack(
              children: [
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
                          duration: widget.theme.barsToggleDuration,
                          curve: widget.theme.barsToggleCurve,
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
                          duration: widget.theme.barsToggleDuration,
                          curve: widget.theme.barsToggleCurve,
                          opacity: _barsVisible ? 1.0 : 0.0,
                          child:
                              widget.bottomBarBuilder!(ctx, _barCtx(progress)),
                        ),
                      ),
                    ),
                  ),

                if (widget.overlayBuilder != null)
                  Positioned.fill(
                    child: widget.overlayBuilder!(ctx, _barCtx(progress)),
                  ),
              ],
            );
          },
        ),
      ],
    );

    // ── 3. 快捷键（桌面版） ──
    if (widget.config.usesDesktopUi) {
      final shortcuts = <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.arrowLeft):
            _animateToPreviousPage,
        const SingleActivator(LogicalKeyboardKey.arrowRight):
            _animateToNextPage,
      };
      if (_cfg.enableZoom) {
        shortcuts[const SingleActivator(
          LogicalKeyboardKey.equal,
          control: true,
        )] = _requestZoomInOnCurrentPage;
        shortcuts[const SingleActivator(
          LogicalKeyboardKey.equal,
          meta: true,
        )] = _requestZoomInOnCurrentPage;
        shortcuts[const SingleActivator(
          LogicalKeyboardKey.numpadAdd,
          control: true,
        )] = _requestZoomInOnCurrentPage;
        shortcuts[const SingleActivator(
          LogicalKeyboardKey.minus,
          control: true,
        )] = _requestZoomOutOnCurrentPage;
        shortcuts[const SingleActivator(
          LogicalKeyboardKey.minus,
          meta: true,
        )] = _requestZoomOutOnCurrentPage;
        shortcuts[const SingleActivator(
          LogicalKeyboardKey.numpadSubtract,
          control: true,
        )] = _requestZoomOutOnCurrentPage;
      }
      shortcuts[const SingleActivator(
        LogicalKeyboardKey.keyI,
        control: true,
      )] = () {
        if (_currentHasInfoPanel) _toggleInfoFromChrome();
      };
      shortcuts[const SingleActivator(
        LogicalKeyboardKey.keyI,
        meta: true,
      )] = () {
        if (_currentHasInfoPanel) _toggleInfoFromChrome();
      };
      shortcuts[const SingleActivator(LogicalKeyboardKey.escape)] =
          _closeViewerFromChrome;

      stack = CallbackShortcuts(
        bindings: shortcuts,
        child: Focus(
          autofocus: true,
          child: stack,
        ),
      );
    }

    return stack;
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

/// 分页加载结果包装。
class PagingResult {
  const PagingResult({
    required this.items,
    required this.hasMore,
  });

  /// 新加载出的项目列表。
  final List<ViewerItem> items;

  /// 是否还可以继续加载下一页。
  final bool hasMore;
}
