import 'package:flutter/material.dart';
import 'dart:math'; // 导入 math 库以使用 pow
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../models/media_item.dart';
import '../controllers/media_viewer_controller.dart';
import '../gestures/yuni_media_gesture_handler.dart';

typedef YuniMediaContentBuilder = Widget Function(
  BuildContext context,
  YuniMediaItem item,
);

typedef YuniMediaInfoBuilder = Widget Function(
  BuildContext context,
  YuniMediaItem item,
  dynamic info,
);

class YuniMediaViewer extends StatefulWidget {
  final List<YuniMediaItem> items;
  final YuniMediaViewerController controller;
  final YuniMediaContentBuilder contentBuilder;
  final Future<dynamic> Function(YuniMediaItem item)? infoProvider;
  final Widget Function(BuildContext context, int index)? topOverlayBuilder;
  final Widget Function(BuildContext context, int index)? bottomOverlayBuilder;
  final YuniMediaInfoBuilder? infoLayerBuilder;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String heroTagPrefix;
  final double infoShowDamping;
  final double infoHideDamping;
  final double dismissDamping;

  const YuniMediaViewer({
    super.key,
    required this.items,
    required this.controller,
    required this.contentBuilder,
    this.infoProvider,
    this.topOverlayBuilder,
    this.bottomOverlayBuilder,
    this.infoLayerBuilder,
    this.onTap,
    this.onLongPress,
    this.heroTagPrefix = '',
    this.infoShowDamping = 0.2,
    this.infoHideDamping = 0.5,
    this.dismissDamping = 1.0,
  });

  static Future<void> show(
    BuildContext context, {
    required List<YuniMediaItem> items,
    required YuniMediaViewerController controller,
    required YuniMediaContentBuilder contentBuilder,
    Future<dynamic> Function(YuniMediaItem item)? infoProvider,
    Widget Function(BuildContext context, int index)? topOverlayBuilder,
    Widget Function(BuildContext context, int index)? bottomOverlayBuilder,
    YuniMediaInfoBuilder? infoLayerBuilder,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    String heroTagPrefix = '',
    double infoShowDamping = 0.2,
    double infoHideDamping = 0.5,
    double dismissDamping = 1.0,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent, 
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: YuniMediaViewer(
              items: items,
              controller: controller,
              contentBuilder: contentBuilder,
              infoProvider: infoProvider,
              topOverlayBuilder: topOverlayBuilder,
              bottomOverlayBuilder: bottomOverlayBuilder,
              infoLayerBuilder: infoLayerBuilder,
              onTap: onTap,
              onLongPress: onLongPress,
              heroTagPrefix: heroTagPrefix,
              infoShowDamping: infoShowDamping,
              infoHideDamping: infoHideDamping,
              dismissDamping: dismissDamping,
            ),
          );
        },
      ),
    );
  }

  @override
  State<YuniMediaViewer> createState() => _YuniMediaViewerState();
}

