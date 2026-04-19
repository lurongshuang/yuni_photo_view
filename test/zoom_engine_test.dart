// Tests for the ZoomEngine interface contract (Task 7.5).
//
// `_ZoomableMediaWrapper` is private, so we cannot instantiate it directly.
// Instead we verify the wiring logic through two approaches:
//
//  1. Unit tests for the ZoomEngine interface contract using a mock engine.
//  2. Tests verifying that onScaleChanged → ViewerPageController.reportContentScale
//     wiring works correctly.
//  3. Tests verifying that requestProgrammaticZoom is forwarded correctly.
//
// **Validates: Requirements 5.2, 5.3, 5.6, 5.8**

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuni_photo_view/src/core/viewer_state.dart';
import 'package:yuni_photo_view/src/viewer/zoom_engine.dart';

// ---------------------------------------------------------------------------
// Mock ZoomEngine for testing
// ---------------------------------------------------------------------------

/// A mock [ZoomEngine] that records calls and allows triggering callbacks.
class MockZoomEngine implements ZoomEngine {
  @override
  VoidCallback? onSingleTap;

  @override
  VoidCallback? onDoubleTap;

  @override
  ValueChanged<double>? onScaleChanged;

  // Tracking
  bool disposed = false;
  bool resetCalled = false;
  final List<ViewerProgrammaticZoomKind> programmaticZoomRequests = [];
  final List<({Widget child, bool enabled})> buildCalls = [];

  @override
  Widget build(
    BuildContext context, {
    required Widget child,
    required bool enabled,
  }) {
    buildCalls.add((child: child, enabled: enabled));
    // Return a simple container that wraps the child
    return SizedBox.expand(child: child);
  }

  @override
  void requestProgrammaticZoom(ViewerProgrammaticZoomKind kind) {
    programmaticZoomRequests.add(kind);
  }

  @override
  void reset() {
    resetCalled = true;
  }

  @override
  void dispose() {
    disposed = true;
  }

  /// Simulate the engine calling onScaleChanged (e.g., user pinch-zoomed).
  void simulateScaleChange(double scale) {
    onScaleChanged?.call(scale);
  }

  /// Simulate the engine calling onSingleTap.
  void simulateSingleTap() {
    onSingleTap?.call();
  }
}

// ---------------------------------------------------------------------------
// Simplified stand-in widget that mirrors _ZoomableMediaWrapper wiring
// ---------------------------------------------------------------------------

/// Mirrors the wiring logic of `_ZoomableMediaWrapperState`:
///
///  - Creates a [ZoomEngine] via the factory.
///  - Wires `onSingleTap` and `onScaleChanged` callbacks.
///  - Listens to [ViewerPageController] for programmatic zoom.
///  - Calls `engine.build(context, child: ..., enabled: ...)`.
class _ZoomWiringTestWidget extends StatefulWidget {
  const _ZoomWiringTestWidget({
    super.key,
    required this.child,
    required this.revealProgressListenable,
    required this.enableZoom,
    required this.pageController,
    required this.zoomEngineFactory,
    this.onSingleTap,
  });

  final Widget child;
  final ValueListenable<double> revealProgressListenable;
  final bool enableZoom;
  final ViewerPageController pageController;
  final ZoomEngine Function(TickerProvider vsync) zoomEngineFactory;
  final VoidCallback? onSingleTap;

  @override
  _ZoomWiringTestWidgetState createState() => _ZoomWiringTestWidgetState();
}

