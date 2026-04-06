import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

import '../core/interaction_config.dart';
import '../core/viewer_item.dart';
import '../core/viewer_state.dart';
import '../core/viewer_theme.dart';
import '../info_sheet/info_sheet_controller.dart';
import 'media_card_chrome_scope.dart';

// ── 竖向手势模式 ────────────────────────────────────────────────────────────

enum _GestureMode {
  /// 尚未判定，等待足够位移。
  pending,

  /// 向上拖：展开或拉高信息面板。
  expandInfo,

  /// 向下拖：压低或收起信息面板。
  collapseInfo,

  /// 向下拖：关闭查看器（内容跟手下移）。
  dismiss,

  /// 不处理（如已放大），交给子级手势。
  consumed,
}

// ── 下拉关闭回调类型 ─────────────────────────────────────────────────────────

typedef DismissUpdateCallback = void Function(double offset);
typedef DismissEndCallback = void Function(double offset, double velocityY);

// ── ViewerPageShell ───────────────────────────────────────────────────────────

/// 单页复合层：主内容区与信息面板同一层级，左右翻页时一起移动。
///
/// 竖向拖动手势在此分流：交给 [InfoSheetController] 或上层的关闭回调。
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
    required this.barsVisible,
    required this.dismissProgress,
    this.infoBuilder,
    this.pageOverlayBuilder,
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

  /// 不参与缩放的单页叠加层（如 Live 角标），在内容之上、全局顶底栏之下。
  final ViewerPageOverlayBuilder? pageOverlayBuilder;

  final DismissUpdateCallback? onDismissUpdate;
  final DismissEndCallback? onDismissEnd;

  /// 内容区单击（不含信息面板）；由 [MediaViewer] 用于切换顶底栏。
  /// 为 null 时外壳不消费单击。
  final VoidCallback? onContentTap;

  /// 可选传入屏幕高度，减少频繁 [MediaQuery]。
  final double? screenHeight;

  /// 全局顶底栏是否显示。
  final bool barsVisible;

  /// 下拉关闭进度（0.0～1.0）。
  final double dismissProgress;

  @override
  State<ViewerPageShell> createState() => _ViewerPageShellState();
}

class _ViewerPageShellState extends State<ViewerPageShell> {
  _GestureMode _gestureMode = _GestureMode.pending;
  double _dismissRawOffset = 0;

  /// 卡片圆角半径；与 [_AnimatedMediaCardChrome] 动画同步，供 [MediaCardChromeScope] / [ViewerPageContext] 使用。
  ValueNotifier<double>? _mediaCardClipNotifier;

  // 便于壳层在需要时对缩放包装调用 reset（例如翻页复用）。
  final GlobalKey<_ZoomableMediaWrapperState> _zoomKey = GlobalKey();

  // ── 辅助 ───────────────────────────────────────────────────────────────

  InfoSheetController get _info => widget.infoController;
  ViewerInteractionConfig get _cfg => widget.config;

  bool get _hasInfo => widget.item.hasInfo && widget.infoBuilder != null;

  @override
  void initState() {
    super.initState();
    if (_mediaCardChromeEnabled(widget.theme)) {
      _mediaCardClipNotifier =
          ValueNotifier<double>(_mediaCardInitialClipRadius());
    }
  }

  @override
  void dispose() {
    _mediaCardClipNotifier?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ViewerPageShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasOn = _mediaCardChromeEnabled(oldWidget.theme);
    final on = _mediaCardChromeEnabled(widget.theme);
    if (!wasOn && on) {
      _mediaCardClipNotifier =
          ValueNotifier<double>(_mediaCardInitialClipRadius());
    } else if (wasOn && !on) {
      _mediaCardClipNotifier?.dispose();
      _mediaCardClipNotifier = null;
    }
  }

  double _mediaCardInitialClipRadius() {
    final immersed = !widget.barsVisible || widget.pageController.isZoomed;
    return immersed ? 0.0 : widget.theme.mediaCardBorderRadius;
  }

  double _resolveScreenHeight(BuildContext ctx) =>
      widget.screenHeight ?? MediaQuery.of(ctx).size.height;

  // ── 拖动手势 ────────────────────────────────────────────────────────────

