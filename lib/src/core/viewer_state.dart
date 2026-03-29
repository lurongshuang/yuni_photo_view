import 'package:flutter/widgets.dart';

import 'interaction_config.dart';
import 'viewer_item.dart';

// ── Enums ────────────────────────────────────────────────────────────────────

/// Two-state info panel visibility.
enum InfoState {
  /// Info panel is not visible; gesture is available to reveal it.
  hidden,

  /// Info panel is visible at the default (or expanded) extent.
  shown,
}

// ── Page context ─────────────────────────────────────────────────────────────

/// Context passed to [ViewerPageBuilder] for each page.
///
/// The business page builder receives this on every relevant state change so
/// it can adjust its rendering (e.g., scale for cover behaviour) without the
/// framework knowing what the content is.
class ViewerPageContext {
  const ViewerPageContext({
    required this.index,
    required this.item,
    required this.infoState,
    required this.infoRevealProgress,
    required this.availableSize,
    required this.config,
    required this.pageController,
  });

  /// Position of this page in the item list.
  final int index;

  /// The data item for this page.
  final ViewerItem item;

  /// Current info panel visibility state.
  final InfoState infoState;

  /// Continuous progress from 0.0 (info hidden) to 1.0 (info at default
  /// half-screen extent). Goes beyond 1.0 when sheet is further expanded.
  final double infoRevealProgress;

  /// Current size available to the business content widget.
  /// Shrinks vertically as the info sheet rises.
  final Size availableSize;

  /// Active interaction configuration.
  final ViewerInteractionConfig config;

  /// Per-page controller the business can use to report content zoom state.
  final ViewerPageController pageController;
}

// ── Bar context ───────────────────────────────────────────────────────────────

/// Context passed to [ViewerBarBuilder] and [ViewerOverlayBuilder].
///
/// All fields update in real-time during user gestures so that custom widgets
/// can animate smoothly without any additional state management.
class ViewerBarContext {
  const ViewerBarContext({
    required this.index,
    required this.item,
    required this.infoState,
    required this.dismissProgress,
    required this.config,
    required this.barsVisible,
    required this.infoRevealProgress,
  });

  final int index;
  final ViewerItem item;
  final InfoState infoState;

  /// How far a dismiss drag has progressed (0.0 = none, 1.0 = trigger point).
  final double dismissProgress;

  final ViewerInteractionConfig config;

  /// Whether the top/bottom overlay bars are currently visible.
  ///
  /// Toggles when the user single-taps the content area
  /// (when [ViewerInteractionConfig.enableTapToToggleBars] is true).
  ///
  /// **Top/bottom bar builders** receive this, but note that the framework
  /// already wraps them in [AnimatedOpacity] — so this field is most useful
  /// for changing *content* (icon, label) rather than managing visibility
  /// yourself.
  ///
  /// **[ViewerOverlayBuilder]** is NOT wrapped by the framework, so this is
  /// the primary way for overlays to show/hide elements in fullscreen mode
  /// (e.g. a "tap to restore bars" hint).
  final bool barsVisible;

  /// Continuous progress of the info sheet reveal.
  ///
  /// - `0.0` — info sheet fully hidden.
  /// - `1.0` — info sheet at the default extent
  ///   ([ViewerInteractionConfig.defaultShownExtent]).
  /// - `> 1.0` — info sheet expanded beyond the default extent.
  ///
  /// Updates on every animation frame while the user drags or while the
  /// sheet animates.  Use this to cross-fade or translate overlays as the
  /// sheet rises — for example, fading out a bottom filmstrip so it does not
  /// overlap the info content.
  final double infoRevealProgress;
}

// ── Per-page controller ───────────────────────────────────────────────────────

/// Allows the business content widget to report its interaction state back to
/// the viewer framework so that gesture priority can be decided correctly.
///
/// The framework disables the dismiss gesture and PageView paging when
/// [isZoomed] is true, and lets [InteractiveViewer] win the gesture arena.
class ViewerPageController extends ChangeNotifier {
  double _contentScale = 1.0;
  Offset _contentOffset = Offset.zero;

  /// Whether the business content is currently zoomed in.
  bool get isZoomed => _contentScale > 1.02;

  /// Current scale factor of the business content.
  double get contentScale => _contentScale;

  /// Current pan offset of the business content.
  Offset get contentOffset => _contentOffset;

  /// Call this from your page widget whenever pinch scale changes.
  /// Notifies listeners only when [isZoomed] crosses the boundary so that
  /// the framework can update gesture routing and PageView physics.
  void reportContentScale(double scale) {
    final wasZoomed = isZoomed;
    _contentScale = scale;
    if (wasZoomed != isZoomed) notifyListeners();
  }

  /// Call this from your page widget whenever pan offset changes.
  void reportContentOffset(Offset offset) {
    _contentOffset = offset;
  }

  /// Convenience reset (e.g., on page change).
  void reset() {
    final wasZoomed = isZoomed;
    _contentScale = 1.0;
    _contentOffset = Offset.zero;
    if (wasZoomed) notifyListeners();
  }
}

// ── Builder typedefs ──────────────────────────────────────────────────────────

/// Builds the main content area for a viewer page.
/// Return any widget — image, video, custom view, etc.
typedef ViewerPageBuilder = Widget Function(
  BuildContext context,
  ViewerPageContext pageCtx,
);

/// Builds the info panel content for a viewer page.
/// Return null to disable the info panel for this page.
typedef ViewerInfoBuilder = Widget Function(
  BuildContext context,
  ViewerPageContext pageCtx,
);

/// Builds the top or bottom bar overlay.
typedef ViewerBarBuilder = Widget Function(
  BuildContext context,
  ViewerBarContext barCtx,
);

/// Builds an arbitrary overlay on top of the viewer.
typedef ViewerOverlayBuilder = Widget Function(
  BuildContext context,
  ViewerBarContext barCtx,
);
