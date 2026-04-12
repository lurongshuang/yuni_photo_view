import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/interaction_config.dart';
import '../core/viewer_state.dart';
import '../core/viewer_theme.dart';

/// 每一页独立持有的信息面板控制器。
///
/// - 二态：隐藏 / 展开（含默认高度与可继续上拉的最大高度）。
/// - 拖动带阻尼；松手按距离+速度阈值吸附到锚点。
/// - 可测量内容高度以计算 [maxShownHeight]。
/// - 内容上拉时配合透明度实现「升起+渐显」。
class InfoSheetController extends ChangeNotifier {
  InfoSheetController({
    required TickerProvider vsync,
    required this.config,
    required this.theme,
    InfoState initialState = InfoState.hidden,
  }) {
    _state = initialState;
    _sheetHeight = initialState == InfoState.shown ? defaultShownHeight : 0;
    _animController = AnimationController(vsync: vsync)
      ..addListener(_onAnimTick);
  }

  final ViewerInteractionConfig config;
  final ViewerTheme theme;

  late final AnimationController _animController;

  // ── 布局尺寸 ─────────────────────────────────────────────────────────────

  double _screenHeight = 0;
  double _measuredContentHeight = 0;
  static const double _dragHandleRegionHeight = 32.0;

  void setScreenHeight(double h) {
    if ((_screenHeight - h).abs() < 0.1) return;

    final oldDefault = defaultShownHeight;
    _screenHeight = h;
    final newDefault = defaultShownHeight;

    if (_state == InfoState.shown) {
      // 场景 A：初次获取屏幕高度（之前是 0），且默认就是展示态 -> 直接对齐
      // 注意：此处不调用 notifyListeners()，因为调用方（ViewerPageShell.build）正处于 build 阶段，
      // 随后的 ListenableBuilder 自然会读取最新值。若调用则会引发 setState() during build 报错。
      if (oldDefault <= 0 && newDefault > 0) {
        _sheetHeight = newDefault;
      }
      // 场景 B：屏幕尺寸变化（如旋转），若当前高度超出新上限，需夹紧
      else if (_sheetHeight > maxShownHeight) {
        _sheetHeight = maxShownHeight;
        // 如果我们确知在构建中（通过 stack trace 知道），应避免立即通知。
        // 使用 microtask 或 postFrameCallback 兜底以防状态不一致。
        Future.microtask(notifyListeners);
      }
    }
  }

  /// 信息区内业务内容布局完成后回调，用于更新可展开的最大高度。
  void setMeasuredContentHeight(double h) {
    final clamped = h + _dragHandleRegionHeight;
    if ((clamped - _measuredContentHeight).abs() < 1) return;
    _measuredContentHeight = clamped;
    notifyListeners();
  }

  double get defaultShownHeight => _screenHeight * config.defaultShownExtent;

  /// 面板可达的最大高度：受屏幕与内容高度共同限制。
  double get maxShownHeight {
    if (_measuredContentHeight <= 0) return defaultShownHeight;
    return math.min(
      _screenHeight * 0.92,
      math.max(defaultShownHeight, _measuredContentHeight),
    );
  }

  // ── 运行时状态 ───────────────────────────────────────────────────────────

  InfoState _state = InfoState.hidden;
  double _sheetHeight = 0;

  // 动画插值用
  double _animFrom = 0;
  double _animTo = 0;
  bool _animIsShow = false;

  // 拖动
  bool _isDragging = false;
  double _dragStartHeight = 0;

  InfoState get state => _state;

  double get sheetHeight => _sheetHeight;

  /// 相对默认高度的比例：0 完全收起，1 恰为默认半屏，可大于 1。
  double get revealProgress {
    if (defaultShownHeight <= 0) return 0;
    return _sheetHeight / defaultShownHeight;
  }

  /// 信息区内文字等的透明度，随高度上升渐显。
  double get contentOpacity {
    if (_sheetHeight <= 0) return 0.0;
    final fadeRange = defaultShownHeight * 0.35;
    return (_sheetHeight / fadeRange).clamp(0.0, 1.0);
  }

  bool get isDragging => _isDragging;

  // ── 动画 tick ────────────────────────────────────────────────────────────

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

  // ── 拖动 API ───────────────────────────────────────────────────────────────

  void startDrag() {
    _isDragging = true;
    _dragStartHeight = _sheetHeight;
    _animController.stop();
  }

  /// [deltaY]：手指向下为正（压低面板），向上为负（拉高面板）。
  void updateDrag(double deltaY) {
    if (!_isDragging) return;

    if (deltaY < 0) {
      // 向上展开
      final upDelta = -deltaY * config.infoDragUpDamping;
      _sheetHeight = math.min(maxShownHeight, _sheetHeight + upDelta);
    } else {
      // 向下收回
      final downDelta = deltaY * config.infoRestoreDownDamping;
      _sheetHeight = math.max(0, _sheetHeight - downDelta);
    }
    notifyListeners();
  }

  /// [velocityY]：向下甩为正，向上甩为负。
  void endDrag(double velocityY) {
    _isDragging = false;
    _settle(velocityY);
  }

  // ── 松手吸附逻辑 ──────────────────────────────────────────────────────────

  void _settle(double velocityY) {
    final double target;

    if (_state == InfoState.hidden) {
      // 从隐藏态上拉：决定展开还是回到 0。
      final shouldShow = _sheetHeight > config.infoShowDistanceThreshold ||
          velocityY < -config.infoShowVelocityThreshold;

      if (shouldShow) {
        target = _pickShowTarget();
        _state = InfoState.shown;
      } else {
        target = 0;
        _state = InfoState.hidden;
      }
    } else {
      // 从展开态：决定收起还是吸附到某一展开高度。
      final shouldHide = _sheetHeight <
              (_dragStartHeight - config.infoHideDistanceThreshold) ||
          velocityY > config.infoHideVelocityThreshold;

      if (shouldHide) {
        target = 0;
        _state = InfoState.hidden;
      } else {
        target = _pickShowTarget();
        _state = InfoState.shown;
      }
    }

    _animateTo(target, isShow: _state == InfoState.shown);
    notifyListeners();
  }

  /// 在「默认高度」与「最大内容高度」两锚点间择近吸附。
  double _pickShowTarget() {
    if (maxShownHeight <= defaultShownHeight) return defaultShownHeight;
    final mid = (defaultShownHeight + maxShownHeight) / 2;
    return _sheetHeight >= mid ? maxShownHeight : defaultShownHeight;
  }

  // ── 命令式 API ────────────────────────────────────────────────────────────

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

  // ── 释放 ─────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _animController.removeListener(_onAnimTick);
    _animController.dispose();
    super.dispose();
  }
}
