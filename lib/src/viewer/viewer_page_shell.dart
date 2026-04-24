import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../yuni_photo_view.dart';
import '../core/interaction_config.dart';
import '../core/viewer_item.dart';
import '../core/viewer_state.dart';
import '../core/viewer_theme.dart';
import '../info_sheet/info_sheet_controller.dart';
import '../widgets/viewer_media_cover_frame.dart' show InfoRevealScope;
import 'media_card_chrome_scope.dart';
import 'photo_view_zoom_engine.dart';
import 'zoom_engine.dart';

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

// ── 信息面板进度注入 ─────────────────────────────────────────────────────────
// InfoRevealScope 定义在 viewer_media_cover_frame.dart，此处通过 import 使用。

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
    required this.itemCount,
    required this.item,
    required this.infoController,
    required this.pageController,
    required this.config,
    required this.theme,
    required this.pageBuilder,
    this.backgroundBuilder,
    this.underMediaBuilder,
    required this.barsVisible,
    this.barsVisibleNotifier,
    required this.dismissProgress,
    this.infoBuilder,
    this.pageOverlayBuilder,
    this.onDismissUpdate,
    this.onDismissEnd,
    this.onContentTap,
    this.screenHeight,
    this.controller,
  });

  final MediaViewerController? controller;

  final int index;
  final int itemCount;
  final ViewerItem item;
  final InfoSheetController infoController;
  final ViewerPageController pageController;
  final ViewerInteractionConfig config;
  final ViewerTheme theme;

  final ViewerPageBuilder pageBuilder;
  final ViewerBackgroundBuilder? backgroundBuilder;
  final ViewerPageOverlayBuilder? underMediaBuilder;
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

  /// 顶底栏显隐状态的监听器，用于 _AnimatedMediaCardChrome 实时响应栏状态变化。
  final ValueListenable<bool>? barsVisibleNotifier;

  /// 下拉关闭进度（0.0～1.0）。
  final double dismissProgress;

  @override
  State<ViewerPageShell> createState() => _ViewerPageShellState();
}

class _ViewerPageShellState extends State<ViewerPageShell> {
  _GestureMode _gestureMode = _GestureMode.pending;
  double _dismissRawOffset = 0;

  /// 已解析的手势缩放配置。
  bool _enableGestureScalingResolved = true;

  /// 卡片圆角半径；与 [_AnimatedMediaCardChrome] 动画同步，供 [MediaCardChromeScope] / [ViewerPageContext] 使用。
  ValueNotifier<double>? _mediaCardClipNotifier;

  /// _AnimatedMediaCardChrome 的 GlobalKey，防止 _buildLayout 重新执行时 State 被销毁重建，
  /// 确保 immersed 变化时 didUpdateWidget 能正确触发动画。
  final GlobalKey _mediaCardChromeKey = GlobalKey();

  // 便于壳层在需要时对缩放包装调用 reset（例如翻页复用）。
  final GlobalKey<_ZoomableMediaWrapperState> _zoomKey = GlobalKey();

  /// 缓存主媒体组件，避免在信息面板滑动动画中频繁调用 pageBuilder 导致状态丢失（如视频播放中断）。
  Widget? _cachedMedia;
  ViewerItem? _lastItem;
  dynamic _lastItemExtra;
  bool _lastBarsVisible = true;
  double _lastDismissProgress = 0.0;

  /// 用于保护媒体组件状态的 GlobalKey，确保在从 PhotoView 移出时不会被重置（针对视频等有力）。
  final GlobalKey _mediaGlobalKey = GlobalKey();

  /// 用于向子组件局部透传信息面板进度，不触发整树重建。
  late final ValueNotifier<double> _infoRevealProgressNotifier;

  // ── 缓存失效判定 ────────────────────────────────────────────────────────

  bool get _needsRebuildCache =>
      _cachedMedia == null ||
      _lastItem != widget.item ||
      _lastItemExtra != widget.item.extra ||
      _lastBarsVisible != widget.barsVisible ||
      (_lastDismissProgress - widget.dismissProgress).abs() >
          0.001; // ── 辅助 ───────────────────────────────────────────────────────────────

  InfoSheetController get _info => widget.infoController;

  ViewerInteractionConfig get _cfg => widget.config;