  void _onDragStart(DragStartDetails details, double screenH) {
    _dismissRawOffset = 0;
    _gestureMode = _GestureMode.pending;
    _info.setScreenHeight(screenH);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final dy = details.delta.dy;

    // 首次有明显竖向位移时再判定模式。
    if (_gestureMode == _GestureMode.pending) {
      if (dy.abs() < 3) return;

      if (dy < 0) {
        // 向上：仅在手势开启且本页有信息区时展开面板。
        _gestureMode = (_cfg.enableInfoGesture && _hasInfo)
            ? _GestureMode.expandInfo
            : _GestureMode.consumed;
      } else {
        // 向下
        if (_info.state == InfoState.shown) {
          _gestureMode = _cfg.enableInfoGesture
              ? _GestureMode.collapseInfo
              : _GestureMode.consumed;
        } else if (widget.pageController.isZoomed ||
            !_cfg.enableDismissGesture) {
          _gestureMode = _GestureMode.consumed;
        } else {
          _gestureMode = _GestureMode.dismiss;
        }
      }

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

  // ── build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenH = _resolveScreenHeight(context);

    // 先写入高度，便于程序调用 show() 时未到首次拖动也能算对默认高度。
    _info.setScreenHeight(screenH);

    return ListenableBuilder(
      listenable: widget.pageController,
      builder: (ctx, _) {
        final isZoomed = widget.pageController.isZoomed;
        // 放大时不注册竖拖，把单指平移交给 PhotoView；单击切栏放在 PhotoView 的 onTapUp，避免与外层 GestureDetector 抢竞技场。
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragStart:
              isZoomed ? null : (d) => _onDragStart(d, screenH),
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
      barsVisible: widget.barsVisible,
      dismissProgress: widget.dismissProgress,
      mediaCardClipRadiusListenable: _mediaCardClipNotifier,
    );

    final pageOverlay = widget.pageOverlayBuilder?.call(ctx, pageCtx);

    final zoomCore = _ZoomableMediaWrapper(
      key: _zoomKey,
      enabled: _cfg.enableZoom && revealProgress < 0.05,
      enableDoubleTap: _cfg.enableDoubleTapZoom,
      pageController: widget.pageController,
      onSingleTap: _cfg.enableTapToToggleBars ? widget.onContentTap : null,
      child: widget.pageBuilder(ctx, pageCtx),
    );

    final theme = widget.theme;
    Widget mediaZoom = zoomCore;
    if (_mediaCardChromeEnabled(theme)) {
      mediaZoom = ListenableBuilder(
        listenable: widget.pageController,
        builder: (context, _) {
          final immersed =
              !widget.barsVisible || widget.pageController.isZoomed;
          return _AnimatedMediaCardChrome(
            immersed: immersed,
            inset: theme.mediaCardInset,
            borderRadius: theme.mediaCardBorderRadius,
            duration: theme.mediaCardAnimationDuration,
            curve: theme.mediaCardAnimationCurve,
            clipRadiusNotifier: _mediaCardClipNotifier!,
            child: zoomCore,
          );
        },
      );
    }

    return Stack(
      children: [
        // 主内容视口：高度随信息面板上移变矮；内容顶对齐，底部由 ClipRect 裁切。
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: contentH,
          child: _MediaViewportWrapper(
            revealProgress: revealProgress,
            child: mediaZoom,
          ),
        ),

        if (pageOverlay != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: contentH,
            child: pageOverlay,
          ),

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

bool _mediaCardChromeEnabled(ViewerTheme theme) {
  final i = theme.mediaCardInset;
  return theme.mediaCardBorderRadius > 0 ||
      i.left > 0 ||
      i.top > 0 ||
      i.right > 0 ||
      i.bottom > 0;
}

// ── 主内容「卡片」外框动画（在 PhotoView 外，不随缩放变形）────────────────────

class _AnimatedMediaCardChrome extends StatefulWidget {
  const _AnimatedMediaCardChrome({
    required this.immersed,
    required this.inset,
    required this.borderRadius,
    required this.duration,
    required this.curve,
    required this.clipRadiusNotifier,
    required this.child,
  });

  /// true：铺满视口（无外边距、无圆角）。
  final bool immersed;

  final EdgeInsets inset;
  final double borderRadius;
  final Duration duration;
  final Curve curve;

  /// 与 [_curveAnim] 同步写入，供 [MediaCardChromeScope] 监听。
  final ValueNotifier<double> clipRadiusNotifier;

  final Widget child;

  @override
  State<_AnimatedMediaCardChrome> createState() =>
      _AnimatedMediaCardChromeState();
}

class _AnimatedMediaCardChromeState extends State<_AnimatedMediaCardChrome>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curveAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _curveAnim = CurvedAnimation(parent: _controller, curve: widget.curve);
    _curveAnim.addListener(_syncClipRadius);
    _controller.value = widget.immersed ? 1.0 : 0.0;
    _syncClipRadius();
  }

  void _syncClipRadius() {
    final r = lerpDouble(widget.borderRadius, 0.0, _curveAnim.value)!;
    if (widget.clipRadiusNotifier.value != r) {
      widget.clipRadiusNotifier.value = r;
    }
  }

  @override
  void didUpdateWidget(_AnimatedMediaCardChrome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (oldWidget.immersed != widget.immersed) {
      if (widget.immersed) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
    if (oldWidget.borderRadius != widget.borderRadius) {
      _syncClipRadius();
    }
  }

  @override
  void dispose() {
    _curveAnim.removeListener(_syncClipRadius);
    _curveAnim.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curveAnim,
      builder: (context, child) {
        final v = _curveAnim.value;
        final pad = EdgeInsets.lerp(widget.inset, EdgeInsets.zero, v)!;
        return Padding(
          padding: pad,
          child: MediaCardChromeScope(
            clipRadiusListenable: widget.clipRadiusNotifier,
            child: child!,
          ),
        );
      },
      child: widget.child,
    );
  }
}

// ── 主内容视口对齐插值 ───────────────────────────────────────────────────────

/// 随 [revealProgress] 在「垂直居中」与「顶对齐」之间插值；底部溢出裁掉，不盖住信息面板。
///
/// - `0`：全屏看时内容居中。
/// - 趋向 `1`：媒体顶边贴视口顶，便于与上拉面板衔接。
/// - 大于 `1`：保持顶对齐。
class _MediaViewportWrapper extends StatelessWidget {
  const _MediaViewportWrapper({
    required this.child,
    required this.revealProgress,
  });

  final Widget child;

  /// 0 = 信息隐藏（居中），1 及以上 = 信息展开（顶对齐）。
  final double revealProgress;

  @override
  Widget build(BuildContext context) {
    // Alignment.center 的 y 为 0，topCenter 为 -1；在 0～1 间插值。
    final alignY = -(revealProgress.clamp(0.0, 1.0));
    return ClipRect(
      child: Align(
        alignment: Alignment(0, alignY),
        child: child,
      ),
    );
  }
}

// ── PhotoView 缩放包装 ───────────────────────────────────────────────────────

/// 用 [PhotoView.customChild] 包一层业务子组件：双指缩放、双击放大/还原、边界内平移。
///
/// 与 [MediaViewer] 外层的 [PhotoViewGestureDetectorScope] 配合，避免横滑翻页与双指缩放抢手势。
/// 缩放状态写入 [ViewerPageController]，供壳层关闭竖拖、禁止 PageView 滑动。
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

  /// PhotoView 在确认「非双击」后的单击回调，用于切换顶底栏。
  final VoidCallback? onSingleTap;

  @override
  State<_ZoomableMediaWrapper> createState() => _ZoomableMediaWrapperState();
}

class _ZoomableMediaWrapperState extends State<_ZoomableMediaWrapper>
    with SingleTickerProviderStateMixin {
  late final PhotoViewController _photoCtrl;
  late final PhotoViewScaleStateController _scaleStateCtrl;
  late final AnimationController _animCtrl;

  /// 与 PhotoView 可视区域一致，用于取视口中心的全局坐标（与 controller.position 同坐标系）。
  final GlobalKey _photoViewportKey = GlobalKey();

  Animation<double>? _scaleAnim;
  Animation<Offset>? _positionAnim;

  // 每次 onTapDown 更新；双击第二下按下时的坐标即为缩放中心。
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
    widget.pageController.addListener(_onPageCtrlForProgrammaticZoom);
  }

  @override
  void didUpdateWidget(_ZoomableMediaWrapper old) {
    super.didUpdateWidget(old);
    // 信息面板将起时关闭缩放：立即回到 1×。
    if (old.enabled && !widget.enabled && _isZoomed) {
      _animCtrl.stop();
      _photoCtrl.updateMultiple(scale: _kMinScale, position: Offset.zero);
      _scaleStateCtrl.scaleState = PhotoViewScaleState.initial;
      widget.pageController.reportContentScale(_kMinScale);
    }
  }

  @override
  void dispose() {
    widget.pageController.removeListener(_onPageCtrlForProgrammaticZoom);
    _animCtrl.removeListener(_onAnimTick);
    _photoCtrl.dispose();
    _scaleStateCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // ── 辅助 ───────────────────────────────────────────────────────────────

  bool get _isZoomed => (_photoCtrl.scale ?? _kMinScale) > 1.02;

  void _onPageCtrlForProgrammaticZoom() {
    final kind = widget.pageController.takeProgrammaticZoom();
    if (kind == null) return;
    if (!widget.enabled) return;
    switch (kind) {
      case ViewerProgrammaticZoomKind.zoomIn:
        _applyStepScale(1.2);
      case ViewerProgrammaticZoomKind.zoomOut:
        _applyStepScale(1 / 1.2);
      case ViewerProgrammaticZoomKind.reset:
        _programmaticResetScale();
    }
  }

  void _applyStepScale(double factor) {
    _animCtrl.stop();
    final cur = _photoCtrl.scale ?? _kMinScale;
    final next = (cur * factor).clamp(_kMinScale, _kMaxScale);
    if ((next - cur).abs() < 0.002) return;
    final pos = _photoCtrl.position;
    final ratio = next / cur;

    // PhotoView 内部 position 与缩放手势 focal 一致，均为全局坐标；锚点须用视口中心的全局坐标。
    final box =
        _photoViewportKey.currentContext?.findRenderObject() as RenderBox?;
    Offset newPos;
    if (box != null && box.hasSize) {
      final centerGlobal = box.localToGlobal(
        Offset(box.size.width / 2, box.size.height / 2),
      );
      newPos = Offset(
        centerGlobal.dx + (pos.dx - centerGlobal.dx) * ratio,
        centerGlobal.dy + (pos.dy - centerGlobal.dy) * ratio,
      );
    } else {
      // 尚无布局时退化为与捏合「焦点不动」时类似的比例平移，避免锚到错误局部坐标。
      newPos = Offset(pos.dx * ratio, pos.dy * ratio);
    }

    _photoCtrl.updateMultiple(scale: next, position: newPos);
    _scaleStateCtrl.scaleState = next > _kMinScale + 0.02
        ? PhotoViewScaleState.zoomedIn
        : PhotoViewScaleState.initial;
  }

  void _programmaticResetScale() {
    _animCtrl.stop();
    _photoCtrl.updateMultiple(scale: _kMinScale, position: Offset.zero);
    _scaleStateCtrl.scaleState = PhotoViewScaleState.initial;
    widget.pageController.reportContentScale(_kMinScale);
  }

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

  // 双击走 PhotoView 的 scaleStateCycle，勿再包一层 GestureDetector(onDoubleTap)，
  // 否则内层 DoubleTapGestureRecognizer 永远胜出，外层不会触发。

  void _onPhotoViewTapDown(
    BuildContext _,
    TapDownDetails details,
    PhotoViewControllerValue __,
  ) {
    _lastTapPosition = details.localPosition;
  }

  void _onPhotoViewTapUp(
    BuildContext _,
    TapUpDetails details,
    PhotoViewControllerValue __,
  ) {
    widget.onSingleTap?.call();
  }

  PhotoViewScaleState _handleDoubleTap(PhotoViewScaleState currentState) {
    if (!widget.enableDoubleTap) {
      return currentState;
    }

    _runDoubleTapAnimation();
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
    } else {
      const s = _kDoubleTapScale;
      targetScale = s;
      // 视口位置 ≈ scale * 子坐标 + position；令点击处在缩放前后屏幕位置不变：
      // targetPosition = -tap * (s - 1)
      targetPosition = Offset(
        -_lastTapPosition.dx * (s - 1),
        -_lastTapPosition.dy * (s - 1),
      );
    }

    final curved = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeInOutCubic,
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

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return SizedBox.expand(
      key: _photoViewportKey,
      child: PhotoView.customChild(
        controller: _photoCtrl,
        scaleStateController: _scaleStateCtrl,
        // tightMode：子级约束为视口尺寸，边界夹紧无需额外 childSize。
        tightMode: true,
        minScale: _kMinScale,
        maxScale: _kMaxScale,
        initialScale: _kMinScale,
        backgroundDecoration: const BoxDecoration(color: Colors.transparent),
        gestureDetectorBehavior: HitTestBehavior.translucent,
        onTapDown: _onPhotoViewTapDown,
        onTapUp: widget.onSingleTap != null ? _onPhotoViewTapUp : null,
        scaleStateCycle: _handleDoubleTap,
        child: widget.child,
      ),
    );
  }
}

// ── 信息面板外观（圆角、拖条、业务内容）────────────────────────────────────────

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
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 使用 Positioned 传入的有限高度，避免 Column+Flexible 在 OverflowBox 下出现
          // size: MISSING（上滑 info 时 hit test 崩溃）。
          final maxH = constraints.maxHeight.clamp(0.0, double.infinity);
          // 动画初期 sheet 高度可能小于拖条设计高度 28，固定 28 会导致底部溢出。
          final handleH = maxH <= 0 ? 0.0 : (maxH < 28 ? maxH : 28.0);
          return Container(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: theme.infoBorderRadius,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (handleH > 0)
                  SizedBox(
                    height: handleH,
                    child: Center(
                      child: Container(
                        width: theme.dragHandleSize.width,
                        height: theme.dragHandleSize.height,
                        decoration: BoxDecoration(
                          color: handleColor,
                          borderRadius: BorderRadius.circular(
                              theme.dragHandleSize.height / 2),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(),
                    child: KeyedSubtree(
                      key: _contentKey,
                      child: widget.child,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
