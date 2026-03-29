import 'package:flutter/material.dart';

/// Visual tokens and animation parameters for the viewer.
///
/// Pass a customised [ViewerTheme] to [MediaViewer] to override defaults.
class ViewerTheme {
  const ViewerTheme({
    this.backgroundColor = Colors.black,
    this.infoBackgroundColor,
    this.infoBorderRadius = const BorderRadius.vertical(
      top: Radius.circular(14),
    ),
    this.dragHandleColor,
    this.dragHandleSize = const Size(36, 4),
    this.infoShowDuration = const Duration(milliseconds: 320),
    this.infoHideDuration = const Duration(milliseconds: 260),
    this.dismissSnapBackDuration = const Duration(milliseconds: 300),
    this.infoShowCurve = Curves.easeOutCubic,
    this.infoHideCurve = Curves.easeInOutCubic,
    this.dismissSnapBackCurve = Curves.easeOutCubic,
  });

  // ── Background & backdrop ─────────────────────────────────────────────────

  /// Background colour of the viewer.
  /// Fades to transparent during dismiss drag so the previous page shows through.
  final Color backgroundColor;

  // ── Info sheet ────────────────────────────────────────────────────────────

  /// Background colour of the info sheet.
  /// Defaults to [backgroundColor] with reduced opacity when null.
  final Color? infoBackgroundColor;

  /// Border radius applied to the top edge of the info sheet.
  final BorderRadius infoBorderRadius;

  /// Colour of the drag handle pill.
  final Color? dragHandleColor;

  /// Width and height of the drag handle pill.
  final Size dragHandleSize;

  // ── Animation durations ───────────────────────────────────────────────────

  /// Duration for the info panel slide-up reveal animation.
  final Duration infoShowDuration;

  /// Duration for the info panel slide-down hide animation.
  final Duration infoHideDuration;

  /// Duration for snapping back after a cancelled dismiss drag.
  final Duration dismissSnapBackDuration;

  // ── Animation curves ──────────────────────────────────────────────────────

  /// Easing curve for info panel show animation.
  final Curve infoShowCurve;

  /// Easing curve for info panel hide animation.
  final Curve infoHideCurve;

  /// Easing curve for dismiss snap-back animation.
  final Curve dismissSnapBackCurve;

  // ── Derived helpers ───────────────────────────────────────────────────────

  /// Effective info background — falls back to a semi-transparent version of
  /// [backgroundColor] when not explicitly set.
  Color effectiveInfoBackground(BuildContext context) {
    if (infoBackgroundColor != null) return infoBackgroundColor!;
    // Use the system's surface colour so the sheet fits Material themes.
    final surface = Theme.of(context).colorScheme.surface;
    return surface;
  }

  Color effectiveDragHandleColor(BuildContext context) {
    return dragHandleColor ??
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3);
  }

  ViewerTheme copyWith({
    Color? backgroundColor,
    Color? infoBackgroundColor,
    BorderRadius? infoBorderRadius,
    Color? dragHandleColor,
    Size? dragHandleSize,
    Duration? infoShowDuration,
    Duration? infoHideDuration,
    Duration? dismissSnapBackDuration,
    Curve? infoShowCurve,
    Curve? infoHideCurve,
    Curve? dismissSnapBackCurve,
  }) {
    return ViewerTheme(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      infoBackgroundColor: infoBackgroundColor ?? this.infoBackgroundColor,
      infoBorderRadius: infoBorderRadius ?? this.infoBorderRadius,
      dragHandleColor: dragHandleColor ?? this.dragHandleColor,
      dragHandleSize: dragHandleSize ?? this.dragHandleSize,
      infoShowDuration: infoShowDuration ?? this.infoShowDuration,
      infoHideDuration: infoHideDuration ?? this.infoHideDuration,
      dismissSnapBackDuration:
          dismissSnapBackDuration ?? this.dismissSnapBackDuration,
      infoShowCurve: infoShowCurve ?? this.infoShowCurve,
      infoHideCurve: infoHideCurve ?? this.infoHideCurve,
      dismissSnapBackCurve: dismissSnapBackCurve ?? this.dismissSnapBackCurve,
    );
  }
}
