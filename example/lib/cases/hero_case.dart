import 'package:flutter/material.dart';
import 'package:yuni_photo_view/yuni_photo_view.dart';

import '../utils/demo_data.dart';

/// Case 6 — Hero 动画。
///
/// 演示：
/// - 从缩略图网格到浏览器的共享元素 Hero 动画。
/// - 使用 [ViewerHero] 代替原生 [Hero]，消除飞入/飞出闪烁：
///   • push 开始：shuttle 与缩略图外观完全一致（cover + 圆角 8px）。
///   • push 结束：shuttle 与 ViewerMediaCoverFrame 外观完全一致（contain + 无圆角）。
///   • pop 开始：与 viewer 外观一致；pop 结束：与缩略图一致。
///   • 拖拽返回松手触发 pop 前，已将 dismiss offset 归零，Hero 从正确坐标起飞。
class HeroCase extends StatelessWidget {
  const HeroCase({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hero 动画')),
      body: GridView.builder(
        padding: const EdgeInsets.all(6),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          childAspectRatio: 1,
        ),
        itemCount: DemoData.images.length,
        itemBuilder: (ctx, i) {
          final item = DemoData.images[i];
          return GestureDetector(
            onTap: () => _open(ctx, i),
            child: Hero(
              tag: 'hero_${item.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  item.payload as String,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const ColoredBox(color: Colors.grey),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _open(BuildContext context, int initialIndex) {
    MediaViewer.open(
      context,
      items: DemoData.images,
      initialIndex: initialIndex,
      config: const ViewerInteractionConfig(
        defaultShownExtent: 0.45,
      ),
      pageBuilder: (ctx, pageCtx) {
        final url = pageCtx.item.payload as String;

        // 使用 ViewerHero 代替原生 Hero。
        // thumbnailCornerRadius 与网格侧 ClipRRect radius 保持一致（均为 8）。
        return ViewerHero(
          tag: 'hero_${pageCtx.item.id}',
          imageUrl: url,
          thumbnailCornerRadius: 8,
          child: ViewerMediaCoverFrame(
            revealProgress: pageCtx.infoRevealProgress,
            child: Image.network(
              url,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => const SizedBox(
                width: 200,
                height: 200,
                child: Center(
                  child: Icon(
                    Icons.broken_image,
                    color: Colors.white54,
                    size: 64,
                  ),
                ),
              ),
            ),
          ),
        );
      },
      infoBuilder: (ctx, pageCtx) {
        final meta = pageCtx.item.meta ?? {};
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (meta['title'] != null)
                Text(
                  meta['title']!,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: 8),
              if (meta['date'] != null)
                Text(
                  meta['date']!,
                  style: const TextStyle(color: Colors.grey),
                ),
              if (meta['location'] != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.place_outlined,
                        size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        meta['location']!,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
      topBarBuilder: (ctx, barCtx) => SafeArea(
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ),
        ),
      ),
    );
  }
}
