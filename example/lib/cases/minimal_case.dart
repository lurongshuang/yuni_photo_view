import 'package:flutter/material.dart';
import 'package:yuni_photo_view/yuni_photo_view.dart';

import '../utils/demo_data.dart';

/// Case 2 — Minimal integration.
///
/// Only [pageBuilder] is provided. No info, no bars.
/// Demonstrates the absolute minimum API surface.
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
      // Only a pageBuilder — everything else is optional.
      pageBuilder: (ctx, pageCtx) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              pageCtx.item.payload as String,
              fit: BoxFit.contain,
              alignment: Alignment.center,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
              ),
            ),
            // Minimal back button — no topBarBuilder needed.
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
