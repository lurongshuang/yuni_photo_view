import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/viewer_state.dart';

/// 一个带有两个扩散毛玻璃圆环的动态背景组件。
///
/// 常用作 [MediaViewer.backgroundBuilder] 的返回值。
///
/// 功能：
/// 1. **纯数据驱动**: 装饰球颜色完全由 [color] 或 [colorProvider] 决定，组件内部不再处理图片加载。
/// 2. **元数据对齐**: 通过 [imageSize] 或 [sizeProvider] 感知内容原始比例，使装饰球始终对齐到媒体的渲染边界。
/// 3. **性能优化**: 彻底剥离图片流解析，采用基于 `itemId` 的数据缓存，确保分页切换瞬间响应。
/// 4. **状态联动**: 联动 [ViewerPageContext.barsVisible] 和 [ViewerPageContext.mediaCardClipRadiusListenable]，
///    实现全屏沉浸模式下自动淡出。
class ViewerDiffuseBackground extends StatefulWidget {
  /// 基础构造函数：提供最高灵活性，支持同步与异步混合传入。
  const ViewerDiffuseBackground({
    super.key,
    required this.pageCtx,
    this.color,
    this.imageSize,
    this.colorProvider,
    this.sizeProvider,
    this.ballSize = 280,
    this.child,
  });

  /// 静态同步模式：适用于已知主色调和尺寸的场景（例如从列表页缓存中带入）。
  /// 能够实现首帧即达的渲染效果，无任何异步延迟。
  factory ViewerDiffuseBackground.static({
    Key? key,
    required ViewerPageContext pageCtx,
    required Color color,
    required Size imageSize,
    double ballSize = 280,
    Widget? child,
  }) =>
      ViewerDiffuseBackground(
        key: key,
        pageCtx: pageCtx,
        color: color,
        imageSize: imageSize,
        ballSize: ballSize,
        child: child,
      );

  /// 异步提供者模式：适用于需要动态计算（如实时 Palette 提取）的场景。
  /// 背景球将在数据计算完成后自动渐变显示。
  factory ViewerDiffuseBackground.async({
    Key? key,
    required ViewerPageContext pageCtx,
    required Future<Color?> Function() colorProvider,
    required Future<Size?> Function() sizeProvider,
    double ballSize = 280,
    Widget? child,
  }) =>
      ViewerDiffuseBackground(
        key: key,
        pageCtx: pageCtx,
        colorProvider: colorProvider,
        sizeProvider: sizeProvider,
        ballSize: ballSize,
        child: child,
      );

  /// 当前页面的上下文。
  final ViewerPageContext pageCtx;

  /// 背景球的主色调。
  final Color? color;

  /// 图片的原始尺寸。
  final Size? imageSize;

  /// 异步颜色提供者。
  final Future<Color?> Function()? colorProvider;

  /// 异步尺寸提供者。
  final Future<Size?> Function()? sizeProvider;

  /// 背景球的尺寸基数。
  final double ballSize;

  /// 子组件，用于获取实际渲染空间。
  final Widget? child;

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
    if (old.color != widget.color ||
        old.imageSize != widget.imageSize ||
        old.pageCtx.item.id != widget.pageCtx.item.id) {
      _resolvedData = null;
      _handleData();
    }
  }

  Future<void> _handleData() async {
    final itemId = widget.pageCtx.item.id;

    // 1. 尝试从缓存直接读取
    if (_cache.containsKey(itemId)) {
      if (mounted) setState(() => _resolvedData = _cache[itemId]);
      return;
    }

    // 2. 依次尝试各级数据源
    Color? finalColor = widget.color;
    Size? finalSize = widget.imageSize;

    // 2.1 尝试异步回调（如果同步值为空）
    if (finalColor == null && widget.colorProvider != null) {
      finalColor = await widget.colorProvider!();
    }
    if (finalSize == null && widget.sizeProvider != null) {
      finalSize = await widget.sizeProvider!();
    }

    // 3. 结果合并与兜底
    finalColor ??= Colors.white.withValues(alpha: 0.2);
    finalSize ??= Size.zero;

    final data = _InternalImageData(color: finalColor, size: finalSize);
    _cache[itemId] = data;

    if (mounted) {
      setState(() => _resolvedData = data);
    }
  }



  @override
  Widget build(BuildContext context) {
    final data = _resolvedData;
    if (data == null) {
      return widget.child ?? const SizedBox.shrink();
    }

    final listenable = widget.pageCtx.mediaCardClipRadiusListenable;

    return ListenableBuilder(
      listenable: listenable ?? ValueNotifier(1.0),
      builder: (context, _) {
        final radius = listenable?.value ?? 0;
        // 显隐判断：工具栏显示 且 处于卡片状态（有圆角）
        final isVisible = widget.pageCtx.barsVisible && radius > 0.1;

        // 如果有 child，使用简化的布局方式
        if (widget.child != null) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final availableSize = Size(
                constraints.maxWidth.isFinite ? constraints.maxWidth : widget.pageCtx.availableSize.width,
                constraints.maxHeight.isFinite ? constraints.maxHeight : widget.pageCtx.availableSize.height,
              );
              
              final imgSize = data.size;

              // 计算图片在 contain 模式下的实际渲染区域
              Rect renderedRect = Rect.fromLTWH(0, 0, availableSize.width, availableSize.height);
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

              return Stack(
                children: [
                  // child 层
                  Positioned.fill(
                    child: widget.child!,
                  ),
                  // 背景球层 - 在 child 之上，但使用 IgnorePointer
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    opacity: isVisible ? 1.0 : 0.0,
                    child: Positioned(
                      left: renderedRect.left,
                      top: renderedRect.top,
                      width: renderedRect.width,
                      height: renderedRect.height,
                      child: IgnorePointer(
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // 左下角的球
                            Positioned(
                              left: -widget.ballSize * 0.4,
                              bottom: -widget.ballSize * 0.4,
                              child: ViewerDiffuseBall(
                                color: data.color,
                                size: widget.ballSize,
                              ),
                            ),
                            // 右上角的球
                            Positioned(
                              right: -widget.ballSize * 0.4,
                              top: -widget.ballSize * 0.4,
                              child: ViewerDiffuseBall(
                                color: data.color,
                                size: widget.ballSize,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        }

        // 如果没有 child，使用原有逻辑
        return LayoutBuilder(
          builder: (context, constraints) {
            final availableSize = Size(
              constraints.maxWidth.isFinite ? constraints.maxWidth : widget.pageCtx.availableSize.width,
              constraints.maxHeight.isFinite ? constraints.maxHeight : widget.pageCtx.availableSize.height,
            );
            
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

            return Stack(
              children: [
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  opacity: isVisible ? 1.0 : 0.0,
                  child: Positioned(
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
                ),
              ],
            );
          },
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
    this.alignment,
    required this.size,
    this.blurSigma = 60,
  });

  final Color color;
  final Alignment? alignment;
  final double size;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final ball = ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.6),
        ),
      ),
    );

    // 如果提供了 alignment，使用 Align 包裹
    if (alignment != null) {
      return Align(
        alignment: alignment!,
        child: ball,
      );
    }

    // 否则直接返回球
    return ball;
  }
}

class _InternalImageData {
  const _InternalImageData({required this.color, required this.size});

  final Color color;
  final Size size;
}
