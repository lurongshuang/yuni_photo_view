import 'package:flutter/material.dart';

class YuniMediaViewerController extends ChangeNotifier {
  int _currentIndex;
  double _opacity = 1.0;
  bool _isOverlayVisible = true;
  double _infoProgress = 0.0;
  bool _isSnappedToDetails = false;

  Size? _currentMediaSize;

  YuniMediaViewerController({int initialIndex = 0}) : _currentIndex = initialIndex;

  int get currentIndex => _currentIndex;
  double get opacity => _opacity;
  bool get isOverlayVisible => _isOverlayVisible;
  double get infoProgress => _infoProgress;
  bool get isSnappedToDetails => _isSnappedToDetails;
  Size? get currentMediaSize => _currentMediaSize;

  void jumpTo(int index) {
    if (_currentIndex == index) return;
    _currentIndex = index;
    notifyListeners();
  }

  void updateCurrentMediaSize(Size? size) {
    if (_currentMediaSize == size) return;
    _currentMediaSize = size;
    notifyListeners();
  }

  void updateOpacity(double opacity) {
    _opacity = opacity.clamp(0.0, 1.0);
    notifyListeners();
  }

  void toggleOverlay() {
    _isOverlayVisible = !_isOverlayVisible;
    notifyListeners();
  }

  void hideOverlay() {
    _isOverlayVisible = false;
    notifyListeners();
  }

  void showOverlay() {
    _isOverlayVisible = true;
    notifyListeners();
  }

  void setInfoProgress(double progress) {
    _infoProgress = progress.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setIsSnappedToDetails(bool isSnapped) {
    _isSnappedToDetails = isSnapped;
    notifyListeners();
  }

  void hideInfo() {
    // 外部触发隐藏详情的便捷方法，实际动画由 GestureHandler 驱动
    _isSnappedToDetails = false;
    _infoProgress = 0.0;
    notifyListeners();
  }
}
