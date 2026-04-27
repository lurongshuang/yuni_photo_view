import 'dart:ui' as ui;

import 'package:flutter/material.dart';

typedef ImageCustom = Widget Function(
    ImageProvider image, BoxFit fit, bool gaplessPlayback);

/// Hero 动画辅助组件，专为 [MediaViewer] 的 `pageBuilder` 设计。
///
/// ## 核心原理
///
/// 缩略图用 `BoxFit.cover`，viewer 用 `BoxFit.contain`。
/// 若 shuttle 全程按"当前边界"重新计算 cover/contain 矩形，
/// 宽图（landscape）会因 shuttle 从小正方形扩展到高竖向视口的过程中，
/// cover 矩形急剧增大，导致动画中间出现放大峰值（zoom 闪烁）。
///
/// **解决方案**：在飞行开始时，把两端的 scale 固定下来：
/// - `thumbCoverScale`  = 缩略图 cover scale（图片填满缩略图）
/// - `viewContainScale` = viewer contain scale（图片完整显示）
///
/// 飞行过程中只对 scale 做线性插值，图片始终居中。
/// scale 值是单调的，不会出现中间放大。
///
/// | 阶段 | 动画值 | 缩放 | 效果 |
/// |------|--------|------|------|
/// | 进入开始 | 0.0 | thumbCoverScale | 与缩略图 cover 一致 |
/// | 进入结束 | 1.0 | viewContainScale | 与查看区 contain 一致 |
/// | 返回开始 | 1.0 | viewContainScale | 与查看区一致 |
/// | 返回结束 | 0.0 | thumbCoverScale | 与缩略图 cover 一致 |
///
/// ## 用法
///
/// ```dart
/// // 网格/列表侧：保持原有 Hero
/// Hero(
///   tag: 'photo_${item.id}',
///   child: ClipRRect(
///     borderRadius: BorderRadius.circular(8),
///     child: Image.network(url, fit: BoxFit.cover),
///   ),
/// )
///
/// // pageBuilder 侧：图片内容使用 ViewerHero.image
/// pageBuilder: (ctx, pageCtx) => ViewerHero.image(
///   tag: 'photo_${pageCtx.item.id}',
///   imageProvider: NetworkImage(pageCtx.item.payload as String),
///   child: ViewerMediaCoverFrame(
///     revealProgress: pageCtx.infoRevealProgress,
///     child: Image.network(pageCtx.item.payload as String),
///   ),
/// )
///
/// // 非图片 widget：使用 ViewerHero.custom
/// ViewerHero.custom(
///   tag: 'card_${pageCtx.item.id}',
///   child: MyCustomVideoCard(item: pageCtx.item),
/// )
/// ```
class ViewerHero extends StatelessWidget {
  ViewerHero.image({
    required this.tag,
    required this.child,
    required ImageProvider this.imageProvider,
    this.thumbnailCornerRadius = 8.0,
    this.viewCornerRadius = 0.0,
    this.shuttleBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.imageCustom,
    super.key,
  }) {
    if (errorBuilder == null) {
      debugPrint('ViewerHero.image (tag: $tag) created with NULL errorBuilder!');
      // 打印前 5 行堆栈即可精确定位
      debugPrint(StackTrace.current.toString().split('\n').take(8).join('\n'));
    }
  }

  const ViewerHero.custom({
    required this.tag,
    required this.child,
    this.shuttleBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.imageCustom,
    super.key,
  })  : imageProvider = null,
        thumbnailCornerRadius = 8.0,
        viewCornerRadius = 0.0;

  /// Hero 标签，与列表/网格侧的 Hero tag 保持一致。
  final Object tag;

  /// 查看页内正常展示的内容（多为 [ViewerMediaCoverFrame] 包一层图片）。
  final Widget child;

  /// 图片提供者。
  ///
  /// 仅 [ViewerHero.image] 会提供该值，并启用图片专用 shuttle：
  /// 在缩略图 `cover` 与查看区 `contain` 之间做固定 scale 插值，减轻图片闪烁。
  ///
  /// [ViewerHero.custom] 下该值固定为 `null`，会退回 Flutter 原生 [Hero] 飞行逻辑，
  /// 或使用显式传入的 [shuttleBuilder]。
  final ImageProvider? imageProvider;

  /// 与列表/网格侧 ClipRRect 圆角保持一致，默认 `8.0`。
  final double thumbnailCornerRadius;

