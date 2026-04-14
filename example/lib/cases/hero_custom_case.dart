import 'package:flutter/material.dart';
import 'package:yuni_photo_view/yuni_photo_view.dart';

class HeroCustomCase extends StatelessWidget {
  const HeroCustomCase({super.key});

  static final List<DefaultViewerItem> _items = List.generate(6, (index) {
    return DefaultViewerItem(
      id: 'custom_$index',
      payload: null,
      meta: {
        'title': _titles[index],
        'subtitle': _subtitles[index],
      },
      extra: _swatches[index],
    );
  });

  static const List<String> _titles = [
    '旅行卡片',
    '视频卡片',
    '活动卡片',
    '书签卡片',
    '播客卡片',
    '灵感卡片',
  ];

  static const List<String> _subtitles = [
    '任意 widget 都可以参与 Hero',
    '不再被 imageProvider 限制',
    '适合卡片、封面、组件块',
    '保留 Flutter 原生 Hero 飞行逻辑',
    '也可以继续自定义 shuttle',
    'Viewer 端照样走 pageBuilder',
  ];

  static const List<Color> _swatches = [
    Color(0xFF1D3557),
    Color(0xFF8D5524),
    Color(0xFF264653),
    Color(0xFF6A4C93),
    Color(0xFF005F73),
    Color(0xFF9C6644),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hero 自定义 Widget')),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.8,
        ),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          return GestureDetector(
            onTap: () => _open(context, index),
            child: Hero(
              tag: 'custom_hero_${item.id}',
              child: _DemoCard(
                title: item.meta?['title'] as String? ?? '卡片',
                subtitle: item.meta?['subtitle'] as String? ?? '',
                color: item.extra! as Color,
                compact: true,
              ),
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
      pageBuilder: (ctx, pageCtx) {
        final item = pageCtx.item as DefaultViewerItem;
        return Center(
          child: ViewerHero.custom(
            tag: 'custom_hero_${pageCtx.item.id}',
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _DemoCard(
                  title: item.meta?['title'] as String? ?? '卡片',
                  subtitle: item.meta?['subtitle'] as String? ?? '',
                  color: item.extra! as Color,
                ),
              ),
            ),
          ),
        );
      },
      infoBuilder: (ctx, pageCtx) => const Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 36),
        child: Text(
          '这个案例演示的是 ViewerHero.custom(...)。'
          ' 缩略图和查看页都是普通自定义 widget，没有 imageProvider，'
          ' Hero 会退回 Flutter 原生共享元素飞行逻辑。',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
      ),
      topBarBuilder: (ctx, barCtx) => SafeArea(
        child: Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ),
      ),
    );
  }
}

class _DemoCard extends StatelessWidget {
  const _DemoCard({
    required this.title,
    required this.subtitle,
    required this.color,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final radius = compact ? 18.0 : 28.0;
    final padding = compact ? 16.0 : 24.0;
    final iconSize = compact ? 44.0 : 64.0;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.95),
              color.withValues(alpha: 0.62),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: compact ? 18 : 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(compact ? 14 : 18),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: compact ? 24 : 34,
                ),
              ),
              const Spacer(),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 18 : 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: compact ? 12 : 15,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
