import 'dart:ui' as ui;

import 'package:flutter/material.dart';

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
/// // pageBuilder 侧：用 ViewerHero 替换原生 Hero
/// pageBuilder: (ctx, pageCtx) => ViewerHero(
///   tag: 'photo_${pageCtx.item.id}',
///   imageProvider: NetworkImage(pageCtx.item.payload as String),
///   child: ViewerMediaCoverFrame(
///     revealProgress: pageCtx.infoRevealProgress,
///     child: Image.network(pageCtx.item.payload as String),
///   ),
/// )
/// ```
class ViewerHero extends StatelessWidget {
  const ViewerHero({
    required this.tag,
    required this.child,
    required this.imageProvider,
    this.thumbnailCornerRadius = 8.0,
    this.viewCornerRadius = 0.0,
    this.shuttleBuilder,
    super.key,
  });

  /// Hero 标签，与列表/网格侧的 Hero tag 保持一致。
  final Object tag;

  /// 查看页内正常展示的内容（多为 [ViewerMediaCoverFrame] 包一层图片）。
  final Widget child;

  /// 图片提供者。飞行期间直接从已有缓存读取，无需重新加载。
  final ImageProvider imageProvider;

  /// 与列表/网格侧 ClipRRect 圆角保持一致，默认 `8.0`。
  final double thumbnailCornerRadius;
  
  /// 到达查看区一端时的圆角，默认 `0.0`。
  /// 若设置了 [ViewerTheme.mediaCardBorderRadius]，建议传入该值以消除闪烁。
  final double viewCornerRadius;

  /// 完全自定义飞行画面（可选）。
  /// `animation.value`：push 0→1，pop 1→0。
  /// 约定 0 = 缩略图风格，1 = viewer 风格。
  final HeroFlightShuttleBuilder? shuttleBuilder;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      flightShuttleBuilder: shuttleBuilder ?? _defaultShuttleBuilder,
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

    return _HeroShuttleWidget(
      imageProvider: imageProvider,
      animation: animation,
      thumbnailCornerRadius: thumbnailCornerRadius,
      viewCornerRadius: viewCornerRadius,
      thumbSize: thumbSize,
      viewerSize: viewerSize,
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
  });

  final ImageProvider imageProvider;
  final Animation<double> animation;
  final double thumbnailCornerRadius;
  final double viewCornerRadius;

  /// 缩略图端的布局尺寸（用于计算 cover scale 锚点）。
  final Size thumbSize;

  /// 查看区一端的布局尺寸（用于计算 contain 缩放锚点）。
  final Size viewerSize;

  @override
  State<_HeroShuttleWidget> createState() => _HeroShuttleWidgetState();
}

class _HeroShuttleWidgetState extends State<_HeroShuttleWidget> {
  ui.Image? _image;
  ImageStream? _stream;
  ImageStreamListener? _asyncListener;

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
    final syncListener =
        ImageStreamListener((info, _) => syncImage = info.image);
    stream.addListener(syncListener);
    stream.removeListener(syncListener);

    if (syncImage != null) {
      _image = syncImage;
      return;
    }

    // 缓存未命中：异步等待（极少发生）
    _asyncListener = ImageStreamListener((info, _) {
      if (mounted) setState(() => _image = info.image);
    });
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
      builder: (_, __) {
        final t = widget.animation.value.clamp(0.0, 1.0);
        final radius = ui.lerpDouble(
          widget.thumbnailCornerRadius,
          widget.viewCornerRadius,
          t,
        )!;

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
              // 缓存未命中降级：contain 单层，无扩散
              : Image(
                  image: widget.imageProvider,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
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