  /// 到达查看区一端时的圆角，默认 `0.0`。
  /// 若设置了 [ViewerTheme.mediaCardBorderRadius]，建议传入该值以消除闪烁。
  final double viewCornerRadius;

  /// 完全自定义飞行画面（可选）。
  /// `animation.value`：push 0→1，pop 1→0。
  /// 约定 0 = 缩略图风格，1 = viewer 风格。
  final HeroFlightShuttleBuilder? shuttleBuilder;

  /// A builder that specifies the widget to display to the user while an image
  /// is still loading.
  ///
  /// If this is null, and the image is loaded incrementally (e.g. over a
  /// network), the user will receive no indication of the progress as the
  /// bytes of the image are loaded.
  ///
  /// For more information on how to interpret the arguments that are passed to
  /// this builder, see the documentation on [ImageLoadingBuilder].
  ///
  /// ## Performance implications
  ///
  /// If a [loadingBuilder] is specified for an image, the [Image] widget is
  /// likely to be rebuilt on every
  /// [rendering pipeline frame](rendering/RendererBinding/drawFrame.html) until
  /// the image has loaded. This is useful for cases such as displaying a loading
  /// progress indicator, but for simpler cases such as displaying a placeholder
  /// widget that doesn't depend on the loading progress (e.g. static "loading"
  /// text), [frameBuilder] will likely work and not incur as much cost.
  ///
  /// ## Chaining with [frameBuilder]
  ///
  /// If a [frameBuilder] has _also_ been specified for an image, the two
  /// builders will be chained together: the `child` argument to this
  /// builder will contain the _result_ of the [frameBuilder]. For example,
  /// consider the following builders used in conjunction:
  ///
  /// {@macro flutter.widgets.Image.frameBuilder.chainedBuildersExample}
  ///
  /// {@tool dartpad}
  /// The following sample uses [loadingBuilder] to show a
  /// [CircularProgressIndicator] while an image loads over the network.
  ///
  /// ** See code in examples/api/lib/widgets/image/image.loading_builder.0.dart **
  /// {@end-tool}
  ///
  /// Run against a real-world image on a slow network, the previous example
  /// renders the following loading progress indicator while the image loads
  /// before rendering the completed image.
  ///
  /// {@animation 400 400 https://flutter.github.io/assets-for-api-docs/assets/widgets/loading_progress_image.mp4}
  final ImageLoadingBuilder? loadingBuilder;

  /// A builder function that is called if an error occurs during image loading.
  ///
  /// If this builder is not provided, any exceptions will be reported to
  /// [FlutterError.onError]. If it is provided, the caller should either handle
  /// the exception by providing a replacement widget, or rethrow the exception.
  ///
  /// {@tool dartpad}
  /// The following sample uses [errorBuilder] to show a '😢' in place of the
  /// image that fails to load, and prints the error to the console.
  ///
  /// ** See code in examples/api/lib/widgets/image/image.error_builder.0.dart **
  /// {@end-tool}
  final ImageErrorWidgetBuilder? errorBuilder;

  ///自定义图片展示
  final ImageCustom? imageCustom;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      flightShuttleBuilder: shuttleBuilder ??
          (imageProvider != null ? _defaultShuttleBuilder : null),
      child: child,
    );
  }

  Widget _defaultShuttleBuilder(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection flightDirection,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    // 获取两端 Hero 的实际布局尺寸，用于计算固定的 scale 锚点。
    final fromBox = fromHeroContext.findRenderObject() as RenderBox?;
    final toBox = toHeroContext.findRenderObject() as RenderBox?;
    final fromSize = fromBox?.size ?? Size.zero;
    final toSize = toBox?.size ?? Size.zero;

    // 根据飞行方向区分缩略图端和 viewer 端：
    //   push: from = 缩略图, to = viewer
    //   pop:  from = viewer,  to = 缩略图
    final Size thumbSize;
    final Size viewerSize;
    if (flightDirection == HeroFlightDirection.push) {
      thumbSize = fromSize;
      viewerSize = toSize;
    } else {
      thumbSize = toSize;
      viewerSize = fromSize;
    }

    debugPrint('ViewerHero: _defaultShuttleBuilder called. errorBuilder is null: ${errorBuilder == null}');
    return _HeroShuttleWidget(
      imageProvider: imageProvider!,
      animation: animation,
      thumbnailCornerRadius: thumbnailCornerRadius,
      viewCornerRadius: viewCornerRadius,
      thumbSize: thumbSize,
      viewerSize: viewerSize,
      errorBuilder: errorBuilder,
      loadingBuilder: loadingBuilder,
      imageCustom: imageCustom,
    );
  }
}

