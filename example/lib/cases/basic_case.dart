import 'package:flutter/material.dart';
import 'package:yuni_photo_view/yuni_photo_view.dart';

import '../utils/demo_data.dart';

/// Case 1 — Basic usage.
///
/// - Grid of images as the entry point.
/// - Default info sheet with EXIF metadata.
/// - Simple top bar (back button + title).
class BasicCase extends StatelessWidget {
  const BasicCase({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('基础用法')),
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
      pageBuilder: _buildPage,
      infoBuilder: _buildInfo,
      topBarBuilder: _buildTopBar,
    );
  }

  Widget _buildPage(BuildContext context, ViewerPageContext pageCtx) {
    final url = pageCtx.item.payload as String;
    // ViewerMediaCoverFrame handles:
    //   • Short/landscape content → scale UP to cover the viewport (no gaps).
    //   • Tall/portrait content   → top-align and clip at bottom (no downscale).
    //   • Smooth alignment transition: centre → topCenter as info reveals.
    return ViewerMediaCoverFrame(
      revealProgress: pageCtx.infoRevealProgress,
      child: Image.network(
        url,
        // No explicit BoxFit — ViewerMediaCoverFrame owns the scale decision.
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return SizedBox(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            child: Center(
              child: CircularProgressIndicator(
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded /
                        progress.expectedTotalBytes!
                    : null,
                color: Colors.white,
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => const SizedBox(
          width: 200,
          height: 200,
          child: Center(
            child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
          ),
        ),
      ),
    );
  }

  Widget _buildInfo(BuildContext context, ViewerPageContext pageCtx) {
    final meta = pageCtx.item.meta ?? {};
    return _DefaultInfoPanel(meta: meta);
  }

  Widget _buildTopBar(BuildContext context, ViewerBarContext barCtx) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: Text(
                barCtx.item.meta?['title'] ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${barCtx.index + 1} / ${DemoData.images.length}',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared info panel ─────────────────────────────────────────────────────────

class _DefaultInfoPanel extends StatelessWidget {
  const _DefaultInfoPanel({required this.meta});

  final Map<String, dynamic> meta;

  @override
  Widget build(BuildContext context) {
    final rows = <_MetaRow>[
      if (meta['date'] != null) _MetaRow('日期', meta['date']!),
      if (meta['location'] != null) _MetaRow('位置', meta['location']!),
      if (meta['size'] != null) _MetaRow('大小', meta['size']!),
      if (meta['resolution'] != null) _MetaRow('分辨率', meta['resolution']!),
      if (meta['device'] != null) _MetaRow('设备', meta['device']!),
      if (meta['lens'] != null) _MetaRow('镜头', meta['lens']!),
      if (meta['aperture'] != null)
        _MetaRow(
          '拍摄参数',
          '${meta['aperture']}  ${meta['shutter']}  ISO ${meta['iso']}  ${meta['ev']}',
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (meta['title'] != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(
              meta['title']!,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        const Divider(height: 1),
        ...rows.map(
          (r) => _InfoRow(label: r.label, value: r.value),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _MetaRow {
  const _MetaRow(this.label, this.value);

  final String label;
  final String value;
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Grid thumbnail ─────────────────────────────────────────────────────────────

class _GridThumb extends StatelessWidget {
  const _GridThumb({required this.item, required this.onTap});

  final ViewerItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          item.payload as String,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const ColoredBox(color: Colors.grey),
        ),
      ),
    );
  }
}
