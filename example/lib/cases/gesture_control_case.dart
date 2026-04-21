import 'package:flutter/material.dart';
import 'package:yuni_photo_view/yuni_photo_view.dart';

import '../utils/demo_data.dart';

/// 演示 enableGestureScaling 功能的示例。
///
/// 展示如何为不同的ViewerItem启用或禁用手势缩放功能。
class GestureControlCase extends StatelessWidget {
  const GestureControlCase({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('手势缩放控制')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.75,
        ),
        itemCount: _items.length,
        itemBuilder: (ctx, i) {
          final item = _items[i] as DefaultViewerItem;
          final gestureEnabled = item.enableGestureScaling;
          
          return GestureDetector(
            onTap: () => _open(ctx, i),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: gestureEnabled ? Colors.green : Colors.red,
                  width: 3,
                ),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(9),
                      ),
                      child: Image.network(
                        item.payload as String,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: gestureEnabled 
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(9),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          gestureEnabled 
                              ? Icons.zoom_in 
                              : Icons.block,
                          color: gestureEnabled ? Colors.green : Colors.red,
                          size: 32,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          gestureEnabled ? '可缩放' : '禁止缩放',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: gestureEnabled ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _open(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MediaViewer(
          items: _items,
          initialIndex: initialIndex,
          pageBuilder: (ctx, pageCtx) {
            final item = pageCtx.item as DefaultViewerItem;
            return ViewerMediaCoverFrame(
              revealProgress: pageCtx.infoRevealProgress,
              child: Image.network(
                item.payload as String,
                fit: BoxFit.contain,
              ),
            );
          },
          pageOverlayBuilder: (ctx, pageCtx) {
            final item = pageCtx.item as DefaultViewerItem;
            return Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 60),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: item.enableGestureScaling
                        ? Colors.green.withOpacity(0.8)
                        : Colors.red.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.enableGestureScaling
                            ? Icons.zoom_in
                            : Icons.block,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.enableGestureScaling
                            ? '双指捏合可缩放'
                            : '缩放已禁用',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          infoBuilder: (ctx, barCtx) {
            final item = barCtx.item as DefaultViewerItem;
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '图片 ${barCtx.index + 1}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        item.enableGestureScaling
                            ? Icons.zoom_in
                            : Icons.block,
                        color: item.enableGestureScaling
                            ? Colors.green
                            : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.enableGestureScaling
                            ? '手势缩放：已启用'
                            : '手势缩放：已禁用',
                        style: TextStyle(
                          fontSize: 16,
                          color: item.enableGestureScaling
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    item.enableGestureScaling
                        ? '你可以使用双指捏合手势来放大或缩小这张图片。'
                        : '这张图片禁用了手势缩放功能，无法通过双指捏合来放大或缩小。',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// 示例数据：混合了启用和禁用手势缩放的图片
  static final List<ViewerItem> _items = [
    // 启用手势缩放（默认）
    DefaultViewerItem(
      id: '1',
      payload: DemoData.images[0].payload,
      enableGestureScaling: true,
    ),
    // 禁用手势缩放
    DefaultViewerItem(
      id: '2',
      payload: DemoData.images[1].payload,
      enableGestureScaling: false,
    ),
    // 启用手势缩放
    DefaultViewerItem(
      id: '3',
      payload: DemoData.images[2].payload,
      enableGestureScaling: true,
    ),
    // 禁用手势缩放
    DefaultViewerItem(
      id: '4',
      payload: DemoData.images[3].payload,
      enableGestureScaling: false,
    ),
    // 启用手势缩放（显式指定）
    DefaultViewerItem(
      id: '5',
      payload: DemoData.images[4].payload,
      enableGestureScaling: true,
    ),
    // 禁用手势缩放
    DefaultViewerItem(
      id: '6',
      payload: DemoData.images[5].payload,
      enableGestureScaling: false,
    ),
  ];
}
