import 'package:flutter/material.dart';
import 'package:yuni_photo_view/yuni_photo_view.dart';
import '../utils/demo_data.dart';

/// 扩展性专题案例：展示如何使用 underMediaBuilder、自定义动效参数和业务数据透传。
class ExtensibilityCase extends StatelessWidget {
  const ExtensibilityCase({super.key});

  @override
  Widget build(BuildContext context) {
    // 构造带 extra 业务负载的数据
    final List<ViewerItem> items = DemoData.images.map((item) {
      final defaultItem = item as DefaultViewerItem;
      return defaultItem.copyWith(
        extra: {
          'isVIP': item.id.contains('1') || item.id.contains('3'),
          'customShadowColor': item.id.contains('2') ? Colors.redAccent : Colors.black,
        },
      );
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('扩展性专题：插槽与动效')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _openViewer(context, items),
          child: const Text('打开极度自定义查看器'),
        ),
      ),
    );
  }

  void _openViewer(BuildContext context, List<ViewerItem> items) {
    MediaViewer.open(
      context,
      items: items,
      // 1. 动效参数魔改：极致缓慢的缩放（方便观察原理）
      theme: const ViewerTheme(
        zoomDuration: Duration(milliseconds: 1500),
        zoomCurve: Curves.elasticOut,
        barsToggleDuration: Duration(milliseconds: 600),
        barsToggleCurve: Curves.bounceOut,
      ),
      // 2. 交互判定阈值魔改：纵向滑动判定极大（几乎锁死非核心方向）
      config: const ViewerInteractionConfig(
        verticalDragMinStartDistance: 60.0, 
      ),
      pageBuilder: (ctx, pageCtx) {
        return Center(
          child: Hero(
            tag: pageCtx.item.id,
            child: Image.network(
              pageCtx.item.payload as String,
              fit: BoxFit.contain,
            ),
          ),
        );
      },
      // 3. 多层布局插槽：在媒体下方增加“立体投影层”
      underMediaBuilder: (ctx, pageCtx) {
        final extra = pageCtx.extra as Map<String, dynamic>?;
        final shadowColor = (extra?['customShadowColor'] as Color?) ?? Colors.black;
        
        return Center(
          child: Container(
            width: 300,
            height: 400,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: shadowColor.withValues(alpha: 0.8),
                  blurRadius: 100,
                  spreadRadius: 20,
                  offset: const Offset(30, 30),
                ),
              ],
            ),
          ),
        );
      },
      // 4. 业务数据透传：根据 extra 渲染水印
      pageOverlayBuilder: (ctx, pageCtx) {
        final extra = pageCtx.extra as Map<String, dynamic>?;
        final isVIP = extra?['isVIP'] == true;

        if (!isVIP) return null;

        return Positioned(
          right: 20,
          top: 100,
          child: Transform.rotate(
            angle: 0.5,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.amber, width: 2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'VIP EXCLUSIVE',
                style: TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
