import 'package:flutter/material.dart';
import 'package:yuni_photo_view/yuni_photo_view.dart';

import '../utils/demo_data.dart';

/// 案例 2：最简集成。
///
/// 只传 [pageBuilder]，无 Info、无顶底栏；展示最小接入方式。
class MinimalCase extends StatelessWidget {
  const MinimalCase({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('最简集成')),
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('打开查看器（无 info / 无操作栏）'),
          onPressed: () => _open(context),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    MediaViewer.open(
      context,
      items: DemoData.images,
      // 仅 pageBuilder 必填，其余参数均可省略。
      pageBuilder: (ctx, pageCtx) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              pageCtx.item.payload as String,
              fit: BoxFit.contain,
              alignment: Alignment.center,
              errorBuilder: (_, __, ___) => const Center(
                child:
                    Icon(Icons.broken_image, color: Colors.white54, size: 64),
              ),
            ),
            // 返回按钮放在页面内容里即可，不必使用 topBarBuilder。
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
