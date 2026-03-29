import 'package:flutter/material.dart';
import 'package:yuni_photo_view/yuni_photo_view.dart';

import '../utils/demo_data.dart';

/// Case 8 — Mirrored info sync mode.
///
/// Demonstrates:
/// - [InfoSyncMode.mirrored]: when one page's info is opened, all pages
///   remember the shown state. Swiping to another page keeps info open.
/// - Toggle between perPage and mirrored to compare.
///
/// Note: in this release the controller's infoState reflects the current page.
/// The mirrored sync is implemented by the business by listening to the
/// controller's state and calling showInfo/hideInfo on page change.
/// A future framework release will natively enforce mirrored behaviour.
class MirroredInfoCase extends StatefulWidget {
  const MirroredInfoCase({super.key});

  @override
  State<MirroredInfoCase> createState() => _MirroredInfoCaseState();
}

class _MirroredInfoCaseState extends State<MirroredInfoCase> {
  InfoSyncMode _syncMode = InfoSyncMode.perPage;
  final _controller = MediaViewerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open(BuildContext context) {
    MediaViewer.open(
      context,
      items: DemoData.images.where((e) => e.hasInfo).toList(),
      controller: _controller,
      config: ViewerInteractionConfig(
        infoSyncMode: _syncMode,
        defaultShownExtent: 0.42,
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
              leading: const Icon(Icons.image_outlined),
              title: Text(meta['title'] ?? ''),
              subtitle: Text(meta['date'] ?? ''),
            ),
            ListTile(
              leading: const Icon(Icons.place_outlined),
              title: Text(meta['location'] ?? ''),
            ),
            ListTile(
              leading: const Icon(Icons.camera),
              title: Text(
                  '${meta['device'] ?? '-'}  ·  ${meta['lens'] ?? '-'}'),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Text(
                'Info 同步模式: ${_syncMode.name}',
                style: TextStyle(
                  color: Colors.deepPurple.shade300,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
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
              Chip(
                backgroundColor: Colors.deepPurple,
                label: Text(
                  _syncMode == InfoSyncMode.perPage ? 'perPage' : 'mirrored',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
      onPageChanged: (index) {
        // When mirrored mode is active, show info on every page that info was
        // already open on. The business drives this via the controller.
        if (_syncMode == InfoSyncMode.mirrored &&
            _controller.currentInfoState == InfoState.shown) {
          _controller.showInfo();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Info 镜像同步')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
            child: Text('Info 同步模式',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          _SyncModeOption(
            label: 'perPage（每页独立记忆）',
            subtitle: '翻页时 info 状态各自独立，默认模式',
            selected: _syncMode == InfoSyncMode.perPage,
            onTap: () => setState(() => _syncMode = InfoSyncMode.perPage),
          ),
          _SyncModeOption(
            label: 'mirrored（镜像同步）',
            subtitle: '任意页展开 info 后，翻页保持展开',
            selected: _syncMode == InfoSyncMode.mirrored,
            onTap: () => setState(() => _syncMode = InfoSyncMode.mirrored),
          ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.icon(
              icon: const Icon(Icons.open_in_full),
              label: const Text('打开查看器'),
              onPressed: () => _open(context),
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('提示', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text(
                      '1. 向上滑动打开 info 面板\n'
                      '2. 左右翻页查看不同模式下 info 状态的变化\n'
                      '3. perPage 模式下每页状态独立\n'
                      '4. mirrored 模式下翻页后 info 保持展开',
                      style: TextStyle(color: Colors.grey, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncModeOption extends StatelessWidget {
  const _SyncModeOption({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? Theme.of(context).colorScheme.primary : Colors.grey,
      ),
      title: Text(label),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}
