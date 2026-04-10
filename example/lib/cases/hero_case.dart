import 'package:flutter/material.dart';
import 'package:yuni_photo_view/yuni_photo_view.dart';

import '../utils/demo_data.dart';

/// 案例 6：Hero 共享元素动画。
///
/// - 列表缩略图与查看页使用相同 `tag`，配合 [ViewerHero] 做过渡。
/// - [ViewerHero] 默认 shuttle 在缩略图 cover+圆角 与查看区 contain 之间插值，减轻闪烁与比例跳变。
/// - 下拉关闭时 Hero 从当前拖动位置衔接回程（勿在 pop 前强行把位移清零）。
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

        // 使用 ViewerHero 替代原生 Hero，减轻 cover/contain 切换时的闪烁。
        // thumbnailCornerRadius 必须与列表缩略图的 ClipRRect 圆角一致（本例为 8）。
        return ViewerHero(
          tag: 'hero_${pageCtx.item.id}',
          imageProvider: NetworkImage(url),
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