class _YuniMediaViewerState extends State<YuniMediaViewer> {
  late PageController _pageController;
  dynamic _currentInfo;
  bool _isLoadingInfo = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.controller.currentIndex);
    widget.controller.addListener(_onControllerChanged);
    _updateMediaSize();
    _loadInfo();
  }

  void _updateMediaSize() {
    final item = widget.items[widget.controller.currentIndex];
    if (item is YuniMediaItemImpl && item.width != null && item.height != null) {
      widget.controller.updateCurrentMediaSize(Size(item.width!, item.height!));
    } else {
      // 默认先设为 null，让 GestureHandler 降级处理或等待动态更新
      widget.controller.updateCurrentMediaSize(null);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _pageController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (_pageController.hasClients &&
        _pageController.page?.round() != widget.controller.currentIndex) {
      _pageController.jumpToPage(widget.controller.currentIndex);
      _updateMediaSize();
      _loadInfo();
    }
  }

  Future<void> _loadInfo() async {
    if (widget.infoProvider == null) return;
    setState(() => _isLoadingInfo = true);
    try {
      final item = widget.items[widget.controller.currentIndex];
      final info = await widget.infoProvider!(item);
      if (mounted) setState(() { _currentInfo = info; _isLoadingInfo = false; });
    } catch (_) { if (mounted) setState(() => _isLoadingInfo = false); }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (widget.controller.infoProgress > 0.01) {
          widget.controller.hideInfo();
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent, 
        body: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            return Stack(
              children: [
                // 1. 内容与手势驱动层 (像素级核心)
                YuniMediaGestureHandler(
                  controller: widget.controller,
                  onDismiss: () => Navigator.of(context).pop(),
                  infoShowDamping: widget.infoShowDamping,
                  infoHideDamping: widget.infoHideDamping,
                  dismissDamping: widget.dismissDamping,
                  // 详情层包装在 ScrollView 中以支持长信息
                  infoLayer: _buildScrollableInfoLayer(screenHeight),
                  child: GestureDetector(
                    onTap: () => widget.controller.toggleOverlay(),
                    onLongPress: widget.onLongPress,
                    child: PhotoViewGallery.builder(
                      itemCount: widget.items.length,
                      builder: (context, index) {
                        final item = widget.items[index];
                        return PhotoViewGalleryPageOptions.customChild(
                          child: _childPlaceholder(context, item),
                          initialScale: PhotoViewComputedScale.contained,
                          minScale: PhotoViewComputedScale.contained,
                          maxScale: PhotoViewComputedScale.covered * 4,
                          heroAttributes: PhotoViewHeroAttributes(
                            tag: '${widget.heroTagPrefix}${item.id}',
                          ),
                        );
                      },
                      pageController: _pageController,
                      onPageChanged: (index) {
                        widget.controller.jumpTo(index);
                        _updateMediaSize();
                        _loadInfo();
                      },
                      scrollPhysics: widget.controller.infoProgress > 0.01 
                          ? const NeverScrollableScrollPhysics() 
                          : const BouncingScrollPhysics(),
                      backgroundDecoration: const BoxDecoration(color: Colors.transparent),
                    ),
                  ),
                ),

                // 2. 锁定 UI 层：固定定位于屏幕边缘
                if (widget.controller.isOverlayVisible)
                  IgnorePointer(
                    ignoring: widget.controller.opacity < 1.0 || widget.controller.infoProgress > 0.1,
                    child: Opacity(
                      opacity: (widget.controller.opacity * (1 - pow(widget.controller.infoProgress, 2))).clamp(0.0, 1.0).toDouble(),
                      child: Stack(
                        children: [
                          if (widget.topOverlayBuilder != null)
                            Positioned(
                              top: 0, left: 0, right: 0,
                              child: widget.topOverlayBuilder!(context, widget.controller.currentIndex),
                            ),
                          if (widget.bottomOverlayBuilder != null)
                            Positioned(
                              bottom: 0, left: 0, right: 0,
                              child: widget.bottomOverlayBuilder!(context, widget.controller.currentIndex),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _childPlaceholder(BuildContext context, YuniMediaItem item) {
    return widget.contentBuilder(context, item);
  }

  Widget? _buildScrollableInfoLayer(double screenHeight) {
    if (widget.infoLayerBuilder == null) return null;
    
    return SizedBox(
      height: screenHeight * 0.5, // 终态占 50% 屏
      child: SingleChildScrollView(
        // 只有吸附完成后才允许内容区滚动
        physics: widget.controller.isSnappedToDetails 
            ? const BouncingScrollPhysics() 
            : const NeverScrollableScrollPhysics(),
        clipBehavior: Clip.none,
        child: _isLoadingInfo
            ? const Center(child: Padding(padding: EdgeInsets.all(100), child: CircularProgressIndicator()))
            : widget.infoLayerBuilder!(
                context,
                widget.items[widget.controller.currentIndex],
                _currentInfo,
              ),
      ),
    );
  }
}
