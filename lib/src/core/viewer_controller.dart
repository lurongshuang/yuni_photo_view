import 'package:flutter/foundation.dart';

import 'viewer_state.dart';
import 'viewer_item.dart';

/// [MediaViewer] 的外部控制器。
///
/// 使用 [MediaViewer.controller] 传入或由框架持有；内部状态由框架更新，
/// 业务侧主要调用指令方法或 [addListener] 监听。
class MediaViewerController extends ChangeNotifier {
  int _currentIndex = 0;
  InfoState _currentInfoState = InfoState.hidden;
  double _dismissProgress = 0.0;
  bool _barsVisible = true;

  // 由 MediaViewer 在挂载时注入，勿在外部赋值。
  VoidCallback? _jumpToPageCallback;
  VoidCallback? _showInfoCallback;
  VoidCallback? _hideInfoCallback;
  ValueChanged<bool>? _setBarsVisibleCallback;
  VoidCallback? _zoomInCallback;
  VoidCallback? _zoomOutCallback;
  VoidCallback? _zoomResetCallback;
  void Function(List<ViewerItem>)? _appendItemsCallback;
  int _pendingJumpIndex = 0;

  // ── 只读状态 ─────────────────────────────────────────────────────────────

  /// 当前可见页下标。
  int get currentIndex => _currentIndex;

  /// 当前页信息面板的枚举状态。
  InfoState get currentInfoState => _currentInfoState;

  /// 下拉关闭手势进度（0.0～1.0），可与外部 UI 联动淡出。
  double get dismissProgress => _dismissProgress;

  /// 顶栏、底栏是否处于显示状态。
  bool get barsVisible => _barsVisible;

  // ── 内部更新（框架调用）──────────────────────────────────────────────────

  /// @nodoc
  void updateIndex(int index) {
    if (_currentIndex == index) return;
    _currentIndex = index;
    notifyListeners();
  }

  /// @nodoc
  void updateInfoState(InfoState state) {
    if (_currentInfoState == state) return;
    _currentInfoState = state;
    notifyListeners();
  }

  /// @nodoc
  void updateDismissProgress(double progress) {
    if ((_dismissProgress - progress).abs() < 0.001) return;
    _dismissProgress = progress;
    notifyListeners();
  }

  /// @nodoc
  void updateBarsVisible(bool visible) {
    if (_barsVisible == visible) return;
    _barsVisible = visible;
    notifyListeners();
  }

  /// @nodoc
  void attachCallbacks({
    required VoidCallback jumpToPage,
    required VoidCallback showInfo,
    required VoidCallback hideInfo,
    required ValueChanged<bool> setBarsVisible,
    VoidCallback? zoomContentIn,
    VoidCallback? zoomContentOut,
    VoidCallback? resetContentZoom,
    void Function(List<ViewerItem>)? appendItems,
  }) {
    _jumpToPageCallback = jumpToPage;
    _showInfoCallback = showInfo;
    _hideInfoCallback = hideInfo;
    _setBarsVisibleCallback = setBarsVisible;
    _zoomInCallback = zoomContentIn;
    _zoomOutCallback = zoomContentOut;
    _zoomResetCallback = resetContentZoom;
    _appendItemsCallback = appendItems;
  }

  // ── 对外指令 ───────────────────────────────────────────────────────────────

  /// 带动画翻到指定 [index]。
  void jumpToPage(int index) {
    _pendingJumpIndex = index;
    _jumpToPageCallback?.call();
  }

  /// 展开当前页信息面板。
  void showInfo() => _showInfoCallback?.call();

  /// 收起当前页信息面板。
  void hideInfo() => _hideInfoCallback?.call();

  /// 切换信息面板展开/收起。
  void toggleInfo() {
    if (_currentInfoState == InfoState.shown) {
      hideInfo();
    } else {
      showInfo();
    }
  }

  /// 显示顶栏、底栏。
  void showBars() => _setBarsVisibleCallback?.call(true);

  /// 隐藏顶栏、底栏。
  void hideBars() => _setBarsVisibleCallback?.call(false);

  /// 设置顶栏、底栏显隐。
  void setBarsVisible(bool visible) => _setBarsVisibleCallback?.call(visible);

  /// 当前页内容程序化放大一步（桌面工具栏 / 快捷键）。
  void zoomContentIn() => _zoomInCallback?.call();

  /// 当前页内容程序化缩小一步。
  void zoomContentOut() => _zoomOutCallback?.call();

  /// 当前页内容还原为 1×。
  void resetContentZoom() => _zoomResetCallback?.call();

  /// 向查看器末尾追加新的媒体项目（异步分页场景使用）。
  void appendItems(List<ViewerItem> newItems) {
    _appendItemsCallback?.call(newItems);
  }

  /// @nodoc
  int get pendingJumpIndex => _pendingJumpIndex;
}