// ── shuttle 主体 ──────────────────────────────────────────────────────────────

class _HeroShuttleWidget extends StatefulWidget {
  const _HeroShuttleWidget({
    required this.imageProvider,
    required this.animation,
    required this.thumbnailCornerRadius,
    required this.viewCornerRadius,
    required this.thumbSize,
    required this.viewerSize,
    this.errorBuilder,
    this.loadingBuilder,
    this.imageCustom,
  });

  final ImageProvider imageProvider;
  final Animation<double> animation;
  final double thumbnailCornerRadius;
  final double viewCornerRadius;

  /// 缩略图端的布局尺寸（用于计算 cover scale 锚点）。
  final Size thumbSize;

  /// 查看区一端的布局尺寸（用于计算 contain 缩放锚点）。
  final Size viewerSize;

  final ImageLoadingBuilder? loadingBuilder;

  final ImageErrorWidgetBuilder? errorBuilder;

  final ImageCustom? imageCustom;

  @override
  State<_HeroShuttleWidget> createState() => _HeroShuttleWidgetState();
}

class _HeroShuttleWidgetState extends State<_HeroShuttleWidget> {
  ui.Image? _image;
  ImageStream? _stream;
  ImageStreamListener? _asyncListener;
  Object? _error;
  StackTrace? _stackTrace;

  @override
  void initState() {
    super.initState();
    _resolveImage();
  }

  /// 优先从缓存同步获取 [ui.Image]；缓存未命中时异步等待。
  ///
  /// 实践中图片已在列表页和 viewer 中展示过，缓存命中率接近 100%，
  /// 同步路径通常在第一帧就能拿到图片，不会有白帧。
  void _resolveImage() {
    final provider = widget.imageProvider;
    final stream = provider.resolve(const ImageConfiguration());
    _stream = stream;

    // 尝试同步获取（ImageStreamCompleter 已完成时会同步回调）
    ui.Image? syncImage;
    Object? syncError;
    StackTrace? syncStack;

    final syncListener = ImageStreamListener(
      (info, _) => syncImage = info.image,
      onError: (exception, stackTrace) {
        syncError = exception;
        syncStack = stackTrace;
      },
    );
    stream.addListener(syncListener);
    stream.removeListener(syncListener);

    if (syncImage != null) {
      _image = syncImage;
      return;
    }

    if (syncError != null) {
      _error = syncError;
      _stackTrace = syncStack;
      return;
    }

    // 缓存未命中：异步等待（极少发生）
    _asyncListener = ImageStreamListener(
      (info, _) {
        if (mounted) {
          setState(() {
            _image = info.image;
            _error = null;
          });
        }
      },
      onError: (exception, stackTrace) {
        // 显式捕获错误并更新状态，确保即使 Image 组件被重建，状态也能保留
        if (mounted) {
          setState(() {
            _error = exception;
            _stackTrace = stackTrace;
          });
        }
      },
    );
    stream.addListener(_asyncListener!);
  }

  @override
  void dispose() {
    if (_asyncListener != null) _stream?.removeListener(_asyncListener!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, __) {
        final t = widget.animation.value.clamp(0.0, 1.0);
        final radius = ui.lerpDouble(
          widget.thumbnailCornerRadius,
          widget.viewCornerRadius,
          t,
        )!;

        // 如果捕获到错误
        if (_error != null) {
          if (widget.errorBuilder != null) {
            return widget.errorBuilder!(context, _error!, _stackTrace);
          }
          // 兜底：如果手动解析捕获到错误但没传 errorBuilder，防止显示原始错误文本
          return const Center(
            child: Icon(Icons.broken_image_outlined, color: Colors.white24, size: 40),
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: _image != null
              ? CustomPaint(
                  painter: _ScaleInterpolationPainter(
                    image: _image!,
                    t: t,
                    radius: radius,
                    thumbSize: widget.thumbSize,
                    viewerSize: widget.viewerSize,
                  ),
                  child: const SizedBox.expand(),
                )
              // 缓存未命中降级：使用 Key 保持 Image 状态，避免在 AnimatedBuilder 中因重建而导致异步回调丢失
              : (widget.imageCustom != null
                  ? widget.imageCustom
                      ?.call(widget.imageProvider, BoxFit.contain, true)
                  : Image(
                      key: ValueKey(widget.imageProvider),
                      image: widget.imageProvider,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      loadingBuilder: widget.loadingBuilder,
                      errorBuilder: widget.errorBuilder ?? (context, error, stackTrace) {
                        // 兜底：如果 Image 组件报错且没传 errorBuilder，防止显示原始错误文本
                        return const Center(
                          child: Icon(Icons.broken_image_outlined, color: Colors.white24, size: 40),
                        );
                      },
                    )),
        );
      },
    );
  }
}

