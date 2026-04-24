import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:yuni_photo_view/yuni_photo_view.dart';

import '../utils/demo_data.dart';

/// 案例：相册风格主内容区——栏全显且未缩放时有圆角与外边距；隐藏栏或放大后贴边。
///
/// 对应 [ViewerTheme.mediaCardInset] / [ViewerTheme.mediaCardBorderRadius]，
/// 由框架在 PhotoView 外侧包裹，边距不随双指缩放变形。
class MediaCardChromeCase extends StatelessWidget {
  const MediaCardChromeCase({super.key});

  static const _theme = ViewerTheme(
    mediaCardInsetTop: 10,
    mediaCardInsetBottom: 10,
    mediaCardInsetLeft: 14,
    mediaCardInsetRight: 14,
    mediaCardBorderRadius: 18,
    mediaCardAnimationDuration: Duration(milliseconds: 300),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('主内容卡片圆角'),
            Text(
              '异步从图片提取背景颜色与尺寸',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(4),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemCount: DemoData.images.length,
        itemBuilder: (ctx, i) => _GridThumb(
          item: DemoData.images[i],
          onTap: () => _open(ctx, i),
        ),
      ),
    );
  }

  void _open(BuildContext context, int initialIndex) {
    MediaViewer.open(
      context,
      items: DemoData.images,
      initialIndex: initialIndex,
      theme: _theme,
      pageBuilder: _buildPage,
      backgroundBuilder: _buildBackground,
      infoBuilder: _buildInfo,
      topBarBuilder: _buildTopBar,
      bottomBarBuilder: _buildBottomBar,
    );
  }

  Widget _buildBackground(BuildContext context, ViewerPageContext pageCtx) {
    final url = pageCtx.item.payload as String;
    final imageProvider = NetworkImage(url);

    return ViewerDiffuseBackground(
      pageCtx: pageCtx,
      // 【实际案例】：业务侧使用 palette_generator 异步获取图片主题色
      colorProvider: () async {
        final palette = await PaletteGenerator.fromImageProvider(
          imageProvider,
          maximumColorCount: 5,
        );
        // 选取主色调并设置 0.3 的不透明度，用于背景球
        return palette.dominantColor?.color.withValues(alpha: 0.3);
      },
      // 【实际案例】：业务侧异步解析图片原始物理尺寸
      // 传入尺寸后，ViewerDiffuseBackground 可以实现背景球与图片的精确边缘对齐（Contain 模式适配）
      sizeProvider: () async {
        final Completer<ui.Image> completer = Completer();
        final stream = imageProvider.resolve(ImageConfiguration.empty);
        stream.addListener(ImageStreamListener((info, _) {
          if (!completer.isCompleted) completer.complete(info.image);
        }));
        final image = await completer.future;
        return Size(image.width.toDouble(), image.height.toDouble());
      },
      ballSize: 300,
    );
  }

  Widget _buildPage(BuildContext context, ViewerPageContext pageCtx) {
    final url = pageCtx.item.payload as String;
    return ViewerHero.image(
      tag: 'hero_card_${pageCtx.item.id}',
      imageProvider: NetworkImage(url),
      thumbnailCornerRadius: 4,
      viewCornerRadius: 18,
      child: ViewerMediaCoverFrame(
        revealProgress: pageCtx.infoRevealProgress,
        child: Image.network(
          url,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          },
          errorBuilder: (_, __, ___) => const Icon(
            Icons.broken_image,
            color: Colors.white54,
            size: 64,
          ),
        ),
      ),
    );
  }

  Widget _buildInfo(BuildContext context, ViewerPageContext pageCtx) {
    final meta = pageCtx.item.meta ?? {};
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            meta['title']?.toString() ?? '详情',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '背景色是如何产生的？示例中通过 backgroundBuilder -> ViewerDiffuseBackground 的 colorProvider 回调，'
            '调用 palette_generator 异步提取了原图的主色调。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, ViewerBarContext barCtx) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: Text(
                barCtx.item.meta?['title'] ?? '预览',
                style: const TextStyle(color: Colors.white, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, ViewerBarContext barCtx) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${barCtx.index + 1} / ${barCtx.itemCount}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridThumb extends StatelessWidget {
  const _GridThumb({required this.item, required this.onTap});

  final ViewerItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Hero(
        tag: 'hero_card_${item.id}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.network(
            item.payload as String,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.grey),
          ),
        ),
      ),
    );
  }
}
