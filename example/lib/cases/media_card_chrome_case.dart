import 'package:flutter/material.dart';
import 'package:yuni_photo_view/yuni_photo_view.dart';

import '../utils/demo_data.dart';

/// 案例：相册风格主内容区——栏全显且未缩放时有圆角与外边距；隐藏栏或放大后贴边。
///
/// 对应 [ViewerTheme.mediaCardInset] / [ViewerTheme.mediaCardBorderRadius]，
/// 由框架在 PhotoView 外侧包裹，边距不随双指缩放变形。
class MediaCardChromeCase extends StatelessWidget {
  const MediaCardChromeCase({super.key});

  static const _theme = ViewerTheme(
    mediaCardInset: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
              '单击切栏；缩放后外框贴边，还原后恢复圆角',
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
    return ViewerDiffuseBackground(
      url: pageCtx.item.payload as String,
      pageCtx: pageCtx,
    );
  }

  Widget _buildPage(BuildContext context, ViewerPageContext pageCtx) {
    final url = pageCtx.item.payload as String;
    return ViewerHero(
      tag: 'hero_card_${pageCtx.item.id}',
      imageUrl: url,
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
    // 使用 Column：info 区已在壳内 SingleChildScrollView 中，勿再嵌套未 shrinkWrap 的 ListView。
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
            '上滑查看元数据。顶底栏都显示时主图带圆角与边距；点按内容隐藏栏或放大图片后外框会贴齐视口。',
            style: Theme.of(context).textTheme.bodyMedium,
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
            if (barCtx.isZoomed)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Text(
                  '已放大',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
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
