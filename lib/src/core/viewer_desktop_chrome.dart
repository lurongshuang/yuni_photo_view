import 'package:flutter/widgets.dart';

import 'interaction_config.dart';
import 'viewer_controller.dart';
import 'viewer_item.dart';
import 'viewer_state.dart';
import 'viewer_theme.dart';

/// 构建桌面控件区（翻页、缩放、信息等）时传入的上下文与回调。
///
/// **自定义方式**
/// - 传入 [MediaViewer.desktopChromeBuilder]，在回调里用本上下文中的方法自行拼 UI（任意布局、
///   任意按钮样式）；不必使用默认组件。
/// - 为 `null` 时使用 [DefaultViewerDesktopChrome]（顶部工具条：返回、翻页、信息、缩放）。
class ViewerDesktopChromeContext {
  const ViewerDesktopChromeContext({
    required this.itemCount,
    required this.currentIndex,
    required this.currentItem,
    required this.closeViewer,
    required this.goToPrevious,
    required this.goToNext,
    required this.canGoToPrevious,
    required this.canGoToNext,
    required this.toggleInfo,
    required this.infoState,
    required this.hasInfoPanel,
    required this.zoomIn,
    required this.zoomOut,
    required this.contentScale,
    required this.canZoomIn,
    required this.canZoomOut,
    required this.controller,
    required this.config,
    required this.theme,
    required this.barsVisible,
    required this.isZoomed,
    required this.dismissProgress,
    required this.items,
  });

  /// 完整的媒体列表。
  final List<ViewerItem> items;

  /// 媒体条数。
  final int itemCount;

  /// 当前页下标。
  final int currentIndex;

  /// 当前页数据。
  final ViewerItem currentItem;

  /// 关闭查看器（会先调用 [MediaViewer.onDismiss]，再 [Navigator.pop]）。
  ///
  /// 自定义顶栏时可用任意 Widget 绑定到此回调；也可不调用，自行处理路由。
  final VoidCallback closeViewer;

  /// 上一页（带动画）。
  final VoidCallback goToPrevious;

  /// 下一页（带动画）。
  final VoidCallback goToNext;

  final bool canGoToPrevious;
  final bool canGoToNext;

  /// 展开 / 收起当前页信息面板。
  final VoidCallback toggleInfo;

  final InfoState infoState;

  /// 当前页是否配置了信息区（含 [ViewerItem.hasInfo] 与 [MediaViewer.infoBuilder]）。
  final bool hasInfoPanel;

  /// 当前页内容程序化放大一步。
  final VoidCallback zoomIn;

  /// 当前页内容程序化缩小一步。
  final VoidCallback zoomOut;

  /// 当前页 [ViewerPageController.contentScale]。
  final double contentScale;

  final bool canZoomIn;
  final bool canZoomOut;

  /// 外部控制器（翻页、信息等指令与监听）。
  final MediaViewerController? controller;

  final ViewerInteractionConfig config;
  final ViewerTheme theme;

  /// 顶底栏是否显示（与触屏模式一致，便于桌面顶栏与控件区联动）。
  final bool barsVisible;

  final bool isZoomed;

  /// 下拉关闭进度（桌面默认关闭下拉时通常为 0）。
  final double dismissProgress;
}

/// 自定义桌面控件区；返回的 Widget 应叠在内容之上（如 [Stack] 内）。
typedef ViewerDesktopChromeBuilder = Widget Function(
  BuildContext context,
  ViewerDesktopChromeContext desktopCtx,
);
