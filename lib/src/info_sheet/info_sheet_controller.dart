import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/interaction_config.dart';
import '../core/viewer_state.dart';
import '../core/viewer_theme.dart';

/// Per-page info sheet state controller.
///
/// Manages the two-state (hidden / shown) lifecycle:
/// - Drag tracking with configurable damping.
/// - Settle on release: distance + velocity threshold decides the target anchor.
/// - No intermediate state — always snaps to an anchor (0, defaultShown, maxShown).
/// - Content height measurement to determine [maxShownHeight].
/// - Opacity animation for the "slide-up + fade-in" compound effect.
class InfoSheetController extends ChangeNotifier {
  InfoSheetController({
    required TickerProvider vsync,
    required this.config,
    required this.theme,
  }) {
    _animController = AnimationController(vsync: vsync)
      ..addListener(_onAnimTick);
  }

  final ViewerInteractionConfig config;
  final ViewerTheme theme;

  late final AnimationController _animController;

  // ── Layout dimensions ─────────────────────────────────────────────────────

  double _screenHeight = 0;
  double _measuredContentHeight = 0;
  static const double _dragHandleRegionHeight = 32.0;

  void setScreenHeight(double h) {
    if (_screenHeight == h) return;
    _screenHeight = h;
    // Re-clamp if already shown
    if (_state == InfoState.shown && _sheetHeight > maxShownHeight) {
      _sheetHeight = maxShownHeight;
      notifyListeners();
    }
  }

  /// Called once the info content has been laid out and its height is known.
  void setMeasuredContentHeight(double h) {
    final clamped = h + _dragHandleRegionHeight;
    if ((clamped - _measuredContentHeight).abs() < 1) return;
    _measuredContentHeight = clamped;
    // If info is shown, update max without jumping the current position.
    notifyListeners();
  }

  double get defaultShownHeight => _screenHeight * config.defaultShownExtent;

  /// Maximum height the sheet can reach — bounded by content + screen limits.
  double get maxShownHeight {
    if (_measuredContentHeight <= 0) return defaultShownHeight;
    return math.min(
      _screenHeight * 0.92,
      math.max(defaultShownHeight, _measuredContentHeight),
    );
  }

  // ── Live state ────────────────────────────────────────────────────────────

  InfoState _state = InfoState.hidden;
  double _sheetHeight = 0;

  // Animation interpolation
  double _animFrom = 0;
  double _animTo = 0;
  bool _animIsShow = false;

  // Drag state
  bool _isDragging = false;
  double _dragStartHeight = 0;

  InfoState get state => _state;

  double get sheetHeight => _sheetHeight;

  /// 0.0 = fully hidden → 1.0 = at default half-screen → >1.0 = expanded.
  double get revealProgress {
    if (defaultShownHeight <= 0) return 0;
    return _sheetHeight / defaultShownHeight;
  }

  /// Opacity for the info content: fades in as the sheet rises.
  double get contentOpacity {
    if (_sheetHeight <= 0) return 0.0;
    final fadeRange = defaultShownHeight * 0.35;
    return (_sheetHeight / fadeRange).clamp(0.0, 1.0);
  }

  bool get isDragging => _isDragging;

  // ── Animation ─────────────────────────────────────────────────────────────

  void _onAnimTick() {
    final curve = _animIsShow ? theme.infoShowCurve : theme.infoHideCurve;
    final t = curve.transform(_animController.value);
    _sheetHeight = _animFrom + (_animTo - _animFrom) * t;
    notifyListeners();
  }

  void _animateTo(double target, {required bool isShow}) {
    _animController.stop();
    _animFrom = _sheetHeight;
    _animTo = target;
    _animIsShow = isShow;
    _animController.value = 0;
    _animController.animateTo(
      1.0,
      duration: isShow ? theme.infoShowDuration : theme.infoHideDuration,
    );
  }

  // ── Drag API ──────────────────────────────────────────────────────────────

  void startDrag() {
    _isDragging = true;
    _dragStartHeight = _sheetHeight;
    _animController.stop();
  }

  /// [deltaY] positive = finger moved downward (collapse),
  ///          negative = finger moved upward (expand).
  void updateDrag(double deltaY) {
    if (!_isDragging) return;

    if (deltaY < 0) {
      // Expanding upward.
      final upDelta = -deltaY * config.infoDragUpDamping;
      _sheetHeight = math.min(maxShownHeight, _sheetHeight + upDelta);
    } else {
      // Collapsing downward.
      final downDelta = deltaY * config.infoRestoreDownDamping;
      _sheetHeight = math.max(0, _sheetHeight - downDelta);
    }
    notifyListeners();
  }

  /// [velocityY] positive = downward fling, negative = upward fling.
  void endDrag(double velocityY) {
    _isDragging = false;
    _settle(velocityY);
  }

  // ── Settle logic ──────────────────────────────────────────────────────────

  void _settle(double velocityY) {
    final double target;

    if (_state == InfoState.hidden) {
      // Was revealing → decide show or stay hidden.
      final shouldShow =
          _sheetHeight > config.infoShowDistanceThreshold ||
          velocityY < -config.infoShowVelocityThreshold;

      if (shouldShow) {
        // Snap to nearest anchor: default or max.
        target = _pickShowTarget();
        _state = InfoState.shown;
      } else {
        target = 0;
        _state = InfoState.hidden;
      }
    } else {
      // Was collapsing (or expanding further) from shown state.
      final shouldHide =
          _sheetHeight < (_dragStartHeight - config.infoHideDistanceThreshold) ||
          velocityY > config.infoHideVelocityThreshold;

      if (shouldHide) {
        target = 0;
        _state = InfoState.hidden;
      } else {
        // Snap to nearest anchor.
        target = _pickShowTarget();
        _state = InfoState.shown;
      }
    }

    _animateTo(target, isShow: _state == InfoState.shown);
    notifyListeners();
  }

  /// Picks the appropriate shown anchor based on current height.
  double _pickShowTarget() {
    if (maxShownHeight <= defaultShownHeight) return defaultShownHeight;
    final mid = (defaultShownHeight + maxShownHeight) / 2;
    return _sheetHeight >= mid ? maxShownHeight : defaultShownHeight;
  }

  // ── Imperative API ────────────────────────────────────────────────────────

  void show({bool animated = true}) {
    _state = InfoState.shown;
    if (animated) {
      _animateTo(defaultShownHeight, isShow: true);
    } else {
      _animController.stop();
      _sheetHeight = defaultShownHeight;
      notifyListeners();
    }
  }

  void hide({bool animated = true}) {
    _state = InfoState.hidden;
    if (animated) {
      _animateTo(0, isShow: false);
    } else {
      _animController.stop();
      _sheetHeight = 0;
      notifyListeners();
    }
  }

  void forceHidden() {
    _animController.stop();
    _state = InfoState.hidden;
    _sheetHeight = 0;
    _isDragging = false;
    notifyListeners();
  }

  // ── Dispose ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _animController.removeListener(_onAnimTick);
    _animController.dispose();
    super.dispose();
  }
}
