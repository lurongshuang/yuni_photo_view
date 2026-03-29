import 'viewer_desktop.dart';

/// 左右翻页时，各页信息面板状态如何记忆。
enum InfoSyncMode {
  /// 每页独立记忆展开高度等（默认）。
  perPage,

  /// 多页共享同一套展开比例（需业务配合 [MediaViewerController] 等实现镜像行为）。
  mirrored,
}

/// 查看器交互相关的阻尼、阈值与开关。
///
/// 各字段均有合理默认值；传入自定义实例给 [MediaViewer] 即可微调手感。
class ViewerInteractionConfig {
  const ViewerInteractionConfig({
    this.infoDragUpDamping = 0.88,
    this.infoRestoreDownDamping = 0.85,
    this.viewerDismissDownDamping = 0.55,
    this.defaultShownExtent = 0.5,
    this.infoSyncMode = InfoSyncMode.perPage,
    this.infoShowDistanceThreshold = 80.0,
    this.infoHideDistanceThreshold = 60.0,
    this.infoShowVelocityThreshold = 500.0,
    this.infoHideVelocityThreshold = 400.0,
    this.dismissDistanceThreshold = 110.0,
    this.dismissVelocityThreshold = 600.0,
    this.barsFadeWithDismissProgress = true,
    this.enableHorizontalPaging = true,
    this.enableDismissGesture = true,
    this.enableInfoGesture = true,
    this.enableZoom = true,
    this.enableDoubleTapZoom = true,
    this.enableTapToToggleBars = true,
    this.enableSystemUiToggle = true,
    this.desktopUiMode = ViewerDesktopUiMode.auto,
    this.desktopAllowSwipePaging = false,
    this.desktopAllowDismissDrag = false,
    this.desktopAllowInfoDrag = false,
  });

  // ── 阻尼（0～1，越大越「拖不动」）────────────────────────────────────────

  /// 手指向上拖、拉高信息面板时的阻尼。
  final double infoDragUpDamping;

  /// 手指向下拖、压低/收起信息面板时的阻尼。
  final double infoRestoreDownDamping;

  /// 下拉关闭时，内容层跟手下移的阻尼（视觉上的跟手比例）。
  final double viewerDismissDownDamping;

  // ── 信息面板布局 ─────────────────────────────────────────────────────────

  /// 默认展开高度占屏幕高度比例（0.5 即半屏）。
  final double defaultShownExtent;

  /// 翻页时信息状态同步策略，见 [InfoSyncMode]。
  final InfoSyncMode infoSyncMode;

  // ── 松手判定阈值 ─────────────────────────────────────────────────────────

  /// 从隐藏态上拉：松手时超过该位移（px）则展开信息面板。
  final double infoShowDistanceThreshold;

  /// 从展开态下拉：相对起始高度下移超过该值（px）则倾向收起。
  final double infoHideDistanceThreshold;

  /// 向上快速甩动超过该速度（px/s）可无视距离直接展开。
  final double infoShowVelocityThreshold;

  /// 向下快速甩动超过该速度则倾向收起信息面板。
  final double infoHideVelocityThreshold;

  /// 下拉位移超过该值（px）松手后倾向关闭整个查看器。
  final double dismissDistanceThreshold;

  /// 向下速度超过该值（px/s）可无视距离直接关闭查看器。
  final double dismissVelocityThreshold;

  // ── 顶底栏与关闭联动 ─────────────────────────────────────────────────────

  /// 为 true 时，下拉关闭过程中顶栏、底栏透明度随关闭进度降低（栏本身不位移）。
  final bool barsFadeWithDismissProgress;

  // ── 手势总开关（部分会体现在 [ViewerPageContext] 供业务参考）────────────

  /// 是否允许 [PageView] 左右滑动翻页。
  final bool enableHorizontalPaging;

  /// 是否允许从内容区向下拖关闭查看器（未放大时）。
  final bool enableDismissGesture;

  /// 是否允许上滑呼出信息面板。
  final bool enableInfoGesture;

  /// 提示业务可启用双指缩放（框架内由 PhotoView 实现）。
  final bool enableZoom;

  /// 是否启用双击放大/还原。
  final bool enableDoubleTapZoom;

  /// 单击内容区是否切换顶栏、底栏显隐；点击信息面板区域不受影响。
  ///
  /// 与双击缩放共存时，单击判定会略延迟（约 300ms），与常见相册应用一致。
  final bool enableTapToToggleBars;

  /// 在 [enableTapToToggleBars] 为 true 时，是否同步隐藏系统状态栏与导航栏（沉浸式）。
  /// 查看器销毁时会恢复边缘到边模式。
  final bool enableSystemUiToggle;

  // ── 桌面 UI（[resolveUsesDesktopUi] 为 true 时生效）────────────────────────

