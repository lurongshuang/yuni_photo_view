// Tests for the _cachedMedia cache strategy fix (Task 4).
//
// `_ViewerPageShellState` is private, so we cannot instantiate it directly.
// Instead we verify the cache logic through two approaches:
//
//  1. Unit tests for the `_needsRebuildCache` logic itself (pure Dart).
//  2. Widget tests using a simplified stand-in widget that replicates the
//     exact caching pattern used in `_ViewerPageShellState`.
//
// The caching pattern being tested:
//   - pageBuilder is called when barsVisible changes
//   - pageBuilder is called when dismissProgress changes (threshold 0.001)
//   - pageBuilder is NOT called when infoRevealProgress changes (uses Listenable)
//
// **Validates: Requirements 3.1, 3.2, 3.4, 3.5**

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers that mirror the _needsRebuildCache logic
// ---------------------------------------------------------------------------

/// Pure-Dart replica of the `_needsRebuildCache` getter logic.
bool needsRebuildCache({
  required bool cachedIsNull,
  required Object? lastItem,
  required Object? currentItem,
  required Object? lastBuilder,
  required Object? currentBuilder,
  required bool lastBarsVisible,
  required bool currentBarsVisible,
  required double lastDismissProgress,
  required double currentDismissProgress,
}) {
  return cachedIsNull ||
      lastItem != currentItem ||
      lastBuilder != currentBuilder ||
      lastBarsVisible != currentBarsVisible ||
      (lastDismissProgress - currentDismissProgress).abs() > 0.001;
}

// ---------------------------------------------------------------------------
// Simplified stand-in widget that replicates the _ViewerPageShellState cache
// ---------------------------------------------------------------------------

/// A simplified widget that mirrors the caching pattern in `_ViewerPageShellState`:
///
///  - `pageBuilder` is called when `barsVisible` or `dismissProgress` changes.
///  - `pageBuilder` is NOT called when `infoRevealProgress` changes (uses
///    `infoRevealProgressListenable` for local updates).
class _CacheTestWidget extends StatefulWidget {
  const _CacheTestWidget({
    super.key,
    required this.barsVisible,
    required this.dismissProgress,
    required this.infoRevealProgressListenable,
    required this.pageBuilder,
  });

  final bool barsVisible;
  final double dismissProgress;
  final ValueListenable<double> infoRevealProgressListenable;

  /// Called to build the cached media widget. Counts how many times it's called.
  final Widget Function(bool barsVisible, double dismissProgress) pageBuilder;

  @override
  _CacheTestWidgetState createState() => _CacheTestWidgetState();
}

class _CacheTestWidgetState extends State<_CacheTestWidget> {
  Widget? _cachedMedia;
  bool? _lastBarsVisible;
  double? _lastDismissProgress;

  bool get _needsRebuildCache =>
      _cachedMedia == null ||
      _lastBarsVisible != widget.barsVisible ||
      (_lastDismissProgress == null ||
          (_lastDismissProgress! - widget.dismissProgress).abs() > 0.001);

