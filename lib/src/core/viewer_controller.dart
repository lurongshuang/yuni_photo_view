import 'package:flutter/foundation.dart';

import 'viewer_state.dart';

/// External controller for [MediaViewer].
///
/// Obtain from [MediaViewer.controller] or pass your own instance.
/// The framework populates internal state automatically; you only need to
/// call commands or listen to change events.
class MediaViewerController extends ChangeNotifier {
  int _currentIndex = 0;
  InfoState _currentInfoState = InfoState.hidden;
  double _dismissProgress = 0.0;

  // Internal callbacks wired by the MediaViewer widget.
  VoidCallback? _jumpToPageCallback;
  VoidCallback? _showInfoCallback;
  VoidCallback? _hideInfoCallback;
  int _pendingJumpIndex = 0;

  // ── Read-only state ───────────────────────────────────────────────────────

  /// Index of the currently visible page.
  int get currentIndex => _currentIndex;

  /// Current info panel state of the visible page.
  InfoState get currentInfoState => _currentInfoState;

  /// Dismiss drag progress (0.0–1.0). Useful for external UI that wants to
  /// fade in sync with the dismiss gesture.
  double get dismissProgress => _dismissProgress;

  // ── Internal update methods (called by the framework) ─────────────────────

  /// @nodoc
  void updateIndex(int index) {
    if (_currentIndex == index) return;
    _currentIndex = index;
    notifyListeners();
  }

  /// @nodoc
  void updateInfoState(InfoState state) {
    if (_currentInfoState == state) return;
    _currentInfoState = state;
    notifyListeners();
  }

  /// @nodoc
  void updateDismissProgress(double progress) {
    if ((_dismissProgress - progress).abs() < 0.001) return;
    _dismissProgress = progress;
    notifyListeners();
  }

  /// @nodoc
  void attachCallbacks({
    required VoidCallback jumpToPage,
    required VoidCallback showInfo,
    required VoidCallback hideInfo,
  }) {
    _jumpToPageCallback = jumpToPage;
    _showInfoCallback = showInfo;
    _hideInfoCallback = hideInfo;
  }

  // ── Public commands ───────────────────────────────────────────────────────

  /// Animate the pager to the given [index].
  void jumpToPage(int index) {
    _pendingJumpIndex = index;
    _jumpToPageCallback?.call();
  }

  /// Programmatically reveal the info panel for the current page.
  void showInfo() => _showInfoCallback?.call();

  /// Programmatically hide the info panel for the current page.
  void hideInfo() => _hideInfoCallback?.call();

  /// Toggle the info panel visibility.
  void toggleInfo() {
    if (_currentInfoState == InfoState.shown) {
      hideInfo();
    } else {
      showInfo();
    }
  }

  /// @nodoc
  int get pendingJumpIndex => _pendingJumpIndex;
}