  bool get _hasInfo => widget.item.hasInfo && widget.infoBuilder != null;

  @override
  void initState() {
    super.initState();
    if (widget.screenHeight != null) {
      _info.setScreenHeight(widget.screenHeight!);
    }
    _infoRevealProgressNotifier = ValueNotifier<double>(_info.revealProgress);
    _info.addListener(_onInfoChange);

    if (_mediaCardChromeEnabled(widget.theme)) {
      final initialRadius = _mediaCardInitialClipRadius();
      _mediaCardClipNotifier = ValueNotifier<double>(initialRadius);
    }
    _resolveEnableGestureScaling();
  }

  void _resolveEnableGestureScaling() {
    final res = widget.item.enableGestureScaling;
    if (res is bool) {
      _enableGestureScalingResolved = res;
    } else {
      res.then((val) {
        if (mounted && _enableGestureScalingResolved != val) {
          setState(() => _enableGestureScalingResolved = val);
        }
      });
    }
  }

  void _onInfoChange() {
    if (_infoRevealProgressNotifier.value != _info.revealProgress) {
      _infoRevealProgressNotifier.value = _info.revealProgress;
    }
  }

  @override
  void dispose() {
    _info.removeListener(_onInfoChange);
    _infoRevealProgressNotifier.dispose();
    _mediaCardClipNotifier?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ViewerPageShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item != widget.item) {
      _resolveEnableGestureScaling();
    }
    final wasOn = _mediaCardChromeEnabled(oldWidget.theme);
    final on = _mediaCardChromeEnabled(widget.theme);

