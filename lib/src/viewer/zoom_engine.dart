import 'package:flutter/widgets.dart';

import '../core/viewer_state.dart' show ViewerProgrammaticZoomKind;

/// 缩放引擎抽象接口。
///
/// 当前由 [PhotoViewZoomEngine] 实现（基于 photo_view 包）。
/// 未来可替换为 yu_ni_photo_view_kit 实现，只需替换此接口的实现类。
abstract class ZoomEngine {
  /// 构建缩放引擎的 Widget 层。
  ///
  /// [child] 是要缩放的业务内容。
  /// [enabled] 控制是否响应手势（信息面板展开时为 false）。
  Widget build(
    BuildContext context, {
    required Widget child,
    required bool enabled,
  });

  /// 单击回调（确认非双击后触发）。
  /// 供框架层接收单击事件以切换顶底栏（需求 5.3）。
  VoidCallback? get onSingleTap;
  set onSingleTap(VoidCallback? value);

  /// 双击回调（双击确认后触发，早于缩放动画开始）。
  /// 供框架层或引擎实现处理双击放大/还原（需求 5.4）。
  VoidCallback? get onDoubleTap;
  set onDoubleTap(VoidCallback? value);

  /// 缩放状态变化回调（供框架更新 ViewerPageController，需求 5.2）。
  /// 参数为新的缩放倍率。
  ValueChanged<double>? get onScaleChanged;
  set onScaleChanged(ValueChanged<double>? value);

  /// 程序化缩放请求（由 ViewerPageController 触发，需求 5.8）。
  void requestProgrammaticZoom(ViewerProgrammaticZoomKind kind);

  /// 重置缩放至初始状态（scale=1, offset=zero）。
  /// 翻页时由框架调用（需求 5.1）。
  void reset();

  /// 释放资源。
  void dispose();
}
