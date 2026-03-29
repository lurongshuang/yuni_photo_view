import 'package:flutter/widgets.dart';

import 'interaction_config.dart';
import 'viewer_item.dart';

// ── 枚举 ────────────────────────────────────────────────────────────────────

/// 信息面板是否展开（二态）。
enum InfoState {
  /// 未展开，仍可上滑呼出。
  hidden,

  /// 已展开至默认高度或可继续拉高。
  shown,
}

// ── 单页上下文（pageBuilder / infoBuilder / pageOverlayBuilder）──────────────

/// 传给 [ViewerPageBuilder] 等回调的上下文。
///
/// 相关状态变化时会重新构建，业务可据此调整缩放、对齐等，而无需框架知晓具体内容类型。
class ViewerPageContext {
  const ViewerPageContext({
    required this.index,
    required this.item,
    required this.infoState,
    required this.infoRevealProgress,
    required this.availableSize,
    required this.config,
    required this.pageController,
    required this.barsVisible,
    required this.dismissProgress,
  });

  /// 当前页在列表中的下标。
  final int index;

  /// 当前页的 [ViewerItem]。
  final ViewerItem item;

  /// 信息面板枚举状态。
  final InfoState infoState;

  /// 连续进度：0.0 完全隐藏 → 1.0 默认半屏高度；大于 1 表示用户继续上拉放大面板。
  final double infoRevealProgress;

  /// 业务主内容区可用尺寸（随信息面板上移而纵向变矮）。
  final Size availableSize;

  /// 当前交互配置。
  final ViewerInteractionConfig config;

  /// 单页控制器，用于向框架上报缩放（如 PhotoView 的 scale）。
  final ViewerPageController pageController;

  /// 全局顶栏、底栏是否显示（与单击内容区切换栏一致）。
  ///
  /// 可用于角标、Live 标记等与栏显隐同步。
  final bool barsVisible;

  /// 下拉关闭拖拽进度：0 无拖拽，1 达到关闭阈值。
  ///
  /// 可与页内浮层一起做淡出、位移动画。
  final double dismissProgress;
}

// ── 顶栏 / 底栏 / overlay 上下文 ─────────────────────────────────────────────

/// 传给 [ViewerBarBuilder]、[ViewerOverlayBuilder] 的上下文。
///
/// 手势过程中字段会持续更新，便于自定义控件跟手动画而无需自建 [Listenable]。
class ViewerBarContext {
  const ViewerBarContext({
    required this.index,
    required this.item,
    required this.infoState,
    required this.dismissProgress,
    required this.config,
    required this.barsVisible,
    required this.infoRevealProgress,
    required this.isZoomed,
    this.usesDesktopUi = false,
  });

  final int index;
  final ViewerItem item;
  final InfoState infoState;

  /// 与 [ViewerInteractionConfig.usesDesktopUi] 一致，便于顶栏/底栏与桌面控件区配合。
  final bool usesDesktopUi;

  /// 下拉关闭进度（0.0～1.0）。
  final double dismissProgress;

  final ViewerInteractionConfig config;

  /// 顶栏、底栏是否可见（单击内容切换，需 [ViewerInteractionConfig.enableTapToToggleBars]）。
  ///
  /// 顶栏、底栏本身已被框架包在 [AnimatedOpacity] 中，该字段更适合改**内容**（图标、文案）。
  /// [ViewerOverlayBuilder] 不受该动画包裹，全屏提示等应主要用此字段控制显隐。
  final bool barsVisible;

  /// 信息面板上拉连续进度（0 隐藏，1 默认高度，可大于 1）。
  ///
  /// 可用于底栏胶片条随上拉淡出、与面板避让等。
  final double infoRevealProgress;

  /// 当前页内容是否处于放大状态（scale 明显高于 1）。
  ///
  /// 可用来在放大时隐藏分享按钮等，避免遮挡画面。
  final bool isZoomed;
}

// ── 程序化缩放（桌面按钮 / 快捷键）──────────────────────────────────────────

/// 由 [ViewerPageController.requestProgrammaticZoom] 触发，由壳内缩放层消费。
enum ViewerProgrammaticZoomKind {
  zoomIn,
  zoomOut,
  reset,
}

// ── 单页缩放上报 ─────────────────────────────────────────────────────────────

/// 由业务内容（如 PhotoView）向框架上报缩放与平移，用于手势路由（关闭拖拽、左右翻页）。
///
/// 当 [isZoomed] 为 true 时，框架会关闭下拉关闭手势并禁止 [PageView] 横向滑动。
class ViewerPageController extends ChangeNotifier {
  double _contentScale = 1.0;
  Offset _contentOffset = Offset.zero;

  ViewerProgrammaticZoomKind? _pendingProgrammaticZoom;

  /// 是否视为已放大（内部阈值约 1.02）。
  bool get isZoomed => _contentScale > 1.02;

  /// 当前缩放倍数。
  double get contentScale => _contentScale;

  /// 当前平移偏移。
  Offset get contentOffset => _contentOffset;

  /// 双指缩放变化时调用；仅在是否跨过「已放大」边界时 [notifyListeners]。
  void reportContentScale(double scale) {
    final wasZoomed = isZoomed;
    _contentScale = scale;
    if (wasZoomed != isZoomed) notifyListeners();
  }

  /// 平移变化时调用。
  void reportContentOffset(Offset offset) {
    _contentOffset = offset;
  }

  /// 重置为 1× 且无偏移（例如翻页时）。
  void reset() {
    final wasZoomed = isZoomed;
    _contentScale = 1.0;
    _contentOffset = Offset.zero;
    if (wasZoomed) notifyListeners();
  }

  /// 桌面工具栏等：请求当前页内容放大 / 缩小 / 还原（由壳内 PhotoView 层监听并执行）。
  void requestProgrammaticZoom(ViewerProgrammaticZoomKind kind) {
    _pendingProgrammaticZoom = kind;
    notifyListeners();
  }

  /// @nodoc
  ViewerProgrammaticZoomKind? takeProgrammaticZoom() {
    final k = _pendingProgrammaticZoom;
    _pendingProgrammaticZoom = null;
    return k;
  }
}

// ── Builder 类型别名 ─────────────────────────────────────────────────────────

/// 构建每一页主内容区。
typedef ViewerPageBuilder = Widget Function(
  BuildContext context,
  ViewerPageContext pageCtx,
);

/// 构建每一页信息面板内部；若整页不需要可在外层不传 [MediaViewer.infoBuilder]。
typedef ViewerInfoBuilder = Widget Function(
  BuildContext context,
  ViewerPageContext pageCtx,
);

/// 构建顶部或底部固定栏。
typedef ViewerBarBuilder = Widget Function(
  BuildContext context,
  ViewerBarContext barCtx,
);

/// 构建叠在最上层的自定义浮层。
typedef ViewerOverlayBuilder = Widget Function(
  BuildContext context,
  ViewerBarContext barCtx,
);

/// 构建单页内、随页滑动但不参与缩放的叠加层（在内容之上、全局顶底栏之下）。
///
/// 典型用途：Live 角标、播放指示、「原图」进度等。某页不需要时返回 `null`。
typedef ViewerPageOverlayBuilder = Widget? Function(
  BuildContext context,
  ViewerPageContext pageCtx,
);