// ── 自定义 Painter：固定 scale 锚点 + 线性插值 ───────────────────────────────

/// 通过固定两端 scale 做线性插值，避免宽图在动画中途出现放大峰值。
///
/// **为什么按当前 shuttle 尺寸重新计算 cover 会出问题：**
/// 宽图（landscape）在 shuttle 从小正方形扩展到高竖向视口时，
/// cover scale 由"按宽缩放"切换到"按高缩放"，scale 值急剧增大，
/// lerp 结果在中间帧出现放大峰值（zoom 效果）。
///
/// **本方案：**
/// 在飞行开始时锁定两端 scale：
/// - `thumbCoverScale`  = 缩略图 cover scale
/// - `viewContainScale` = viewer contain scale
/// 飞行中只对 scale 线性插值，scale 单调变化，不会出现中间放大。
class _ScaleInterpolationPainter extends CustomPainter {
  const _ScaleInterpolationPainter({
    required this.image,
    required this.t,
    required this.radius,
    required this.thumbSize,
    required this.viewerSize,
  });

  final ui.Image image;

  /// 0 = 缩略图端（cover），1 = viewer 端（contain）。
  /// push: 0→1；pop: 1→0。
  final double t;

  /// 当前圆角半径。
  final double radius;

  final Size thumbSize;
  final Size viewerSize;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final imgW = image.width.toDouble();
    final imgH = image.height.toDouble();
    if (imgW <= 0 || imgH <= 0) return;

    // 缩略图端：cover scale（图片填满缩略图，可裁切）
    final thumbCoverScale = _coverScale(thumbSize, imgW, imgH);

    // viewer 端：contain scale（图片完整显示，可有留白）
    final viewContainScale = _containScale(viewerSize, imgW, imgH);

    // 线性插值 scale，单调无峰值
    final scale = ui.lerpDouble(thumbCoverScale, viewContainScale, t)!;

    final drawW = imgW * scale;
    final drawH = imgH * scale;

    // 始终居中
    final dx = (size.width - drawW) / 2.0;
    final dy = (size.height - drawH) / 2.0;

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    // 计算当前图片绘制矩形并应用圆角裁剪：
    // 这能确保在 contain 模式下，圆角跟随图片边缘而非视口。
    if (radius > 0.5) {
      final imgRect = Rect.fromLTWH(dx, dy, drawW, drawH);
      canvas.clipRRect(RRect.fromRectAndRadius(
        imgRect,
        Radius.circular(radius),
      ));
    }

    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, imgW, imgH),
      Rect.fromLTWH(dx, dy, drawW, drawH),
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.restore();
  }

  /// cover：取 max(scaleX, scaleY)，图片填满 bounds（超出部分裁切）。
  static double _coverScale(Size bounds, double imgW, double imgH) {
    if (bounds.isEmpty) return 1.0;
    final sx = bounds.width / imgW;
    final sy = bounds.height / imgH;
    return sx > sy ? sx : sy;
  }

  /// contain：取 min(scaleX, scaleY)，图片完整显示（可有留白）。
  static double _containScale(Size bounds, double imgW, double imgH) {
    if (bounds.isEmpty) return 1.0;
    final sx = bounds.width / imgW;
    final sy = bounds.height / imgH;
    return sx < sy ? sx : sy;
  }

  @override
  bool shouldRepaint(_ScaleInterpolationPainter old) =>
      old.image != image ||
      old.t != t ||
      old.radius != radius ||
      old.thumbSize != thumbSize ||
      old.viewerSize != viewerSize;
}
