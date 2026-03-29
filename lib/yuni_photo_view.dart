/// YuniPhotoView：Flutter 全屏媒体查看交互框架。
///
/// 提供分页、手势、上滑信息面板与可自定义浮层等**壳层能力**。
///
/// **框架不渲染具体媒体内容**：图片、视频等由业务在 [ViewerPageBuilder]、
/// [ViewerInfoBuilder] 等回调中自行构建。
///
/// ## 快速开始
///
/// ```dart
/// import 'package:yuni_photo_view/yuni_photo_view.dart';
///
/// MediaViewer.open(
///   context,
///   items: [
///     ViewerItem(id: '1', payload: 'https://example.com/photo.jpg'),
///     ViewerItem(id: '2', payload: 'https://example.com/photo2.jpg'),
///   ],
///   pageBuilder: (context, pageCtx) {
///     return Image.network(
///       pageCtx.item.payload as String,
///       fit: BoxFit.cover,
///       alignment: Alignment.topCenter,
///     );
///   },
///   infoBuilder: (context, pageCtx) {
///     return MyInfoWidget(item: pageCtx.item);
///   },
///   topBarBuilder: (context, barCtx) {
///     return MyTopBar(onBack: () => Navigator.pop(context));
///   },
/// );
/// ```
library yuni_photo_view;

// ── 核心数据模型 ─────────────────────────────────────────────────────────────
export 'src/core/viewer_item.dart' show ViewerItem;

// ── 交互配置 ─────────────────────────────────────────────────────────────────
export 'src/core/interaction_config.dart'
    show ViewerInteractionConfig, InfoSyncMode;

// ── 状态与 Builder 类型 ───────────────────────────────────────────────────────
export 'src/core/viewer_state.dart'
    show
        InfoState,
        ViewerPageContext,
        ViewerBarContext,
        ViewerPageController,
        ViewerPageBuilder,
        ViewerInfoBuilder,
        ViewerBarBuilder,
        ViewerOverlayBuilder,
        ViewerPageOverlayBuilder;

// ── 外部控制器 ───────────────────────────────────────────────────────────────
export 'src/core/viewer_controller.dart' show MediaViewerController;

// ── 主题 ─────────────────────────────────────────────────────────────────────
export 'src/core/viewer_theme.dart' show ViewerTheme;

// ── 主组件 ───────────────────────────────────────────────────────────────────
export 'src/viewer/media_viewer.dart' show MediaViewer;

// ── 辅助组件 ─────────────────────────────────────────────────────────────────
/// 建议在 [ViewerPageBuilder] 中包裹图片/视频：矮内容放大铺满，高内容顶对齐裁剪，
/// 并由 [ViewerPageContext.infoRevealProgress] 驱动居中→贴顶的平滑过渡。
export 'src/widgets/viewer_media_cover_frame.dart' show ViewerMediaCoverFrame;

/// 在 [pageBuilder] 中可替代原生 [Hero]：默认 flight shuttle 在缩略图 cover 与
/// 查看区 contain 之间插值，并可通过 [ViewerHero.shuttleBuilder] 完全自定义。
export 'src/widgets/viewer_hero.dart' show ViewerHero;
