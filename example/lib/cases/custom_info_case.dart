import 'package:flutter/material.dart';
import 'package:yuni_photo_view/yuni_photo_view.dart';

import '../utils/demo_data.dart';

/// 案例 3：复杂自定义信息面板。
///
/// - 多区块布局（拍摄信息、参数芯片、地图占位等）。
/// - 内容较长时可把信息面板撑过半屏。
/// - 用 FutureBuilder 模拟异步拉取额外元数据。
class CustomInfoCase extends StatelessWidget {
  const CustomInfoCase({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('自定义 Info 面板')),
      body: ListView.builder(
        itemCount: DemoData.images.length,
        itemBuilder: (ctx, i) => ListTile(
          leading: SizedBox(
            width: 56,
            height: 56,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                DemoData.images[i].payload as String,
                fit: BoxFit.cover,
              ),
            ),
          ),
          title: Text(DemoData.images[i].meta?['title'] ?? 'Item $i'),
          subtitle: Text(DemoData.images[i].meta?['date'] ?? ''),
          onTap: () => _open(ctx, i),
        ),
      ),
    );
  }

  void _open(BuildContext context, int index) {
    MediaViewer.open(
      context,
      items: DemoData.images,
      initialIndex: index,
      config: const ViewerInteractionConfig(
        defaultShownExtent: 0.45,
      ),
      pageBuilder: (ctx, pageCtx) => ViewerMediaCoverFrame(
        revealProgress: pageCtx.infoRevealProgress,
        child: Image.network(pageCtx.item.payload as String),
      ),
      infoBuilder: (ctx, pageCtx) => _RichInfoPanel(item: pageCtx.item),
      topBarBuilder: (ctx, barCtx) => _TopBar(
        onClose: () => Navigator.of(ctx).pop(),
        title: barCtx.item.meta?['title'],
      ),
    );
  }
}

// ── 富内容信息面板 ───────────────────────────────────────────────────────────

class _RichInfoPanel extends StatefulWidget {
  const _RichInfoPanel({required this.item});

  final ViewerItem item;

  @override
  State<_RichInfoPanel> createState() => _RichInfoPanelState();
}

class _RichInfoPanelState extends State<_RichInfoPanel> {
  late Future<Map<String, dynamic>> _asyncMeta;

  @override
  void initState() {
    super.initState();
    _asyncMeta = _fetchExtraInfo(widget.item);
  }

  Future<Map<String, dynamic>> _fetchExtraInfo(ViewerItem item) async {
    // 模拟 600ms 异步请求（例如逆地理编码 + 云端元数据）。
    await Future.delayed(const Duration(milliseconds: 600));
    return {
      'album': '2026年3月 旅行',
      'tags': ['风景', '自然', '旅行'],
      'likes': 128,
      'views': 1024,
    };
  }

  @override
  Widget build(BuildContext context) {
    final meta = widget.item.meta ?? {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 基础拍摄信息 ─────────────────────────────────────────────────────
        _Section(
          title: '拍摄信息',
          child: Column(
            children: [
              _Row('日期', meta['date'] ?? '-'),
              _Row('位置', meta['location'] ?? '-'),
              _Row('设备', meta['device'] ?? '-'),
              _Row('镜头', meta['lens'] ?? '-'),
            ],
          ),
        ),

        // ── 拍摄参数（芯片展示）────────────────────────────────────────────
        _Section(
          title: '拍摄参数',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ParamChip(label: '光圈', value: meta['aperture'] ?? '-'),
                _ParamChip(label: '快门', value: meta['shutter'] ?? '-'),
                _ParamChip(label: 'ISO', value: meta['iso'] ?? '-'),
                _ParamChip(label: '曝光', value: meta['ev'] ?? '-'),
              ],
            ),
          ),
        ),

        // ── 地图占位（可替换为真实地图组件）────────────────────────────────
        _Section(
          title: '拍摄地点',
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 120,
                color: Colors.grey.shade300,
                child: const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map_outlined, color: Colors.grey),
                      SizedBox(width: 8),
                      Text('地图视图', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── 异步加载的扩展信息 ─────────────────────────────────────────────
        FutureBuilder<Map<String, dynamic>>(
          future: _asyncMeta,
          builder: (ctx, snap) {
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final extra = snap.data!;
            return _Section(
              title: '更多信息',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Row('相册', extra['album'] ?? '-'),
                  _Row('标签', (extra['tags'] as List).join('  ·  ')),
                  _Row('喜欢', '${extra['likes']}'),
                  _Row('浏览', '${extra['views']}'),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 40),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: Colors.grey),
          ),
        ),
        child,
        const Divider(height: 1, indent: 16),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}

class _ParamChip extends StatelessWidget {
  const _ParamChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onClose, this.title});

  final VoidCallback onClose;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black54, Colors.transparent],
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: onClose,
            ),
            if (title != null)
              Expanded(
                child: Text(
                  title!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