    if (!wasOn && on) {
      final initialRadius = _mediaCardInitialClipRadius();
      _mediaCardClipNotifier = ValueNotifier<double>(initialRadius);
    } else if (wasOn && !on) {
      _mediaCardClipNotifier?.dispose();
      _mediaCardClipNotifier = null;
    }
    // 圆角值完全由 _AnimatedMediaCardChrome 的动画控制，不在此直接设置 notifier.value
  }

  double _mediaCardInitialClipRadius() {
    final immersed = !widget.barsVisible || widget.pageController.isZoomed;
    final radius = immersed ? 0.0 : widget.theme.mediaCardBorderRadius;
    return radius;
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
      if (dy.abs() < _cfg.verticalDragMinStartDistance) return;

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
          child: _buildLayout(ctx, screenH),
        );
      },
    );
  }

  Widget _buildLayout(BuildContext ctx, double screenH) {
    // 注意：ListenableBuilder 不再包裹整个布局，
    // 我们手动在需要的地方通过 ListenableBuilder 或 ValueListenableBuilder 局部刷新。

    final revealProgress = _info.revealProgress;
    final sheetH = _info.sheetHeight;
    final contentH = (screenH - sheetH).clamp(0.0, screenH);
    final screenW = MediaQuery.of(ctx).size.width;

    final pageCtx = ViewerPageContext(
      index: widget.index,
      itemCount: widget.itemCount,
      item: widget.item,
      infoState: _info.state,
      infoRevealProgress: revealProgress,
      infoRevealProgressListenable: _infoRevealProgressNotifier,
      availableSize: Size(screenW, contentH),
      config: _cfg,
      pageController: widget.pageController,
      barsVisible: widget.barsVisible,
      barsVisibleListenable: widget.controller?.barsVisibleNotifier,
      dismissProgress: widget.dismissProgress,
      mediaCardClipRadiusListenable: _mediaCardClipNotifier,
      controller: widget.controller,
    );

    // ── 缓存策略 ──
    // 只有当项或 Builder 变化时才重新调用。滑动 revealProgress 时不重新生成 widget 实例。
    if (_needsRebuildCache) {
      _cachedMedia = KeyedSubtree(
        key: _mediaGlobalKey,
        child: widget.pageBuilder(ctx, pageCtx),
      );
      _lastItem = widget.item;
      _lastItemExtra = widget.item.extra;
      _lastBarsVisible = widget.barsVisible;
      _lastDismissProgress = widget.dismissProgress;
    }

    final pageOverlay = widget.pageOverlayBuilder?.call(ctx, pageCtx);
    final underMedia = widget.underMediaBuilder?.call(ctx, pageCtx);

    final zoomCore = _ZoomableMediaWrapper(
      key: _zoomKey,
      revealProgressListenable: _infoRevealProgressNotifier,
      enableZoom: _cfg.enableZoom && _enableGestureScalingResolved,
      enableDoubleTap:
          _cfg.enableDoubleTapZoom && _enableGestureScalingResolved,
      pageController: widget.pageController,
      theme: widget.theme,
      onSingleTap: _cfg.enableTapToToggleBars ? widget.onContentTap : null,
      child: _cachedMedia!,
    );

    final theme = widget.theme;
    Widget mediaZoom = zoomCore;
    if (_mediaCardChromeEnabled(theme)) {
      // 同时监听 pageController（isZoomed 变化）和 barsVisibleNotifier（栏显隐变化）
      // 两者都会影响 immersed 状态，从而触发圆角动画。
      // 优先使用框架内部的 barsVisibleNotifier（始终存在），
      // 其次使用外部 controller 的 notifier。
      final barsNotifier =
          widget.barsVisibleNotifier ?? widget.controller?.barsVisibleNotifier;
      final cardListenable = barsNotifier != null
          ? Listenable.merge([widget.pageController, barsNotifier])
          : widget.pageController;
      // 用局部变量捕获，避免闭包内字段晋升失败（Dart 不对私有字段在 lambda 内晋升）
      final notifier = _mediaCardClipNotifier!;
      mediaZoom = ListenableBuilder(
        listenable: cardListenable,
        builder: (context, _) {
          // 优先从 barsVisibleNotifier 读取最新值（notifier 触发时 widget.barsVisible 可能还未更新）
          final barsVisible = barsNotifier?.value ?? widget.barsVisible;
          final immersed = !barsVisible || widget.pageController.isZoomed;
          return _AnimatedMediaCardChrome(
            key: _mediaCardChromeKey,
            immersed: immersed,
            inset: theme.mediaCardInset,
            borderRadius: theme.mediaCardBorderRadius,
            duration: theme.mediaCardAnimationDuration,
            curve: theme.mediaCardAnimationCurve,
            clipRadiusNotifier: notifier,
            child: zoomCore,
          );
        },
      );
    }

    return InfoRevealScope(
      listenable: _infoRevealProgressNotifier,
      child: ListenableBuilder(
        listenable: _info,
        child: mediaZoom,
        builder: (ctx, stableMedia) {
          final revealProgress = _info.revealProgress;
          final sheetH = _info.sheetHeight;
          final contentH = (screenH - sheetH).clamp(0.0, screenH);

          // 重新构建一个局部的上下文，仅刷新非缓存的部分
          final animationCtx = pageCtx.copyWith(
            infoRevealProgress: revealProgress,
            availableSize: Size(screenW, contentH),
            infoState: _info.state,
          );

          return Stack(
            children: [
              if (widget.backgroundBuilder != null)
                Positioned.fill(
                  child: widget.backgroundBuilder!(ctx, animationCtx),
                ),

              if (underMedia != null)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: contentH,
                  child: underMedia,
                ),

              // 主内容视口：高度随信息面板上移变矮；内容顶对齐，底部由 ClipRect 裁切。
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: contentH,
                child: _MediaViewportWrapper(
                  revealProgress: revealProgress,
                  child: stableMedia!,
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
                  height: sheetH + 10,
                  child: Opacity(
                    opacity: 1,
                    child: _InfoSheetSurface(
                      theme: widget.theme,
                      infoController: _info,
                      child: widget.infoBuilder!(ctx, animationCtx),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
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
    super.key,
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
    return MediaCardChromeScope(
      clipRadiusListenable: widget.clipRadiusNotifier,
      child: AnimatedBuilder(
        animation: _curveAnim,
        builder: (context, child) {
          final v = _curveAnim.value;
          final pad = EdgeInsets.lerp(widget.inset, EdgeInsets.zero, v)!;
          return Padding(
            padding: pad,
            child: child!,
          );
        },
        child: widget.child,
      ),
    );
  }
}

// ── 主内容视口对齐插值 ───────────────────────────────────────────────────────

/// 主内容视口包装器；底部溢出裁掉，不盖住信息面板。
///
/// [RenderCoverFrame] 自身已通过 `_computeGeometry` 处理垂直对齐插值，
/// 此处只需固定顶对齐并裁切底部溢出，不再做动态 Align 偏移。
class _MediaViewportWrapper extends StatelessWidget {
  const _MediaViewportWrapper({
    required this.child,
    required this.revealProgress,
  });

  final Widget child;

  /// 0 = 信息隐藏，1 及以上 = 信息展开。（保留参数以兼容调用方，此处不再使用。）
  final double revealProgress;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Align(
        alignment: Alignment.topCenter,
        child: child,
      ),
    );
  }
}

// ── PhotoView 缩放包装 ───────────────────────────────────────────────────────

/// 用 [ZoomEngine] 包一层业务子组件：双指缩放、双击放大/还原、边界内平移。
///
/// 与 [MediaViewer] 外层的 [PhotoViewGestureDetectorScope] 配合，避免横滑翻页与双指缩放抢手势。
/// 缩放状态写入 [ViewerPageController]，供壳层关闭竖拖、禁止 PageView 滑动。
///
/// 默认使用 [PhotoViewZoomEngine]；可通过 [zoomEngineFactory] 注入自定义引擎（测试或未来替换用）。
class _ZoomableMediaWrapper extends StatefulWidget {
  const _ZoomableMediaWrapper({
    super.key,
    required this.child,
    required this.revealProgressListenable,
    required this.enableZoom,
    required this.enableDoubleTap,
    required this.pageController,
    required this.theme,
    this.onSingleTap,
    this.zoomEngineFactory,
  });

  final Widget child;
  final ValueListenable<double> revealProgressListenable;
  final bool enableZoom;
  final bool enableDoubleTap;
  final ViewerPageController pageController;
  final ViewerTheme theme;

  /// 确认「非双击」后的单击回调，用于切换顶底栏。
  final VoidCallback? onSingleTap;

  /// 可选：注入自定义 [ZoomEngine] 工厂（测试或未来替换引擎用）。
  /// 为 null 时默认使用 [PhotoViewZoomEngine]。
  final ZoomEngine Function(TickerProvider vsync)? zoomEngineFactory;

  @override
  State<_ZoomableMediaWrapper> createState() => _ZoomableMediaWrapperState();
}

class _ZoomableMediaWrapperState extends State<_ZoomableMediaWrapper>
    with SingleTickerProviderStateMixin {
  late final ZoomEngine _engine;

  @override
  void initState() {
    super.initState();

    // 7.2: 若外部注入了工厂则使用注入的引擎，否则创建默认的 PhotoViewZoomEngine
    if (widget.zoomEngineFactory != null) {
      _engine = widget.zoomEngineFactory!(this);
    } else {
      _engine = PhotoViewZoomEngine(
        vsync: this,
        theme: widget.theme,
        enableZoom: widget.enableZoom,
        enableDoubleTap: widget.enableDoubleTap,
      );
    }

    // 7.2: 连接引擎回调
    _engine.onSingleTap = widget.onSingleTap;
    _engine.onScaleChanged = (s) => widget.pageController.reportContentScale(s);

    // 7.2: 监听程序化缩放请求
    widget.pageController.addListener(_onPageCtrlForProgrammaticZoom);
  }

  @override
  void dispose() {
    widget.pageController.removeListener(_onPageCtrlForProgrammaticZoom);
    _engine.dispose();
    super.dispose();
  }

  // ── 程序化缩放 ─────────────────────────────────────────────────────────

  void _onPageCtrlForProgrammaticZoom() {
    final kind = widget.pageController.takeProgrammaticZoom();
    if (kind == null) return;

    // 只有在面板未展开且缩放已启用时才响应缩放请求
    final revealProgress = widget.revealProgressListenable.value;
    if (!widget.enableZoom || revealProgress >= 0.05) return;

    _engine.requestProgrammaticZoom(kind);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: widget.revealProgressListenable,
      builder: (context, revealProgress, _) {
        final bool enabled = widget.enableZoom && revealProgress < 0.01;

        // 引擎的 build 方法内部处理 enabled=false 时的缩放重置逻辑
        return _engine.build(context, child: widget.child, enabled: enabled);
      },
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
          return ClipRRect(
            borderRadius: theme.infoBorderRadius,
            child: Container(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              color: bg,
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
            ),
          );
        },
      ),
    );
  }
}
