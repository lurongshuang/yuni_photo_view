import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuni_photo_view/src/core/viewer_theme.dart';

void main() {
  // A baseline theme with non-default values so we can detect accidental changes.
  final baseline = ViewerTheme(
    backgroundColor: Colors.white,
    infoBackgroundColor: Colors.grey,
    infoBorderRadius: const BorderRadius.all(Radius.circular(8)),
    dragHandleColor: Colors.red,
    dragHandleSize: const Size(40, 6),
    infoShowDuration: const Duration(milliseconds: 400),
    infoHideDuration: const Duration(milliseconds: 350),
    dismissSnapBackDuration: const Duration(milliseconds: 450),
    infoShowCurve: Curves.linear,
    infoHideCurve: Curves.bounceIn,
    dismissSnapBackCurve: Curves.bounceOut,
    mediaCardInsetTop: 8,
    mediaCardInsetBottom: 8,
    mediaCardInsetLeft: 8,
    mediaCardInsetRight: 8,
    mediaCardBorderRadius: 12,
    mediaCardAnimationDuration: const Duration(milliseconds: 300),
    mediaCardAnimationCurve: Curves.easeIn,
    barsToggleDuration: const Duration(milliseconds: 150),
    barsToggleCurve: Curves.easeOut,
    zoomDuration: const Duration(milliseconds: 200),
    zoomCurve: Curves.easeInOut,
  );

  group('ViewerTheme.copyWith — new fields', () {
    test('barsToggleDuration: non-null value is applied, other fields unchanged', () {
      const newDuration = Duration(milliseconds: 999);
      final copy = baseline.copyWith(barsToggleDuration: newDuration);

      expect(copy.barsToggleDuration, newDuration);

      // All other fields must remain equal to baseline.
      expect(copy.backgroundColor, baseline.backgroundColor);
      expect(copy.infoBackgroundColor, baseline.infoBackgroundColor);
      expect(copy.infoBorderRadius, baseline.infoBorderRadius);
      expect(copy.dragHandleColor, baseline.dragHandleColor);
      expect(copy.dragHandleSize, baseline.dragHandleSize);
      expect(copy.infoShowDuration, baseline.infoShowDuration);
      expect(copy.infoHideDuration, baseline.infoHideDuration);
      expect(copy.dismissSnapBackDuration, baseline.dismissSnapBackDuration);
      expect(copy.infoShowCurve, baseline.infoShowCurve);
      expect(copy.infoHideCurve, baseline.infoHideCurve);
      expect(copy.dismissSnapBackCurve, baseline.dismissSnapBackCurve);
      expect(copy.mediaCardInset, baseline.mediaCardInset);
      expect(copy.mediaCardBorderRadius, baseline.mediaCardBorderRadius);
      expect(copy.mediaCardAnimationDuration, baseline.mediaCardAnimationDuration);
      expect(copy.mediaCardAnimationCurve, baseline.mediaCardAnimationCurve);
      expect(copy.barsToggleCurve, baseline.barsToggleCurve);
      expect(copy.zoomDuration, baseline.zoomDuration);
      expect(copy.zoomCurve, baseline.zoomCurve);
    });

    test('barsToggleCurve: non-null value is applied, other fields unchanged', () {
      const newCurve = Curves.bounceInOut;
      final copy = baseline.copyWith(barsToggleCurve: newCurve);

      expect(copy.barsToggleCurve, newCurve);

      expect(copy.backgroundColor, baseline.backgroundColor);
      expect(copy.infoBackgroundColor, baseline.infoBackgroundColor);
      expect(copy.infoBorderRadius, baseline.infoBorderRadius);
      expect(copy.dragHandleColor, baseline.dragHandleColor);
      expect(copy.dragHandleSize, baseline.dragHandleSize);
      expect(copy.infoShowDuration, baseline.infoShowDuration);
      expect(copy.infoHideDuration, baseline.infoHideDuration);
      expect(copy.dismissSnapBackDuration, baseline.dismissSnapBackDuration);
      expect(copy.infoShowCurve, baseline.infoShowCurve);
      expect(copy.infoHideCurve, baseline.infoHideCurve);
      expect(copy.dismissSnapBackCurve, baseline.dismissSnapBackCurve);
      expect(copy.mediaCardInset, baseline.mediaCardInset);
      expect(copy.mediaCardBorderRadius, baseline.mediaCardBorderRadius);
      expect(copy.mediaCardAnimationDuration, baseline.mediaCardAnimationDuration);
      expect(copy.mediaCardAnimationCurve, baseline.mediaCardAnimationCurve);
      expect(copy.barsToggleDuration, baseline.barsToggleDuration);
      expect(copy.zoomDuration, baseline.zoomDuration);
      expect(copy.zoomCurve, baseline.zoomCurve);
    });

    test('zoomDuration: non-null value is applied, other fields unchanged', () {
      const newDuration = Duration(milliseconds: 777);
      final copy = baseline.copyWith(zoomDuration: newDuration);

      expect(copy.zoomDuration, newDuration);

      expect(copy.backgroundColor, baseline.backgroundColor);
      expect(copy.infoBackgroundColor, baseline.infoBackgroundColor);
      expect(copy.infoBorderRadius, baseline.infoBorderRadius);
      expect(copy.dragHandleColor, baseline.dragHandleColor);
      expect(copy.dragHandleSize, baseline.dragHandleSize);
      expect(copy.infoShowDuration, baseline.infoShowDuration);
      expect(copy.infoHideDuration, baseline.infoHideDuration);
      expect(copy.dismissSnapBackDuration, baseline.dismissSnapBackDuration);
      expect(copy.infoShowCurve, baseline.infoShowCurve);
      expect(copy.infoHideCurve, baseline.infoHideCurve);
      expect(copy.dismissSnapBackCurve, baseline.dismissSnapBackCurve);
      expect(copy.mediaCardInset, baseline.mediaCardInset);
      expect(copy.mediaCardBorderRadius, baseline.mediaCardBorderRadius);
      expect(copy.mediaCardAnimationDuration, baseline.mediaCardAnimationDuration);
      expect(copy.mediaCardAnimationCurve, baseline.mediaCardAnimationCurve);
      expect(copy.barsToggleDuration, baseline.barsToggleDuration);
      expect(copy.barsToggleCurve, baseline.barsToggleCurve);
      expect(copy.zoomCurve, baseline.zoomCurve);
    });

    test('zoomCurve: non-null value is applied, other fields unchanged', () {
      const newCurve = Curves.elasticIn;
      final copy = baseline.copyWith(zoomCurve: newCurve);

      expect(copy.zoomCurve, newCurve);

      expect(copy.backgroundColor, baseline.backgroundColor);
      expect(copy.infoBackgroundColor, baseline.infoBackgroundColor);
      expect(copy.infoBorderRadius, baseline.infoBorderRadius);
      expect(copy.dragHandleColor, baseline.dragHandleColor);
      expect(copy.dragHandleSize, baseline.dragHandleSize);
      expect(copy.infoShowDuration, baseline.infoShowDuration);
      expect(copy.infoHideDuration, baseline.infoHideDuration);
      expect(copy.dismissSnapBackDuration, baseline.dismissSnapBackDuration);
      expect(copy.infoShowCurve, baseline.infoShowCurve);
      expect(copy.infoHideCurve, baseline.infoHideCurve);
      expect(copy.dismissSnapBackCurve, baseline.dismissSnapBackCurve);
      expect(copy.mediaCardInset, baseline.mediaCardInset);
      expect(copy.mediaCardBorderRadius, baseline.mediaCardBorderRadius);
      expect(copy.mediaCardAnimationDuration, baseline.mediaCardAnimationDuration);
      expect(copy.mediaCardAnimationCurve, baseline.mediaCardAnimationCurve);
      expect(copy.barsToggleDuration, baseline.barsToggleDuration);
      expect(copy.barsToggleCurve, baseline.barsToggleCurve);
      expect(copy.zoomDuration, baseline.zoomDuration);
    });
  });

  group('ViewerTheme.copyWith — idempotency', () {
    /// Validates: Requirements 4.7
    ///
    /// For any ViewerTheme instance t, t.copyWith() equals t on all fields.
    test('copyWith() with no arguments preserves all fields (idempotency)', () {
      final copy = baseline.copyWith();

      expect(copy.backgroundColor, baseline.backgroundColor);
      expect(copy.infoBackgroundColor, baseline.infoBackgroundColor);
      expect(copy.infoBorderRadius, baseline.infoBorderRadius);
      expect(copy.dragHandleColor, baseline.dragHandleColor);
      expect(copy.dragHandleSize, baseline.dragHandleSize);
      expect(copy.infoShowDuration, baseline.infoShowDuration);
      expect(copy.infoHideDuration, baseline.infoHideDuration);
      expect(copy.dismissSnapBackDuration, baseline.dismissSnapBackDuration);
      expect(copy.infoShowCurve, baseline.infoShowCurve);
      expect(copy.infoHideCurve, baseline.infoHideCurve);
      expect(copy.dismissSnapBackCurve, baseline.dismissSnapBackCurve);
      expect(copy.mediaCardInset, baseline.mediaCardInset);
      expect(copy.mediaCardBorderRadius, baseline.mediaCardBorderRadius);
      expect(copy.mediaCardAnimationDuration, baseline.mediaCardAnimationDuration);
      expect(copy.mediaCardAnimationCurve, baseline.mediaCardAnimationCurve);
      expect(copy.barsToggleDuration, baseline.barsToggleDuration);
      expect(copy.barsToggleCurve, baseline.barsToggleCurve);
      expect(copy.zoomDuration, baseline.zoomDuration);
      expect(copy.zoomCurve, baseline.zoomCurve);
    });

    test('copyWith() with no arguments on default-constructed theme preserves all fields', () {
      const defaultTheme = ViewerTheme();
      final copy = defaultTheme.copyWith();

      expect(copy.backgroundColor, defaultTheme.backgroundColor);
      expect(copy.infoBackgroundColor, defaultTheme.infoBackgroundColor);
      expect(copy.infoBorderRadius, defaultTheme.infoBorderRadius);
      expect(copy.dragHandleColor, defaultTheme.dragHandleColor);
      expect(copy.dragHandleSize, defaultTheme.dragHandleSize);
      expect(copy.infoShowDuration, defaultTheme.infoShowDuration);
      expect(copy.infoHideDuration, defaultTheme.infoHideDuration);
      expect(copy.dismissSnapBackDuration, defaultTheme.dismissSnapBackDuration);
      expect(copy.infoShowCurve, defaultTheme.infoShowCurve);
      expect(copy.infoHideCurve, defaultTheme.infoHideCurve);
      expect(copy.dismissSnapBackCurve, defaultTheme.dismissSnapBackCurve);
      expect(copy.mediaCardInset, defaultTheme.mediaCardInset);
      expect(copy.mediaCardBorderRadius, defaultTheme.mediaCardBorderRadius);
      expect(copy.mediaCardAnimationDuration, defaultTheme.mediaCardAnimationDuration);
      expect(copy.mediaCardAnimationCurve, defaultTheme.mediaCardAnimationCurve);
      expect(copy.barsToggleDuration, defaultTheme.barsToggleDuration);
      expect(copy.barsToggleCurve, defaultTheme.barsToggleCurve);
      expect(copy.zoomDuration, defaultTheme.zoomDuration);
      expect(copy.zoomCurve, defaultTheme.zoomCurve);
    });
  });
}