class _ZoomWiringTestWidgetState extends State<_ZoomWiringTestWidget>
    with SingleTickerProviderStateMixin {
  late final ZoomEngine _engine;

  @override
  void initState() {
    super.initState();
    _engine = widget.zoomEngineFactory(this);
    _engine.onSingleTap = widget.onSingleTap;
    _engine.onScaleChanged = (s) => widget.pageController.reportContentScale(s);
    widget.pageController.addListener(_onPageCtrlForProgrammaticZoom);
  }

  @override
  void dispose() {
    widget.pageController.removeListener(_onPageCtrlForProgrammaticZoom);
    _engine.dispose();
    super.dispose();
  }

  void _onPageCtrlForProgrammaticZoom() {
    final kind = widget.pageController.takeProgrammaticZoom();
    if (kind == null) return;
    final revealProgress = widget.revealProgressListenable.value;
    if (!widget.enableZoom || revealProgress >= 0.05) return;
    _engine.requestProgrammaticZoom(kind);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: widget.revealProgressListenable,
      builder: (context, revealProgress, _) {
        final bool enabled = widget.enableZoom && revealProgress < 0.01;
        return _engine.build(context, child: widget.child, enabled: enabled);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Unit tests for ZoomEngine interface contract
// ---------------------------------------------------------------------------

void main() {
  group('ZoomEngine interface — mock contract tests', () {
    test('MockZoomEngine implements ZoomEngine interface', () {
      final engine = MockZoomEngine();
      expect(engine, isA<ZoomEngine>());
    });

    test('onScaleChanged callback can be set and called', () {
      final engine = MockZoomEngine();
      double? receivedScale;
      engine.onScaleChanged = (s) => receivedScale = s;

      engine.simulateScaleChange(2.5);

      expect(receivedScale, 2.5);
    });

    test('onSingleTap callback can be set and called', () {
      final engine = MockZoomEngine();
      bool tapped = false;
      engine.onSingleTap = () => tapped = true;

      engine.simulateSingleTap();

      expect(tapped, isTrue);
    });

    test('requestProgrammaticZoom records the zoom kind', () {
      final engine = MockZoomEngine();

      engine.requestProgrammaticZoom(ViewerProgrammaticZoomKind.zoomIn);
      engine.requestProgrammaticZoom(ViewerProgrammaticZoomKind.zoomOut);
      engine.requestProgrammaticZoom(ViewerProgrammaticZoomKind.reset);

      expect(engine.programmaticZoomRequests, [
        ViewerProgrammaticZoomKind.zoomIn,
        ViewerProgrammaticZoomKind.zoomOut,
        ViewerProgrammaticZoomKind.reset,
      ]);
    });

    test('dispose marks engine as disposed', () {
      final engine = MockZoomEngine();
      expect(engine.disposed, isFalse);

      engine.dispose();

      expect(engine.disposed, isTrue);
    });

    test('reset marks engine as reset', () {
      final engine = MockZoomEngine();
      expect(engine.resetCalled, isFalse);

      engine.reset();

      expect(engine.resetCalled, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Wiring tests: onScaleChanged → ViewerPageController.reportContentScale
  // ---------------------------------------------------------------------------

  group('ZoomEngine wiring — onScaleChanged → ViewerPageController', () {
    testWidgets(
      'onScaleChanged callback updates ViewerPageController.contentScale',
      (WidgetTester tester) async {
        final pageController = ViewerPageController();
        final revealNotifier = ValueNotifier<double>(0.0);
        late MockZoomEngine capturedEngine;

        await tester.pumpWidget(
          MaterialApp(
            home: _ZoomWiringTestWidget(
              revealProgressListenable: revealNotifier,
              enableZoom: true,
              pageController: pageController,
              zoomEngineFactory: (vsync) {
                capturedEngine = MockZoomEngine();
                return capturedEngine;
              },
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        );

        // Initially scale is 1.0
        expect(pageController.contentScale, 1.0);

        // Simulate engine reporting a scale change
        capturedEngine.simulateScaleChange(2.5);

        expect(
          pageController.contentScale,
          2.5,
          reason: 'onScaleChanged should forward scale to ViewerPageController',
        );

        revealNotifier.dispose();
        pageController.dispose();
      },
    );

    testWidgets(
      'onScaleChanged with scale > 1.02 sets isZoomed to true',
      (WidgetTester tester) async {
        final pageController = ViewerPageController();
        final revealNotifier = ValueNotifier<double>(0.0);
        late MockZoomEngine capturedEngine;

        await tester.pumpWidget(
          MaterialApp(
            home: _ZoomWiringTestWidget(
              revealProgressListenable: revealNotifier,
              enableZoom: true,
              pageController: pageController,
              zoomEngineFactory: (vsync) {
                capturedEngine = MockZoomEngine();
                return capturedEngine;
              },
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        );

        expect(pageController.isZoomed, isFalse);

        capturedEngine.simulateScaleChange(2.0);

        expect(
          pageController.isZoomed,
          isTrue,
          reason: 'scale > 1.02 should set isZoomed to true',
        );

        revealNotifier.dispose();
        pageController.dispose();
      },
    );

    testWidgets(
      'onScaleChanged with scale = 1.0 sets isZoomed to false',
      (WidgetTester tester) async {
        final pageController = ViewerPageController();
        final revealNotifier = ValueNotifier<double>(0.0);
        late MockZoomEngine capturedEngine;

        await tester.pumpWidget(
          MaterialApp(
            home: _ZoomWiringTestWidget(
              revealProgressListenable: revealNotifier,
              enableZoom: true,
              pageController: pageController,
              zoomEngineFactory: (vsync) {
                capturedEngine = MockZoomEngine();
                return capturedEngine;
              },
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        );

        // First zoom in
        capturedEngine.simulateScaleChange(2.5);
        expect(pageController.isZoomed, isTrue);

        // Then zoom back to 1.0
        capturedEngine.simulateScaleChange(1.0);
        expect(
          pageController.isZoomed,
          isFalse,
          reason: 'scale = 1.0 should set isZoomed to false',
        );

        revealNotifier.dispose();
        pageController.dispose();
      },
    );

    testWidgets(
      'multiple scale changes are all forwarded to ViewerPageController',
      (WidgetTester tester) async {
        final pageController = ViewerPageController();
        final revealNotifier = ValueNotifier<double>(0.0);
        late MockZoomEngine capturedEngine;

        await tester.pumpWidget(
          MaterialApp(
            home: _ZoomWiringTestWidget(
              revealProgressListenable: revealNotifier,
              enableZoom: true,
              pageController: pageController,
              zoomEngineFactory: (vsync) {
                capturedEngine = MockZoomEngine();
                return capturedEngine;
              },
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        );

        for (final scale in [1.5, 2.0, 3.0, 1.0]) {
          capturedEngine.simulateScaleChange(scale);
          expect(pageController.contentScale, scale);
        }

        revealNotifier.dispose();
        pageController.dispose();
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Wiring tests: requestProgrammaticZoom forwarding
  // ---------------------------------------------------------------------------

  group('ZoomEngine wiring — requestProgrammaticZoom forwarding', () {
    testWidgets(
      'zoomIn request is forwarded to engine when zoom is enabled and panel is closed',
      (WidgetTester tester) async {
        final pageController = ViewerPageController();
        final revealNotifier = ValueNotifier<double>(0.0);
        late MockZoomEngine capturedEngine;

        await tester.pumpWidget(
          MaterialApp(
            home: _ZoomWiringTestWidget(
              revealProgressListenable: revealNotifier,
              enableZoom: true,
              pageController: pageController,
              zoomEngineFactory: (vsync) {
                capturedEngine = MockZoomEngine();
                return capturedEngine;
              },
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        );

        pageController.requestProgrammaticZoom(ViewerProgrammaticZoomKind.zoomIn);
        await tester.pump();

        expect(
          capturedEngine.programmaticZoomRequests,
          contains(ViewerProgrammaticZoomKind.zoomIn),
          reason: 'zoomIn request should be forwarded to engine',
        );

        revealNotifier.dispose();
        pageController.dispose();
      },
    );

    testWidgets(
      'zoomOut request is forwarded to engine',
      (WidgetTester tester) async {
        final pageController = ViewerPageController();
        final revealNotifier = ValueNotifier<double>(0.0);
        late MockZoomEngine capturedEngine;

        await tester.pumpWidget(
          MaterialApp(
            home: _ZoomWiringTestWidget(
              revealProgressListenable: revealNotifier,
              enableZoom: true,
              pageController: pageController,
              zoomEngineFactory: (vsync) {
                capturedEngine = MockZoomEngine();
                return capturedEngine;
              },
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        );

        pageController.requestProgrammaticZoom(ViewerProgrammaticZoomKind.zoomOut);
        await tester.pump();

        expect(
          capturedEngine.programmaticZoomRequests,
          contains(ViewerProgrammaticZoomKind.zoomOut),
          reason: 'zoomOut request should be forwarded to engine',
        );

        revealNotifier.dispose();
        pageController.dispose();
      },
    );

    testWidgets(
      'reset request is forwarded to engine',
      (WidgetTester tester) async {
        final pageController = ViewerPageController();
        final revealNotifier = ValueNotifier<double>(0.0);
        late MockZoomEngine capturedEngine;

        await tester.pumpWidget(
          MaterialApp(
            home: _ZoomWiringTestWidget(
              revealProgressListenable: revealNotifier,
              enableZoom: true,
              pageController: pageController,
              zoomEngineFactory: (vsync) {
                capturedEngine = MockZoomEngine();
                return capturedEngine;
              },
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        );

        pageController.requestProgrammaticZoom(ViewerProgrammaticZoomKind.reset);
        await tester.pump();

        expect(
          capturedEngine.programmaticZoomRequests,
          contains(ViewerProgrammaticZoomKind.reset),
          reason: 'reset request should be forwarded to engine',
        );

        revealNotifier.dispose();
        pageController.dispose();
      },
    );

    testWidgets(
      'programmatic zoom is NOT forwarded when enableZoom is false',
      (WidgetTester tester) async {
        final pageController = ViewerPageController();
        final revealNotifier = ValueNotifier<double>(0.0);
        late MockZoomEngine capturedEngine;

        await tester.pumpWidget(
          MaterialApp(
            home: _ZoomWiringTestWidget(
              revealProgressListenable: revealNotifier,
              enableZoom: false, // zoom disabled
              pageController: pageController,
              zoomEngineFactory: (vsync) {
                capturedEngine = MockZoomEngine();
                return capturedEngine;
              },
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        );

        pageController.requestProgrammaticZoom(ViewerProgrammaticZoomKind.zoomIn);
        await tester.pump();

        expect(
          capturedEngine.programmaticZoomRequests,
          isEmpty,
          reason: 'programmatic zoom should NOT be forwarded when enableZoom is false',
        );

        revealNotifier.dispose();
        pageController.dispose();
      },
    );

    testWidgets(
      'programmatic zoom is NOT forwarded when info panel is open (revealProgress >= 0.05)',
      (WidgetTester tester) async {
        final pageController = ViewerPageController();
        final revealNotifier = ValueNotifier<double>(0.1); // panel open
        late MockZoomEngine capturedEngine;

        await tester.pumpWidget(
          MaterialApp(
            home: _ZoomWiringTestWidget(
              revealProgressListenable: revealNotifier,
              enableZoom: true,
              pageController: pageController,
              zoomEngineFactory: (vsync) {
                capturedEngine = MockZoomEngine();
                return capturedEngine;
              },
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        );

        pageController.requestProgrammaticZoom(ViewerProgrammaticZoomKind.zoomIn);
        await tester.pump();

        expect(
          capturedEngine.programmaticZoomRequests,
          isEmpty,
          reason: 'programmatic zoom should NOT be forwarded when info panel is open',
        );

        revealNotifier.dispose();
        pageController.dispose();
      },
    );

    testWidgets(
      'multiple programmatic zoom requests are all forwarded in order',
      (WidgetTester tester) async {
        final pageController = ViewerPageController();
        final revealNotifier = ValueNotifier<double>(0.0);
        late MockZoomEngine capturedEngine;

        await tester.pumpWidget(
          MaterialApp(
            home: _ZoomWiringTestWidget(
              revealProgressListenable: revealNotifier,
              enableZoom: true,
              pageController: pageController,
              zoomEngineFactory: (vsync) {
                capturedEngine = MockZoomEngine();
                return capturedEngine;
              },
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        );

        // Each requestProgrammaticZoom notifies listeners once, so we pump after each
        pageController.requestProgrammaticZoom(ViewerProgrammaticZoomKind.zoomIn);
        await tester.pump();
        pageController.requestProgrammaticZoom(ViewerProgrammaticZoomKind.zoomOut);
        await tester.pump();
        pageController.requestProgrammaticZoom(ViewerProgrammaticZoomKind.reset);
        await tester.pump();

        expect(
          capturedEngine.programmaticZoomRequests,
          [
            ViewerProgrammaticZoomKind.zoomIn,
            ViewerProgrammaticZoomKind.zoomOut,
            ViewerProgrammaticZoomKind.reset,
          ],
          reason: 'all programmatic zoom requests should be forwarded in order',
        );

        revealNotifier.dispose();
        pageController.dispose();
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Wiring tests: onSingleTap forwarding
  // ---------------------------------------------------------------------------

  group('ZoomEngine wiring — onSingleTap forwarding', () {
    testWidgets(
      'onSingleTap callback is wired to the provided callback',
      (WidgetTester tester) async {
        final pageController = ViewerPageController();
        final revealNotifier = ValueNotifier<double>(0.0);
        late MockZoomEngine capturedEngine;
        bool singleTapCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: _ZoomWiringTestWidget(
              revealProgressListenable: revealNotifier,
              enableZoom: true,
              pageController: pageController,
              onSingleTap: () => singleTapCalled = true,
              zoomEngineFactory: (vsync) {
                capturedEngine = MockZoomEngine();
                return capturedEngine;
              },
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        );

        // Simulate engine triggering single tap
        capturedEngine.simulateSingleTap();

        expect(
          singleTapCalled,
          isTrue,
          reason: 'onSingleTap should be forwarded from engine to the provided callback',
        );

        revealNotifier.dispose();
        pageController.dispose();
      },
    );

    testWidgets(
      'engine is disposed when widget is removed from tree',
      (WidgetTester tester) async {
        final pageController = ViewerPageController();
        final revealNotifier = ValueNotifier<double>(0.0);
        late MockZoomEngine capturedEngine;

        await tester.pumpWidget(
          MaterialApp(
            home: _ZoomWiringTestWidget(
              revealProgressListenable: revealNotifier,
              enableZoom: true,
              pageController: pageController,
              zoomEngineFactory: (vsync) {
                capturedEngine = MockZoomEngine();
                return capturedEngine;
              },
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        );

        expect(capturedEngine.disposed, isFalse);

        // Remove the widget from the tree
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));

        expect(
          capturedEngine.disposed,
          isTrue,
          reason: 'engine should be disposed when widget is removed from tree',
        );

        revealNotifier.dispose();
        pageController.dispose();
      },
    );
  });

  // ---------------------------------------------------------------------------
  // ZoomEngine build method tests
  // ---------------------------------------------------------------------------

  group('ZoomEngine wiring — build method', () {
    testWidgets(
      'engine.build is called with enabled=true when revealProgress < 0.01',
      (WidgetTester tester) async {
        final pageController = ViewerPageController();
        final revealNotifier = ValueNotifier<double>(0.0);
        late MockZoomEngine capturedEngine;

        await tester.pumpWidget(
          MaterialApp(
            home: _ZoomWiringTestWidget(
              revealProgressListenable: revealNotifier,
              enableZoom: true,
              pageController: pageController,
              zoomEngineFactory: (vsync) {
                capturedEngine = MockZoomEngine();
                return capturedEngine;
              },
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        );

        expect(capturedEngine.buildCalls, isNotEmpty);
        expect(
          capturedEngine.buildCalls.last.enabled,
          isTrue,
          reason: 'engine.build should be called with enabled=true when revealProgress < 0.01',
        );

        revealNotifier.dispose();
        pageController.dispose();
      },
    );

    testWidgets(
      'engine.build is called with enabled=false when revealProgress >= 0.01',
      (WidgetTester tester) async {
        final pageController = ViewerPageController();
        final revealNotifier = ValueNotifier<double>(0.0);
        late MockZoomEngine capturedEngine;

        await tester.pumpWidget(
          MaterialApp(
            home: _ZoomWiringTestWidget(
              revealProgressListenable: revealNotifier,
              enableZoom: true,
              pageController: pageController,
              zoomEngineFactory: (vsync) {
                capturedEngine = MockZoomEngine();
                return capturedEngine;
              },
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        );

        // Open the info panel
        revealNotifier.value = 0.5;
        await tester.pump();

        expect(
          capturedEngine.buildCalls.last.enabled,
          isFalse,
          reason: 'engine.build should be called with enabled=false when revealProgress >= 0.01',
        );

        revealNotifier.dispose();
        pageController.dispose();
      },
    );

    testWidgets(
      'engine.build is called with enabled=false when enableZoom is false',
      (WidgetTester tester) async {
        final pageController = ViewerPageController();
        final revealNotifier = ValueNotifier<double>(0.0);
        late MockZoomEngine capturedEngine;

        await tester.pumpWidget(
          MaterialApp(
            home: _ZoomWiringTestWidget(
              revealProgressListenable: revealNotifier,
              enableZoom: false, // zoom disabled
              pageController: pageController,
              zoomEngineFactory: (vsync) {
                capturedEngine = MockZoomEngine();
                return capturedEngine;
              },
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        );

        expect(
          capturedEngine.buildCalls.last.enabled,
          isFalse,
          reason: 'engine.build should be called with enabled=false when enableZoom is false',
        );

        revealNotifier.dispose();
        pageController.dispose();
      },
    );
  });
}