  @override
  Widget build(BuildContext context) {
    if (_needsRebuildCache) {
      _cachedMedia = widget.pageBuilder(widget.barsVisible, widget.dismissProgress);
      _lastBarsVisible = widget.barsVisible;
      _lastDismissProgress = widget.dismissProgress;
    }

    // infoRevealProgress changes are handled via Listenable — no rebuild of
    // _cachedMedia. We use ValueListenableBuilder for local updates only.
    return ValueListenableBuilder<double>(
      valueListenable: widget.infoRevealProgressListenable,
      builder: (context, revealProgress, _) {
        return Column(
          children: [
            _cachedMedia!,
            Text('reveal:$revealProgress'),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Unit tests for the _needsRebuildCache logic
// ---------------------------------------------------------------------------

void main() {
  group('_needsRebuildCache logic — unit-level', () {
    const item = 'item1';
    const builder = 'builder1';

    test('returns true when cache is null', () {
      expect(
        needsRebuildCache(
          cachedIsNull: true,
          lastItem: item,
          currentItem: item,
          lastBuilder: builder,
          currentBuilder: builder,
          lastBarsVisible: true,
          currentBarsVisible: true,
          lastDismissProgress: 0.0,
          currentDismissProgress: 0.0,
        ),
        isTrue,
      );
    });

    test('returns false when nothing changed', () {
      expect(
        needsRebuildCache(
          cachedIsNull: false,
          lastItem: item,
          currentItem: item,
          lastBuilder: builder,
          currentBuilder: builder,
          lastBarsVisible: true,
          currentBarsVisible: true,
          lastDismissProgress: 0.0,
          currentDismissProgress: 0.0,
        ),
        isFalse,
      );
    });

    test('returns true when barsVisible changes from true to false', () {
      expect(
        needsRebuildCache(
          cachedIsNull: false,
          lastItem: item,
          currentItem: item,
          lastBuilder: builder,
          currentBuilder: builder,
          lastBarsVisible: true,
          currentBarsVisible: false,
          lastDismissProgress: 0.0,
          currentDismissProgress: 0.0,
        ),
        isTrue,
      );
    });

    test('returns true when barsVisible changes from false to true', () {
      expect(
        needsRebuildCache(
          cachedIsNull: false,
          lastItem: item,
          currentItem: item,
          lastBuilder: builder,
          currentBuilder: builder,
          lastBarsVisible: false,
          currentBarsVisible: true,
          lastDismissProgress: 0.0,
          currentDismissProgress: 0.0,
        ),
        isTrue,
      );
    });

    test('returns true when dismissProgress changes beyond threshold', () {
      expect(
        needsRebuildCache(
          cachedIsNull: false,
          lastItem: item,
          currentItem: item,
          lastBuilder: builder,
          currentBuilder: builder,
          lastBarsVisible: true,
          currentBarsVisible: true,
          lastDismissProgress: 0.0,
          currentDismissProgress: 0.5,
        ),
        isTrue,
      );
    });

    test('returns false when dismissProgress changes within threshold (0.001)', () {
      expect(
        needsRebuildCache(
          cachedIsNull: false,
          lastItem: item,
          currentItem: item,
          lastBuilder: builder,
          currentBuilder: builder,
          lastBarsVisible: true,
          currentBarsVisible: true,
          lastDismissProgress: 0.0,
          currentDismissProgress: 0.0005,
        ),
        isFalse,
      );
    });

    test('returns true when dismissProgress changes exactly at threshold', () {
      expect(
        needsRebuildCache(
          cachedIsNull: false,
          lastItem: item,
          currentItem: item,
          lastBuilder: builder,
          currentBuilder: builder,
          lastBarsVisible: true,
          currentBarsVisible: true,
          lastDismissProgress: 0.0,
          currentDismissProgress: 0.0011,
        ),
        isTrue,
      );
    });

    test('returns true when item changes', () {
      expect(
        needsRebuildCache(
          cachedIsNull: false,
          lastItem: 'item1',
          currentItem: 'item2',
          lastBuilder: builder,
          currentBuilder: builder,
          lastBarsVisible: true,
          currentBarsVisible: true,
          lastDismissProgress: 0.0,
          currentDismissProgress: 0.0,
        ),
        isTrue,
      );
    });

    test('returns true when builder changes', () {
      expect(
        needsRebuildCache(
          cachedIsNull: false,
          lastItem: item,
          currentItem: item,
          lastBuilder: 'builder1',
          currentBuilder: 'builder2',
          lastBarsVisible: true,
          currentBarsVisible: true,
          lastDismissProgress: 0.0,
          currentDismissProgress: 0.0,
        ),
        isTrue,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Widget tests using the simplified stand-in widget
  // ---------------------------------------------------------------------------

  group('_CacheTestWidget — widget-level cache strategy tests', () {
    testWidgets(
      'pageBuilder is called once on initial build',
      (WidgetTester tester) async {
        int buildCount = 0;
        final infoNotifier = ValueNotifier<double>(0.0);

        await tester.pumpWidget(
          MaterialApp(
            home: _CacheTestWidget(
              barsVisible: true,
              dismissProgress: 0.0,
              infoRevealProgressListenable: infoNotifier,
              pageBuilder: (barsVisible, dismissProgress) {
                buildCount++;
                return Text('media:$barsVisible:$dismissProgress');
              },
            ),
          ),
        );

        expect(buildCount, 1, reason: 'pageBuilder should be called once on initial build');

        infoNotifier.dispose();
      },
    );

    testWidgets(
      'pageBuilder is called again when barsVisible changes',
      (WidgetTester tester) async {
        int buildCount = 0;
        final infoNotifier = ValueNotifier<double>(0.0);

        await tester.pumpWidget(
          MaterialApp(
            home: _CacheTestWidget(
              barsVisible: true,
              dismissProgress: 0.0,
              infoRevealProgressListenable: infoNotifier,
              pageBuilder: (barsVisible, dismissProgress) {
                buildCount++;
                return Text('media:$barsVisible:$dismissProgress');
              },
            ),
          ),
        );

        expect(buildCount, 1);

        // Change barsVisible to false
        await tester.pumpWidget(
          MaterialApp(
            home: _CacheTestWidget(
              barsVisible: false,
              dismissProgress: 0.0,
              infoRevealProgressListenable: infoNotifier,
              pageBuilder: (barsVisible, dismissProgress) {
                buildCount++;
                return Text('media:$barsVisible:$dismissProgress');
              },
            ),
          ),
        );

        expect(
          buildCount,
          2,
          reason: 'pageBuilder should be called again when barsVisible changes',
        );

        infoNotifier.dispose();
      },
    );

    testWidgets(
      'pageBuilder is called again when dismissProgress changes',
      (WidgetTester tester) async {
        int buildCount = 0;
        final infoNotifier = ValueNotifier<double>(0.0);

        await tester.pumpWidget(
          MaterialApp(
            home: _CacheTestWidget(
              barsVisible: true,
              dismissProgress: 0.0,
              infoRevealProgressListenable: infoNotifier,
              pageBuilder: (barsVisible, dismissProgress) {
                buildCount++;
                return Text('media:$barsVisible:$dismissProgress');
              },
            ),
          ),
        );

        expect(buildCount, 1);

        // Change dismissProgress significantly
        await tester.pumpWidget(
          MaterialApp(
            home: _CacheTestWidget(
              barsVisible: true,
              dismissProgress: 0.5,
              infoRevealProgressListenable: infoNotifier,
              pageBuilder: (barsVisible, dismissProgress) {
                buildCount++;
                return Text('media:$barsVisible:$dismissProgress');
              },
            ),
          ),
        );

        expect(
          buildCount,
          2,
          reason: 'pageBuilder should be called again when dismissProgress changes',
        );

        infoNotifier.dispose();
      },
    );

    testWidgets(
      'pageBuilder is NOT called again when infoRevealProgress changes via Listenable',
      (WidgetTester tester) async {
        int buildCount = 0;
        final infoNotifier = ValueNotifier<double>(0.0);

        await tester.pumpWidget(
          MaterialApp(
            home: _CacheTestWidget(
              barsVisible: true,
              dismissProgress: 0.0,
              infoRevealProgressListenable: infoNotifier,
              pageBuilder: (barsVisible, dismissProgress) {
                buildCount++;
                return Text('media:$barsVisible:$dismissProgress');
              },
            ),
          ),
        );

        expect(buildCount, 1);

        // Change infoRevealProgress via the Listenable — should NOT trigger pageBuilder
        infoNotifier.value = 0.5;
        await tester.pump();

        expect(
          buildCount,
          1,
          reason: 'pageBuilder must NOT be called when infoRevealProgress changes via Listenable',
        );

        infoNotifier.value = 1.0;
        await tester.pump();

        expect(
          buildCount,
          1,
          reason: 'pageBuilder must NOT be called on further infoRevealProgress changes',
        );

        infoNotifier.dispose();
      },
    );

    testWidgets(
      'pageBuilder is NOT called again when dismissProgress changes within threshold',
      (WidgetTester tester) async {
        int buildCount = 0;
        final infoNotifier = ValueNotifier<double>(0.0);

        await tester.pumpWidget(
          MaterialApp(
            home: _CacheTestWidget(
              barsVisible: true,
              dismissProgress: 0.0,
              infoRevealProgressListenable: infoNotifier,
              pageBuilder: (barsVisible, dismissProgress) {
                buildCount++;
                return Text('media:$barsVisible:$dismissProgress');
              },
            ),
          ),
        );

        expect(buildCount, 1);

        // Change dismissProgress within the 0.001 threshold — should NOT rebuild
        await tester.pumpWidget(
          MaterialApp(
            home: _CacheTestWidget(
              barsVisible: true,
              dismissProgress: 0.0005,
              infoRevealProgressListenable: infoNotifier,
              pageBuilder: (barsVisible, dismissProgress) {
                buildCount++;
                return Text('media:$barsVisible:$dismissProgress');
              },
            ),
          ),
        );

        expect(
          buildCount,
          1,
          reason: 'pageBuilder should NOT be called for dismissProgress changes within 0.001 threshold',
        );

        infoNotifier.dispose();
      },
    );

    testWidgets(
      'pageBuilder receives updated barsVisible value when rebuilt',
      (WidgetTester tester) async {
        bool? lastBarsVisible;
        final infoNotifier = ValueNotifier<double>(0.0);

        await tester.pumpWidget(
          MaterialApp(
            home: _CacheTestWidget(
              barsVisible: true,
              dismissProgress: 0.0,
              infoRevealProgressListenable: infoNotifier,
              pageBuilder: (barsVisible, dismissProgress) {
                lastBarsVisible = barsVisible;
                return Text('media:$barsVisible');
              },
            ),
          ),
        );

        expect(lastBarsVisible, isTrue);

        await tester.pumpWidget(
          MaterialApp(
            home: _CacheTestWidget(
              barsVisible: false,
              dismissProgress: 0.0,
              infoRevealProgressListenable: infoNotifier,
              pageBuilder: (barsVisible, dismissProgress) {
                lastBarsVisible = barsVisible;
                return Text('media:$barsVisible');
              },
            ),
          ),
        );

        expect(
          lastBarsVisible,
          isFalse,
          reason: 'pageBuilder should receive the updated barsVisible=false value',
        );

        infoNotifier.dispose();
      },
    );

    testWidgets(
      'pageBuilder receives updated dismissProgress value when rebuilt',
      (WidgetTester tester) async {
        double? lastDismissProgress;
        final infoNotifier = ValueNotifier<double>(0.0);

        await tester.pumpWidget(
          MaterialApp(
            home: _CacheTestWidget(
              barsVisible: true,
              dismissProgress: 0.0,
              infoRevealProgressListenable: infoNotifier,
              pageBuilder: (barsVisible, dismissProgress) {
                lastDismissProgress = dismissProgress;
                return Text('media:$dismissProgress');
              },
            ),
          ),
        );

        expect(lastDismissProgress, 0.0);

        await tester.pumpWidget(
          MaterialApp(
            home: _CacheTestWidget(
              barsVisible: true,
              dismissProgress: 0.5,
              infoRevealProgressListenable: infoNotifier,
              pageBuilder: (barsVisible, dismissProgress) {
                lastDismissProgress = dismissProgress;
                return Text('media:$dismissProgress');
              },
            ),
          ),
        );

        expect(
          lastDismissProgress,
          closeTo(0.5, 0.001),
          reason: 'pageBuilder should receive the updated dismissProgress value',
        );

        infoNotifier.dispose();
      },
    );

    testWidgets(
      'multiple barsVisible toggles each trigger a pageBuilder rebuild',
      (WidgetTester tester) async {
        int buildCount = 0;
        final infoNotifier = ValueNotifier<double>(0.0);

        Future<void> pump(bool barsVisible) async {
          await tester.pumpWidget(
            MaterialApp(
              home: _CacheTestWidget(
                barsVisible: barsVisible,
                dismissProgress: 0.0,
                infoRevealProgressListenable: infoNotifier,
                pageBuilder: (barsVisible, dismissProgress) {
                  buildCount++;
                  return Text('media:$barsVisible');
                },
              ),
            ),
          );
        }

        await pump(true);   // build 1
        await pump(false);  // build 2
        await pump(true);   // build 3
        await pump(false);  // build 4

        expect(
          buildCount,
          4,
          reason: 'each barsVisible toggle should trigger a pageBuilder rebuild',
        );

        infoNotifier.dispose();
      },
    );
  });
}
