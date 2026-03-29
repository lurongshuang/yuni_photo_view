import 'package:flutter/foundation.dart';

/// 是否使用桌面式控件区（翻页按钮、缩放按钮、信息按钮等），与触屏手势解耦。
enum ViewerDesktopUiMode {
  /// 在 Windows / macOS / Linux 原生宿主上启用；Web 与移动端不启用。
  auto,

  /// 始终使用手机式交互（不显示桌面控件区，手势规则仅由 [ViewerInteractionConfig] 决定）。
  never,

  /// 强制桌面控件区；用于 Web 大屏、或外接键鼠的平板等场景。
  force,
}

/// 当前 Flutter 宿主是否为桌面类原生平台（不含 Web）。
bool isFlutterDesktopHost() {
  if (kIsWeb) return false;
  return switch (defaultTargetPlatform) {
    TargetPlatform.windows ||
    TargetPlatform.macOS ||
    TargetPlatform.linux =>
      true,
    _ => false,
  };
}

/// 由 [ViewerInteractionConfig.desktopUiMode] 解析是否启用桌面 UI。
bool resolveViewerDesktopUi(ViewerDesktopUiMode mode) {
  return switch (mode) {
    ViewerDesktopUiMode.auto => isFlutterDesktopHost(),
    ViewerDesktopUiMode.force => true,
    ViewerDesktopUiMode.never => false,
  };
}
