import 'package:flutter/material.dart';
import 'package:yuni_photo_view/yuni_photo_view.dart';

List<YuniMediaItem> generateItems(int count, YuniMediaType type) {
  return List.generate(
    count,
    (index) {
      double w = 800;
      double h = 1200;
      if (index % 3 == 0) {
        w = 1200; h = 800; // 横图
      } else if (index % 3 == 1) {
        w = 800; h = 2400; // 长图
      }
      return YuniMediaItemImpl(
        id: '${type.name}_$index',
        mediaType: type,
        url: 'https://picsum.photos/id/${index + 20}/${w.toInt()}/${h.toInt()}',
        thumbnailUrl: 'https://picsum.photos/id/${index + 20}/200/300',
        width: w,
        height: h,
      );
    },
  );
}

Widget buildGrid(BuildContext context, List<YuniMediaItem> items, String prefix, {bool minimal = false}) {
  return GridView.builder(
    padding: const EdgeInsets.all(8),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
    itemCount: items.length,
    itemBuilder: (context, index) {
      final item = items[index] as YuniMediaItemImpl;
      return YuniMediaHeroWrapper(
        heroTag: '$prefix${item.id}',
        onTap: () => openViewer(context, items, index, prefix, minimal: minimal),
        child: Container(
          color: Colors.grey[300],
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(item.thumbnailUrl!, fit: BoxFit.cover),
              if (item.mediaType == YuniMediaType.video)
                const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 40)),
            ],
          ),
        ),
      );
    },
  );
}

void openViewer(BuildContext context, List<YuniMediaItem> items, int index, String prefix, {bool minimal = false, double infoShowDamping = 0.2, double infoHideDamping = 0.5, double dismissDamping = 1.0}) {
  final controller = YuniMediaViewerController(initialIndex: index);
  YuniMediaViewer.show(
    context,
    items: items,
    controller: controller,
    heroTagPrefix: prefix,
    infoShowDamping: infoShowDamping,
    infoHideDamping: infoHideDamping,
    dismissDamping: dismissDamping,
    contentBuilder: (context, item) {
      if (item.mediaType == YuniMediaType.video) {
        return Container(
          color: Colors.black,
          child: const Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.movie, color: Colors.white, size: 80),
                    SizedBox(height: 20),
                    Text('模拟视频播放器内容', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      return Image.network((item as YuniMediaItemImpl).url!, fit: BoxFit.contain);
    },
    topOverlayBuilder: minimal ? null : (context, index) => SafeArea(
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
          const Spacer(),
          if (prefix != 'cus_')
            IconButton(icon: const Icon(Icons.share, color: Colors.white), onPressed: () {}),
        ],
      ),
    ),
    infoLayerBuilder: (minimal || prefix == 'vid_') ? null : (context, item, info) {
      final textColor = prefix == 'cus_' ? Colors.white : Colors.black;
      
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('2026年3月28日 星期六 · 01:05', style: TextStyle(fontSize: 16, color: textColor.withValues(alpha: 0.6))),
            const SizedBox(height: 8),
            Text('iPhone 16 Pro Max', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 16),
            const Divider(),
            _buildExifRow(Icons.camera_alt, '广角相机', '24mm f/1.78', textColor),
            _buildExifRow(Icons.photo_size_select_actual, '48MP', '8064 x 6048', textColor),
            _buildExifRow(Icons.info_outline, 'ISO 125', '1/100 s', textColor),
            const Divider(),
            const SizedBox(height: 16),
            Text('备忘录', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 8),
            Text(
              '这是一段非常长的详细元数据信息，用于测试长内容的滚动。在 1:1 分割的大图详情态下，你可以继续往上划动来阅读这些丰富的信息。' * 10,
              style: TextStyle(color: textColor.withValues(alpha: 0.8), height: 1.5),
            ),
            const SizedBox(height: 32),
            Container(
              height: 200,
              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
              child: const Center(child: Text('模拟地图位置')),
            ),
            const SizedBox(height: 80), // 底部留白
          ],
        ),
      );
    },
  );
}

Widget _buildExifRow(IconData icon, String title, String value, Color color) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Text(title, style: TextStyle(color: color.withValues(alpha: 0.7))),
        const Spacer(),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      ],
    ),
  );
}
