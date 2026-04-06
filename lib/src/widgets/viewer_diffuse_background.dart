import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

import '../core/viewer_state.dart';

/// 一个带有两个扩散毛玻璃圆环的动态背景组件。
///
/// 常用作 [MediaViewer.backgroundBuilder] 的返回值。
///
/// 功能：
/// 1. **自动取色**: 传入 [url] 且未传 [color] 时，自动从图片中提取主题色。
/// 2. **图片感知布局**: 自动获取图片尺寸，使背景球始终对齐到图片的渲染边界（而非屏幕边界）。
/// 3. **状态联动**: 联动 [ViewerPageContext.barsVisible] 和 [ViewerPageContext.mediaCardClipRadiusListenable]，
///    实现全屏沉浸模式下自动淡出。
class ViewerDiffuseBackground extends StatefulWidget {
  const ViewerDiffuseBackground({
    super.key,
    required this.pageCtx,
    this.url,
    this.color,
    this.ballSize = 280,
  });

  /// 当前页面的上下文。
  final ViewerPageContext pageCtx;

  /// 媒体 URL，用于自动取色和计算布局比例。
  final String? url;

  /// 背景球的主色调。若不传且 [url] 存在，则自动提取图片主题色。
  final Color? color;

  /// 背景球的尺寸基数。
  final double ballSize;

  @override
  State<ViewerDiffuseBackground> createState() =>
      _ViewerDiffuseBackgroundState();
}

class _ViewerDiffuseBackgroundState extends State<ViewerDiffuseBackground> {
  static final Map<String, _InternalImageData> _cache = {};
  _InternalImageData? _resolvedData;

  @override
  void initState() {
    super.initState();
    _handleData();
  }

  @override
  void didUpdateWidget(ViewerDiffuseBackground old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url || old.color != widget.color) {
      _resolvedData = null;
      _handleData();
    }
  }

  Future<void> _handleData() async {
    final url = widget.url;
    final manualColor = widget.color;

    // 如果通过色值直接指定
    if (manualColor != null) {
      Size size = Size.zero;
      if (url != null) {
        size = await _resolveImageSize(url);
      }
      if (mounted) {
        setState(() =>
            _resolvedData = _InternalImageData(color: manualColor, size: size));
      }
      return;
    }

    // 尝试从缓存或 URL 提取
    if (url != null) {
      if (_cache.containsKey(url)) {
        setState(() => _resolvedData = _cache[url]);
        return;
      }

      try {
        final provider = NetworkImage(url);

        // 1. 获取颜色
        final palette = await PaletteGenerator.fromImageProvider(
          provider,
          maximumColorCount: 10,
        );
        final color = palette.dominantColor?.color.withValues(alpha: 0.4) ??
            Colors.white.withValues(alpha: 0.2);

        // 2. 获取尺寸
        final size = await _resolveImageSize(url);

        final data = _InternalImageData(color: color, size: size);
        _cache[url] = data;
        if (mounted) setState(() => _resolvedData = data);
      } catch (_) {
        // Ignore
      }
    }
  }

  Future<Size> _resolveImageSize(String url) async {
    try {
      final completer = Completer<Size>();
      final provider = NetworkImage(url);
      final stream = provider.resolve(const ImageConfiguration());
      late ImageStreamListener listener;
      listener = ImageStreamListener((ImageInfo info, bool synchronousCall) {
        if (!completer.isCompleted) {
          completer.complete(Size(
            info.image.width.toDouble(),
            info.image.height.toDouble(),
          ));
        }
        stream.removeListener(listener);
      }, onError: (Object exception, StackTrace? stackTrace) {
        if (!completer.isCompleted) completer.complete(Size.zero);
        stream.removeListener(listener);
      });
      stream.addListener(listener);
      return await completer.future;
    } catch (_) {
      return Size.zero;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _resolvedData;
    if (data == null) return const SizedBox.shrink();

    final listenable = widget.pageCtx.mediaCardClipRadiusListenable;

    return ListenableBuilder(
      listenable: listenable ?? ValueNotifier(1.0),
      builder: (context, _) {
        final radius = listenable?.value ?? 0;
        // 显隐判断：工具栏显示 且 处于卡片状态（有圆角）
        final isVisible = widget.pageCtx.barsVisible && radius > 0.1;

        // 计算图片实际渲染区域（contain）
        final availableSize = widget.pageCtx.availableSize;
        final imgSize = data.size;

        Rect renderedRect =
            Rect.fromLTWH(0, 0, availableSize.width, availableSize.height);
        if (imgSize.width > 0 && imgSize.height > 0) {
          final contentW = availableSize.width;
          final contentH = availableSize.height;
          final imgRatio = imgSize.width / imgSize.height;
          final viewportRatio = contentW / contentH;

          double drawW, drawH;
          if (imgRatio > viewportRatio) {
            drawW = contentW;
            drawH = contentW / imgRatio;
          } else {
            drawH = contentH;
            drawW = contentH * imgRatio;
          }
          final dx = (contentW - drawW) / 2;
          final dy = (contentH - drawH) / 2;
          renderedRect = Rect.fromLTWH(dx, dy, drawW, drawH);
        }

        return AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          opacity: isVisible ? 1.0 : 0.0,
          child: Stack(
            children: [
              Positioned(
                left: renderedRect.left,
                top: renderedRect.top,
                width: renderedRect.width,
                height: renderedRect.height,
                child: IgnorePointer(
                  child: Stack(
                    children: [
                      ViewerDiffuseBall(
                        color: data.color,
                        alignment: const Alignment(-0.8, 0.7), // 左下
                        size: widget.ballSize,
                      ),
                      ViewerDiffuseBall(
                        color: data.color,
                        alignment: const Alignment(0.8, -0.7), // 右上
                        size: widget.ballSize,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 单个扩散毛玻璃圆环组件。
class ViewerDiffuseBall extends StatelessWidget {
  const ViewerDiffuseBall({
    super.key,
    required this.color,
    required this.alignment,
    required this.size,
    this.blurSigma = 60,
  });

  final Color color;
  final Alignment alignment;
  final double size;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

class _InternalImageData {
  const _InternalImageData({required this.color, required this.size});

  final Color color;
  final Size size;
}