  /// 是否显示桌面控件区，以及是否按桌面规则收紧手势（见 [resolveForShell]）。
  final ViewerDesktopUiMode desktopUiMode;

  /// 桌面模式下是否仍允许横向滑动翻页（默认 false，依赖按钮 / 快捷键）。
  final bool desktopAllowSwipePaging;

  /// 桌面模式下是否仍允许从内容区下拉关闭（默认 false，建议用顶栏关闭）。
  final bool desktopAllowDismissDrag;

  /// 桌面模式下是否仍允许上滑 / 拖动手势控制信息面板（默认 false，建议用信息按钮）。
  final bool desktopAllowInfoDrag;

  /// 是否启用桌面布局与控件区（由 [desktopUiMode] 与宿主平台决定）。
  bool get usesDesktopUi => resolveViewerDesktopUi(desktopUiMode);

  /// 传给 [ViewerPageShell] 等的有效配置：在桌面模式下收紧翻页 / 关闭 / 信息手势。
  ViewerInteractionConfig resolveForShell() {
    if (!usesDesktopUi) return this;
    return copyWith(
      enableHorizontalPaging: enableHorizontalPaging && desktopAllowSwipePaging,
      enableDismissGesture: enableDismissGesture && desktopAllowDismissDrag,
      enableInfoGesture: enableInfoGesture && desktopAllowInfoDrag,
    );
  }

  /// 复制并覆盖指定字段。
  ViewerInteractionConfig copyWith({
    double? infoDragUpDamping,
    double? infoRestoreDownDamping,
    double? viewerDismissDownDamping,
    double? defaultShownExtent,
    InfoSyncMode? infoSyncMode,
    double? infoShowDistanceThreshold,
    double? infoHideDistanceThreshold,
    double? infoShowVelocityThreshold,
    double? infoHideVelocityThreshold,
    double? dismissDistanceThreshold,
    double? dismissVelocityThreshold,
    bool? barsFadeWithDismissProgress,
    bool? enableHorizontalPaging,
    bool? enableDismissGesture,
    bool? enableInfoGesture,
    bool? enableZoom,
    bool? enableDoubleTapZoom,
    bool? enableTapToToggleBars,
    bool? enableSystemUiToggle,
    ViewerDesktopUiMode? desktopUiMode,
    bool? desktopAllowSwipePaging,
    bool? desktopAllowDismissDrag,
    bool? desktopAllowInfoDrag,
  }) {
    return ViewerInteractionConfig(
      infoDragUpDamping: infoDragUpDamping ?? this.infoDragUpDamping,
      infoRestoreDownDamping:
          infoRestoreDownDamping ?? this.infoRestoreDownDamping,
      viewerDismissDownDamping:
          viewerDismissDownDamping ?? this.viewerDismissDownDamping,
      defaultShownExtent: defaultShownExtent ?? this.defaultShownExtent,
      infoSyncMode: infoSyncMode ?? this.infoSyncMode,
      infoShowDistanceThreshold:
          infoShowDistanceThreshold ?? this.infoShowDistanceThreshold,
      infoHideDistanceThreshold:
          infoHideDistanceThreshold ?? this.infoHideDistanceThreshold,
      infoShowVelocityThreshold:
          infoShowVelocityThreshold ?? this.infoShowVelocityThreshold,
      infoHideVelocityThreshold:
          infoHideVelocityThreshold ?? this.infoHideVelocityThreshold,
      dismissDistanceThreshold:
          dismissDistanceThreshold ?? this.dismissDistanceThreshold,
      dismissVelocityThreshold:
          dismissVelocityThreshold ?? this.dismissVelocityThreshold,
      barsFadeWithDismissProgress:
          barsFadeWithDismissProgress ?? this.barsFadeWithDismissProgress,
      enableHorizontalPaging:
          enableHorizontalPaging ?? this.enableHorizontalPaging,
      enableDismissGesture: enableDismissGesture ?? this.enableDismissGesture,
      enableInfoGesture: enableInfoGesture ?? this.enableInfoGesture,
      enableZoom: enableZoom ?? this.enableZoom,
      enableDoubleTapZoom: enableDoubleTapZoom ?? this.enableDoubleTapZoom,
      enableTapToToggleBars:
          enableTapToToggleBars ?? this.enableTapToToggleBars,
      enableSystemUiToggle: enableSystemUiToggle ?? this.enableSystemUiToggle,
      desktopUiMode: desktopUiMode ?? this.desktopUiMode,
      desktopAllowSwipePaging:
          desktopAllowSwipePaging ?? this.desktopAllowSwipePaging,
      desktopAllowDismissDrag:
          desktopAllowDismissDrag ?? this.desktopAllowDismissDrag,
      desktopAllowInfoDrag: desktopAllowInfoDrag ?? this.desktopAllowInfoDrag,
    );
  }
}
