// ignore_for_file: avoid_print

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Pure-function mirror of RenderCoverFrame._computeGeometry (new logic)
//
// New semantics:
//   - child is laid out at natural size (scale=1) at p=0, centered
//   - at p=1: scale = max(1, viewH/childH) — only upscale if childH < viewH
//   - dy: lerp from (viewH-childH)/2 (centered) to 0 (top-aligned)
// ---------------------------------------------------------------------------

({double scale, double dx, double dy}) computeGeometry({
  required double viewW,
  required double viewH,
  required double childW,
  required double childH,
  required double p,
}) {
  // scale at p=1: upscale to fill viewport height if needed, never downscale
  final scaleAtP1 = math.max(1.0, viewH / childH);
  final scale = lerpDouble(1.0, scaleAtP1, p)!;

  final scaledW = childW * scale;

  final dx = (viewW - scaledW) / 2.0;

  // dy: lerp from centered (p=0) to top-aligned (p=1)
  final dyAtP0 = (viewH - childH) / 2.0;
  final dy = lerpDouble(dyAtP0, 0.0, p)!;

  return (scale: scale, dx: dx, dy: dy);
}

// ---------------------------------------------------------------------------
// Unit tests
// ---------------------------------------------------------------------------

void main() {
  // ── Landscape image (childH < viewH — needs upscaling at p=1) ─────────────
  //
  // viewW=400, viewH=800, childW=400, childH=225  (16:9 landscape)
  // scaleAtP1 = max(1, 800/225) = 3.556
  group('Landscape image (childW=400, childH=225, viewW=400, viewH=800)', () {
    const viewW = 400.0;
    const viewH = 800.0;
    const childW = 400.0;
    const childH = 225.0;

    test('p=0: scale=1.0, image at natural size, centered', () {
      final g = computeGeometry(
        viewW: viewW, viewH: viewH, childW: childW, childH: childH, p: 0.0,
      );

      expect(g.scale, closeTo(1.0, 0.001));
      // dy = (800 - 225) / 2 = 287.5
      expect(g.dy, closeTo(287.5, 0.001));
      // dx = (400 - 400) / 2 = 0
      expect(g.dx, closeTo(0.0, 0.001));
    });

    test('p=1: scale=viewH/childH, fills viewport height, top-aligned', () {
      final g = computeGeometry(
        viewW: viewW, viewH: viewH, childW: childW, childH: childH, p: 1.0,
      );

      final expectedScale = viewH / childH; // 3.556
      expect(g.scale, closeTo(expectedScale, 0.001));
      expect(g.dy, closeTo(0.0, 0.001));
    });

    test('p=0.5: scale and dy interpolated', () {
      final g = computeGeometry(
        viewW: viewW, viewH: viewH, childW: childW, childH: childH, p: 0.5,
      );

      final scaleAtP1 = viewH / childH;
      final expectedScale = lerpDouble(1.0, scaleAtP1, 0.5)!;
      expect(g.scale, closeTo(expectedScale, 0.001));

      // dy = lerp(287.5, 0, 0.5) = 143.75
      expect(g.dy, closeTo(143.75, 0.001));
    });
  });

  // ── Portrait image (childH > viewH — no upscaling needed) ─────────────────
  //
  // viewW=400, viewH=800, childW=300, childH=1200  (tall portrait)
  // scaleAtP1 = max(1, 800/1200) = max(1, 0.667) = 1.0  → no upscale
  group('Portrait image (childW=300, childH=1200, viewW=400, viewH=800)', () {
    const viewW = 400.0;
    const viewH = 800.0;
    const childW = 300.0;
    const childH = 1200.0;

    test('p=0: scale=1.0, image at natural size, centered (dy negative = overflows)', () {
      final g = computeGeometry(
        viewW: viewW, viewH: viewH, childW: childW, childH: childH, p: 0.0,
      );

      expect(g.scale, closeTo(1.0, 0.001));
      // dy = (800 - 1200) / 2 = -200  (image taller than viewport, clipped)
      expect(g.dy, closeTo(-200.0, 0.001));
    });

    test('p=1: scale=1.0 (no upscale needed), top-aligned (dy=0)', () {
      final g = computeGeometry(
        viewW: viewW, viewH: viewH, childW: childW, childH: childH, p: 1.0,
      );

      // scaleAtP1 = max(1, 800/1200) = 1.0
      expect(g.scale, closeTo(1.0, 0.001));
      expect(g.dy, closeTo(0.0, 0.001));
    });
  });

  // ── Square image (childH == viewH — exactly fits) ─────────────────────────
  //
  // viewW=400, viewH=800, childW=400, childH=800
  // scaleAtP1 = max(1, 800/800) = 1.0
  group('Square-ish image (childW=400, childH=800, viewW=400, viewH=800)', () {
    const viewW = 400.0;
    const viewH = 800.0;
    const childW = 400.0;
    const childH = 800.0;

    test('p=0: scale=1.0, dy=0 (exactly fills viewport)', () {
      final g = computeGeometry(
        viewW: viewW, viewH: viewH, childW: childW, childH: childH, p: 0.0,
      );

      expect(g.scale, closeTo(1.0, 0.001));
      expect(g.dy, closeTo(0.0, 0.001));
    });

    test('p=1: scale=1.0, dy=0 (no change needed)', () {
      final g = computeGeometry(
        viewW: viewW, viewH: viewH, childW: childW, childH: childH, p: 1.0,
      );

      expect(g.scale, closeTo(1.0, 0.001));
      expect(g.dy, closeTo(0.0, 0.001));
    });
  });

  // ── Scale accuracy ≤ 0.001 ────────────────────────────────────────────────
  group('Scale accuracy (error ≤ 0.001)', () {
    test('scale equals lerp(1.0, max(1, viewH/childH), p) within 0.001', () {
      const cases = [
        (viewW: 375.0, viewH: 812.0, childW: 375.0, childH: 211.0, p: 0.3),  // landscape
        (viewW: 414.0, viewH: 896.0, childW: 300.0, childH: 400.0, p: 0.7),  // portrait
        (viewW: 360.0, viewH: 780.0, childW: 360.0, childH: 780.0, p: 0.5),  // exact fit
      ];

      for (final c in cases) {
        final scaleAtP1 = math.max(1.0, c.viewH / c.childH);
        final expectedScale = lerpDouble(1.0, scaleAtP1, c.p)!;

        final g = computeGeometry(
          viewW: c.viewW, viewH: c.viewH,
          childW: c.childW, childH: c.childH,
          p: c.p,
        );

        expect(g.scale, closeTo(expectedScale, 0.001), reason: 'case $c');
      }
    });
  });

  // ── Property tests ────────────────────────────────────────────────────────
  group('Property tests', () {
    test('scale is always >= 1.0 (never downscale)', () {
      final rng = math.Random(42);
      const iterations = 500;
      int failures = 0;

      for (int i = 0; i < iterations; i++) {
        final viewW = 10.0 + rng.nextDouble() * 1990;
        final viewH = 10.0 + rng.nextDouble() * 1990;
        final childW = 10.0 + rng.nextDouble() * 1990;
        final childH = 10.0 + rng.nextDouble() * 1990;
        final p = rng.nextDouble();

        final g = computeGeometry(
          viewW: viewW, viewH: viewH, childW: childW, childH: childH, p: p,
        );

        if (g.scale < 1.0 - 0.001) {
          failures++;
          print('FAIL scale<1: viewW=$viewW viewH=$viewH childW=$childW '
              'childH=$childH p=$p → scale=${g.scale}');
        }
      }

      expect(failures, 0,
          reason: '$failures/$iterations cases had scale < 1.0');
    });

    test('dy at p=1 equals 0 (top-aligned)', () {
      final rng = math.Random(99);
      const iterations = 500;
      int failures = 0;

      for (int i = 0; i < iterations; i++) {
        final viewW = 10.0 + rng.nextDouble() * 1990;
        final viewH = 10.0 + rng.nextDouble() * 1990;
        final childW = 10.0 + rng.nextDouble() * 1990;
        final childH = 10.0 + rng.nextDouble() * 1990;

        final g = computeGeometry(
          viewW: viewW, viewH: viewH, childW: childW, childH: childH, p: 1.0,
        );

        if (g.dy.abs() > 0.001) {
          failures++;
          print('FAIL dy@p=1: viewW=$viewW viewH=$viewH childW=$childW '
              'childH=$childH → dy=${g.dy}');
        }
      }

      expect(failures, 0,
          reason: '$failures/$iterations cases had dy@p=1 ≠ 0');
    });

    test('scale at p=1 equals max(1, viewH/childH)', () {
      final rng = math.Random(7);
      const iterations = 500;
      int failures = 0;

      for (int i = 0; i < iterations; i++) {
        final viewW = 10.0 + rng.nextDouble() * 1990;
        final viewH = 10.0 + rng.nextDouble() * 1990;
        final childW = 10.0 + rng.nextDouble() * 1990;
        final childH = 10.0 + rng.nextDouble() * 1990;

        final g = computeGeometry(
          viewW: viewW, viewH: viewH, childW: childW, childH: childH, p: 1.0,
        );

        final expected = math.max(1.0, viewH / childH);
        if ((g.scale - expected).abs() > 0.001) {
          failures++;
          print('FAIL scale@p=1: viewW=$viewW viewH=$viewH childW=$childW '
              'childH=$childH → scale=${g.scale} expected=$expected');
        }
      }

      expect(failures, 0,
          reason: '$failures/$iterations cases had scale@p=1 ≠ max(1, viewH/childH)');
    });

    test('scale at p=0 equals 1.0 (natural size)', () {
      final rng = math.Random(123);
      const iterations = 500;
      int failures = 0;

      for (int i = 0; i < iterations; i++) {
        final viewW = 10.0 + rng.nextDouble() * 1990;
        final viewH = 10.0 + rng.nextDouble() * 1990;
        final childW = 10.0 + rng.nextDouble() * 1990;
        final childH = 10.0 + rng.nextDouble() * 1990;

        final g = computeGeometry(
          viewW: viewW, viewH: viewH, childW: childW, childH: childH, p: 0.0,
        );

        if ((g.scale - 1.0).abs() > 0.001) {
          failures++;
          print('FAIL scale@p=0: viewW=$viewW viewH=$viewH childW=$childW '
              'childH=$childH → scale=${g.scale}');
        }
      }

      expect(failures, 0,
          reason: '$failures/$iterations cases had scale@p=0 ≠ 1.0');
    });
  });
}
