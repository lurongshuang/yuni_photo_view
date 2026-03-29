import 'package:flutter/material.dart';
import 'package:yuni_photo_view/yuni_photo_view.dart';

import '../utils/demo_data.dart';

/// Case 5 — Fully custom top + bottom bars.
///
/// Demonstrates:
/// - Gradient top bar with share / favourite buttons.
/// - Filmstrip-style bottom bar with thumbnail row + current indicator.
/// - Bars fade (alpha only) with dismiss progress — no translation.
class FullCustomBarCase extends StatefulWidget {
  const FullCustomBarCase({super.key});

  @override
  State<FullCustomBarCase> createState() => _FullCustomBarCaseState();
}

class _FullCustomBarCaseState extends State<FullCustomBarCase> {
  final _controller = MediaViewerController();
  final Set<String> _favourites = {};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open(BuildContext context, int index) {
    MediaViewer.open(
      context,
      items: DemoData.images,
      initialIndex: index,
      controller: _controller,
      config: const ViewerInteractionConfig(
        defaultShownExtent: 0.48,
      ),
      pageBuilder: (ctx, pageCtx) => ViewerMediaCoverFrame(
        revealProgress: pageCtx.infoRevealProgress,
        child: Image.network(pageCtx.item.payload as String),
      ),
      infoBuilder: (ctx, pageCtx) {
        final meta = pageCtx.item.meta ?? {};
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text(meta['date'] ?? '-'),
            ),
            ListTile(
              leading: const Icon(Icons.place_outlined),
              title: Text(meta['location'] ?? '-'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text('${meta['device'] ?? '-'}  ·  ${meta['lens'] ?? '-'}'),
            ),
            ListTile(
              leading: const Icon(Icons.tune_outlined),
              title: Text(
                  '${meta['aperture'] ?? '-'}  ${meta['shutter'] ?? '-'}  ISO ${meta['iso'] ?? '-'}'),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
      topBarBuilder: (ctx, barCtx) => _GradientTopBar(
        index: barCtx.index,
        total: DemoData.images.length,
        isFavourite: _favourites.contains(barCtx.item.id),
        onClose: () => Navigator.of(ctx).pop(),
        onFavourite: () => setState(
          () => _favourites.contains(barCtx.item.id)
              ? _favourites.remove(barCtx.item.id)
              : _favourites.add(barCtx.item.id),
        ),
        onShare: () => ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('分享 (演示)')),
        ),
      ),
      bottomBarBuilder: (ctx, barCtx) => _FilmstripBar(
        items: DemoData.images,
        currentIndex: barCtx.index,
        onTap: (i) => _controller.jumpToPage(i),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('自定义顶/底栏')),
      body: GridView.builder(
        padding: const EdgeInsets.all(4),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemCount: DemoData.images.length,
        itemBuilder: (ctx, i) => GestureDetector(
          onTap: () => _open(ctx, i),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.network(
              DemoData.images[i].payload as String,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Gradient top bar ──────────────────────────────────────────────────────────

class _GradientTopBar extends StatelessWidget {
  const _GradientTopBar({
    required this.index,
    required this.total,
    required this.isFavourite,
    required this.onClose,
    required this.onFavourite,
    required this.onShare,
  });

  final int index;
  final int total;
  final bool isFavourite;
  final VoidCallback onClose;
  final VoidCallback onFavourite;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: onClose,
              ),
              Expanded(
                child: Text(
                  '$index / $total',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  isFavourite ? Icons.favorite : Icons.favorite_border,
                  color: isFavourite ? Colors.redAccent : Colors.white,
                ),
                onPressed: onFavourite,
              ),
              IconButton(
                icon: const Icon(Icons.ios_share, color: Colors.white),
                onPressed: onShare,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Filmstrip bottom bar ──────────────────────────────────────────────────────

class _FilmstripBar extends StatelessWidget {
  const _FilmstripBar({
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<ViewerItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            itemCount: items.length,
            itemBuilder: (ctx, i) {
              final selected = i == currentIndex;
              return GestureDetector(
                onTap: () => onTap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 52,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: selected ? Colors.white : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      items[i].payload as String,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
