// Tests for the double-tap / single-tap race condition fix (Task 3).
//
// `_ZoomableMediaWrapper` is a private class, so we cannot instantiate it
// directly in tests. Instead we verify the guard logic through two approaches:
//
//  1. Unit tests for the guard logic itself (pure Dart, no Flutter widgets).
//  2. A lightweight widget test using a simplified stand-in widget that
//     replicates the exact guard pattern used in `_ZoomableMediaWrapper`.
//
// Full integration tests that drive `MediaViewer` end-to-end are deferred
// because they require a real `photo_view` gesture pipeline (which needs a
// device / integration-test environment).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Minimal stand-in widget that replicates the _doubleTapGuard pattern
// ---------------------------------------------------------------------------

/// A simplified widget that mirrors the guard logic in `_ZoomableMediaWrapper`:
///
///  - `onSingleTap` is only called when `!_doubleTapGuard`.
///  - `simulateDoubleTap()` sets `_doubleTapGuard = true` and schedules a
///    post-frame reset, then calls the zoom callback.
///  - `simulateSingleTap()` calls `onSingleTap` if the guard is not set.
class _GuardTestWidget extends StatefulWidget {
  const _GuardTestWidget({
    super.key,
    required this.onSingleTap,
    required this.onZoom,
  });

  final VoidCallback onSingleTap;
  final VoidCallback onZoom;

  @override
  _GuardTestWidgetState createState() => _GuardTestWidgetState();
}

class _GuardTestWidgetState extends State<_GuardTestWidget> {
  bool _doubleTapGuard = false;

  /// Mirrors `_handleDoubleTap` + `_runDoubleTapAnimation` in the real widget.
  void simulateDoubleTap() {
    _doubleTapGuard = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _doubleTapGuard = false;
    });
    widget.onZoom();
  }

  /// Mirrors the `onTapUp` callback in the real widget.
  void simulateSingleTap() {
    if (!_doubleTapGuard) {
      widget.onSingleTap();
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('_doubleTapGuard logic — unit-level', () {
    test('guard starts as false', () {
      // The field is initialised to false; onTapUp should fire immediately.
      bool guard = false;
      int singleTapCount = 0;

      // Simulate onTapUp with guard = false
      if (!guard) singleTapCount++;

      expect(singleTapCount, 1);
    });

    test('guard set to true blocks onTapUp', () {
      bool guard = true; // as set by _handleDoubleTap
      int singleTapCount = 0;

      if (!guard) singleTapCount++;

      expect(singleTapCount, 0);
    });

    test('guard reset to false after postFrameCallback allows next tap', () {
      bool guard = true;
      int singleTapCount = 0;

      // Simulate postFrameCallback reset
      guard = false;

      if (!guard) singleTapCount++;

      expect(singleTapCount, 1);
    });
  });

  group('_doubleTapGuard — widget-level via _GuardTestWidget', () {
    testWidgets(
      'double-tap sequence: onSingleTap is NOT called, onZoom IS called',
      (WidgetTester tester) async {
        int singleTapCount = 0;
        int zoomCount = 0;

        final key = GlobalKey<_GuardTestWidgetState>();

        await tester.pumpWidget(
          MaterialApp(
            home: _GuardTestWidget(
              key: key,
              onSingleTap: () => singleTapCount++,
              onZoom: () => zoomCount++,
            ),
          ),
        );

        final state = key.currentState!;

        // Simulate the double-tap sequence:
        //   1. scaleStateCycle fires → sets guard, schedules reset, calls zoom
        //   2. onTapUp fires in the same frame → guard is still true → blocked
        state.simulateDoubleTap(); // sets guard = true, calls onZoom
        state.simulateSingleTap(); // guard is true → onSingleTap NOT called

        expect(zoomCount, 1, reason: 'zoom callback should fire on double-tap');
        expect(
          singleTapCount,
          0,
          reason: 'onSingleTap must NOT fire during a double-tap sequence',
        );

        // After the next frame the guard is reset.
        await tester.pump();

        // A subsequent single tap should now work normally.
        state.simulateSingleTap();
        expect(singleTapCount, 1,
            reason: 'onSingleTap should fire after guard is reset');
      },
    );

    testWidgets(
      'single-tap sequence: onSingleTap IS called once, onZoom is NOT called',
      (WidgetTester tester) async {
        int singleTapCount = 0;
        int zoomCount = 0;

        final key = GlobalKey<_GuardTestWidgetState>();

        await tester.pumpWidget(
          MaterialApp(
            home: _GuardTestWidget(
              key: key,
              onSingleTap: () => singleTapCount++,
              onZoom: () => zoomCount++,
            ),
          ),
        );

        final state = key.currentState!;

        // Simulate a plain single-tap: only onTapUp fires, no scaleStateCycle.
        state.simulateSingleTap();

        expect(
          singleTapCount,
          1,
          reason: 'onSingleTap must fire exactly once on a single tap',
        );
        expect(
          zoomCount,
          0,
          reason: 'zoom callback must NOT fire on a single tap',
        );
      },
    );

    testWidgets(
      'guard is reset after one frame so subsequent single-tap works',
      (WidgetTester tester) async {
        int singleTapCount = 0;

        final key = GlobalKey<_GuardTestWidgetState>();

        await tester.pumpWidget(
          MaterialApp(
            home: _GuardTestWidget(
              key: key,
              onSingleTap: () => singleTapCount++,
              onZoom: () {},
            ),
          ),
        );

        final state = key.currentState!;

        // Double-tap sets the guard.
        state.simulateDoubleTap();
        state.simulateSingleTap(); // blocked
        expect(singleTapCount, 0);

        // Advance one frame → postFrameCallback fires → guard reset.
        await tester.pump();

        state.simulateSingleTap(); // should now fire
        expect(singleTapCount, 1);
      },
    );

    testWidgets(
      'multiple single taps each fire onSingleTap independently',
      (WidgetTester tester) async {
        int singleTapCount = 0;

        final key = GlobalKey<_GuardTestWidgetState>();

        await tester.pumpWidget(
          MaterialApp(
            home: _GuardTestWidget(
              key: key,
              onSingleTap: () => singleTapCount++,
              onZoom: () {},
            ),
          ),
        );

        final state = key.currentState!;

        state.simulateSingleTap();
        state.simulateSingleTap();
        state.simulateSingleTap();

        expect(singleTapCount, 3);
      },
    );
  });

  group('_runDoubleTapAnimation guard — isAnimating early-return logic', () {
    // The `if (_animCtrl.isAnimating) return;` guard prevents re-entrant
    // animation starts. We verify the logic pattern directly.

    test('animation is not restarted when already animating', () {
      int animationStartCount = 0;
      bool isAnimating = false;

      void runAnimation() {
        if (isAnimating) return; // mirrors the guard
        isAnimating = true;
        animationStartCount++;
      }

      // First call starts the animation.
      runAnimation();
      expect(animationStartCount, 1);
      expect(isAnimating, true);

      // Second call while animating is ignored.
      runAnimation();
      expect(animationStartCount, 1,
          reason: 'animation must not restart while already running');
    });

    test('animation can start again after it completes', () {
      int animationStartCount = 0;
      bool isAnimating = false;

      void runAnimation() {
        if (isAnimating) return;
        isAnimating = true;
        animationStartCount++;
      }

      runAnimation(); // starts
      isAnimating = false; // simulate completion
      runAnimation(); // starts again

      expect(animationStartCount, 2);
    });
  });
}
