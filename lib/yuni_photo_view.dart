/// YuniPhotoView — A Flutter viewer interaction framework.
///
/// This package provides the interaction shell for full-screen media viewing:
/// paging, gestures, a slide-up info panel, and customisable overlays.
///
/// **The framework does NOT render any media content.**
/// Images, videos, files, and any other content are supplied by the business
/// application via [pageBuilder] and [infoBuilder] callbacks.
///
/// ## Quick start
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

// ── Core data model ───────────────────────────────────────────────────────────
export 'src/core/viewer_item.dart' show ViewerItem;

// ── Interaction configuration ─────────────────────────────────────────────────
export 'src/core/interaction_config.dart'
    show ViewerInteractionConfig, InfoSyncMode;

// ── State & builder types ─────────────────────────────────────────────────────
export 'src/core/viewer_state.dart'
    show
        InfoState,
        ViewerPageContext,
        ViewerBarContext,
        ViewerPageController,
        ViewerPageBuilder,
        ViewerInfoBuilder,
        ViewerBarBuilder,
        ViewerOverlayBuilder;

// ── External controller ───────────────────────────────────────────────────────
export 'src/core/viewer_controller.dart' show MediaViewerController;

// ── Theme ─────────────────────────────────────────────────────────────────────
export 'src/core/viewer_theme.dart' show ViewerTheme;

// ── Main widget ───────────────────────────────────────────────────────────────
export 'src/viewer/media_viewer.dart' show MediaViewer;

// ── Helper widgets ────────────────────────────────────────────────────────────
/// Recommended frame for image / video content in [pageBuilder].
/// Applies cover-scale-up for short content and top-align-clip for tall content,
/// with a smooth centre→top alignment transition driven by [infoRevealProgress].
export 'src/widgets/viewer_media_cover_frame.dart' show ViewerMediaCoverFrame;

/// Drop-in replacement for [Hero] inside [pageBuilder].
/// Provides a smooth default flight-shuttle (BoxFit.cover + animated corner
/// radius) and exposes [shuttleBuilder] for full customisation.
export 'src/widgets/viewer_hero.dart' show ViewerHero;
