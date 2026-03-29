/// Controls whether the info state is mirrored across pages or per-page.
enum InfoSyncMode {
  /// Each page remembers its own info expand ratio and scroll offset.
  /// Default.
  perPage,

  /// All pages share the same shown/hidden state and expand ratio.
  mirrored,
}

/// All physics & threshold parameters that govern the viewer's interactions.
///
/// Every parameter has a sensible default. Pass a customised instance to
/// [MediaViewer] to fine-tune feel.
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
  });

  // ── Damping ────────────────────────────────────────────────────────────────

  /// Resistance when dragging the info sheet upward (0..1).
  /// Higher values = more resistance.
  final double infoDragUpDamping;

  /// Resistance when dragging the info sheet downward to restore (0..1).
  final double infoRestoreDownDamping;

  /// Resistance applied to the content layer during downward dismiss drag (0..1).
  final double viewerDismissDownDamping;

  // ── Info layout ────────────────────────────────────────────────────────────

  /// Fraction of screen height used as the default info sheet height (0..1).
  /// 0.5 = half screen.
  final double defaultShownExtent;

  /// How info state is synchronised when the user pages left/right.
  final InfoSyncMode infoSyncMode;

  // ── Settle thresholds ──────────────────────────────────────────────────────

  /// Minimum drag distance (px) to trigger info show on release.
  final double infoShowDistanceThreshold;

  /// Minimum drag distance (px) to trigger info hide on release.
  final double infoHideDistanceThreshold;

  /// Minimum upward fling velocity (px/s) to show info regardless of distance.
  final double infoShowVelocityThreshold;

  /// Minimum downward fling velocity (px/s) to hide info regardless of distance.
  final double infoHideVelocityThreshold;

  /// Minimum downward drag distance (px) to trigger dismiss on release.
  final double dismissDistanceThreshold;

  /// Minimum downward fling velocity (px/s) to trigger dismiss regardless of distance.
  final double dismissVelocityThreshold;

  // ── Overlay behaviour ──────────────────────────────────────────────────────

  /// When [true], the top/bottom bars fade out as dismiss progress increases.
  /// The bars NEVER translate — only opacity changes.
  final bool barsFadeWithDismissProgress;

  // ── Gesture capability flags ───────────────────────────────────────────────
  // These are communicated to the business via [ViewerPageContext] so that
  // content renderers can adapt (e.g., disable zoom when framework owns the gesture).

  /// Allow left/right paging via [PageView].
  final bool enableHorizontalPaging;

  /// Allow downward swipe to close the viewer.
  final bool enableDismissGesture;

  /// Allow upward swipe to reveal the info sheet.
  final bool enableInfoGesture;

  /// Hint to the business page builder that pinch-to-zoom is appropriate.
  final bool enableZoom;

  /// Hint to the business page builder that double-tap-to-zoom is appropriate.
  final bool enableDoubleTapZoom;

  /// When [true], a single tap on the content area toggles the top/bottom bar
  /// visibility (fade in / fade out).  Taps on the info sheet are not affected.
  ///
  /// Because the double-tap-zoom recogniser also lives in the same area, the
  /// toggle fires ~300 ms after a single tap — this is standard behaviour in
  /// all major photo-viewer apps (iOS Photos, Google Photos, etc.).
  final bool enableTapToToggleBars;

  /// When [true] and [enableTapToToggleBars] is also [true], the system status
  /// bar and navigation bar are hidden together with the app bars (immersive
  /// mode).  The system UI is restored when the viewer is dismissed.
  final bool enableSystemUiToggle;

  /// Returns a copy with the given fields replaced.
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
    );
  }
}
