import 'package:flutter/material.dart';
import 'package:yuni_photo_view/yuni_photo_view.dart';

import '../utils/demo_data.dart';

/// Case 4 — Mixed items: some have info, some do not.
///
/// Demonstrates:
/// - [ViewerItem.hasInfo] = false → info gesture disabled for that page.
/// - A badge on the thumbnail shows whether info is available.
/// - The last item (img_6) always has hasInfo=false; others have it.
class NoInfoCase extends StatelessWidget {
  const NoInfoCase({super.key});

  // Use the original list which includes a no-info item.
  List<ViewerItem> get _items => DemoData.images;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('无 Info 页面混合示例')),
      body: GridView.builder(
        padding: const EdgeInsets.all(4),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemCount: _items.length,
        itemBuilder: (ctx, i) {
          final item = _items[i];
          return GestureDetector(
            onTap: () => _open(ctx, i),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    item.payload as String,
                    fit: BoxFit.cover,
                  ),
                ),
                if (!item.hasInfo)
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'No Info',
                        style: TextStyle(color: Colors.white, fontSize: 9),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _open(BuildContext context, int initialIndex) {
    MediaViewer.open(
      context,
      items: _items,
      initialIndex: initialIndex,
      pageBuilder: (ctx, pageCtx) => Stack(
        fit: StackFit.expand,
        children: [
          ViewerMediaCoverFrame(
            revealProgress: pageCtx.infoRevealProgress,
            child: Image.network(pageCtx.item.payload as String),
          ),
          if (!pageCtx.item.hasInfo)
            const Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: 80),
                child: Chip(
                  label: Text('此项无 Info 信息'),
                  backgroundColor: Colors.black54,
                  labelStyle: TextStyle(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
      infoBuilder: (ctx, pageCtx) {
        // The framework already disables the info gesture when hasInfo=false.
        // This builder is only called for items where hasInfo=true.
        final meta = pageCtx.item.meta ?? {};
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (meta['title'] != null)
                Text(meta['title']!,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              if (meta['date'] != null) ...[
                const SizedBox(height: 8),
                Text(meta['date']!,
                    style: const TextStyle(color: Colors.grey)),
              ],
              if (meta['location'] != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.place_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(meta['location']!,
                          style: const TextStyle(color: Colors.grey)),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        );
      },
      topBarBuilder: (ctx, barCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
              const Spacer(),
              if (!barCtx.item.hasInfo)
                const Icon(Icons.info_outline,
                    color: Colors.white38, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
