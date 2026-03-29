import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:yuni_photo_view/yuni_photo_view.dart';

import '../utils/demo_data.dart';

/// 综合案例：用插件现有能力拼出接近相册应用的交互（不进行 Live Photo 文件解析）。
///
/// Live 样式：仅用 [ViewerItem.meta] 约定字段，[pageOverlayBuilder] 画角标与按钮；视频地址由业务配置。
/// 播放：长按封面，或点叠加层按钮，或点底栏按钮；播放 meta 里的 `motionUrl`，结束后恢复静态图。
/// 顶栏、底栏、[overlayBuilder] 为自定义；放大时 [ViewerBarContext.isZoomed] 为真则收合底栏。
/// 上滑信息：[infoBuilder] 内「查看原图」为模拟下载，完成后改用高清 URL（业务可自行替换为本地文件）。
/// 角标透明度：使用 [ViewerPageContext.barsVisible] 与 [ViewerPageContext.dismissProgress]。
class ComprehensiveCase extends StatelessWidget {
  const ComprehensiveCase({super.key});

  void _openViewer(BuildContext context, int index) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _ComprehensiveViewerShell(initialIndex: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = DemoData.comprehensiveItems;
    return Scaffold(
      appBar: AppBar(title: const Text('综合案例（Live / 原图 / 多栏）')),
      body: GridView.builder(
        padding: const EdgeInsets.all(4),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemCount: items.length,
        itemBuilder: (ctx, i) {
          final item = items[i];
          final isLive = item.meta?['livePhoto'] == true;
          return GestureDetector(
            onTap: () => _openViewer(ctx, i),
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
                if (isLive)
                  Positioned(
                    left: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.motion_photos_on,
                            color: Colors.white,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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
}

// ── 全屏浏览：状态必须挂在独立 Route 的 State 上 ─────────────────────────────

class _ComprehensiveViewerShell extends StatefulWidget {
  const _ComprehensiveViewerShell({required this.initialIndex});

  final int initialIndex;

  @override
  State<_ComprehensiveViewerShell> createState() =>
      _ComprehensiveViewerShellState();
}

class _ComprehensiveViewerShellState extends State<_ComprehensiveViewerShell> {
  final List<ViewerItem> _items = DemoData.comprehensiveItems;
  final MediaViewerController _viewerController = MediaViewerController();

  VideoPlayerController? _videoCtrl;
  String? _playingItemId;

  final Set<String> _originalReady = {};
  final Set<String> _originalDownloading = {};

  @override
  void dispose() {
    _videoCtrl?.removeListener(_onVideoTick);
    _videoCtrl?.dispose();
    _viewerController.dispose();
    super.dispose();
  }

  bool _isLivePhoto(ViewerItem item) => item.meta?['livePhoto'] == true;

  String? _motionUrl(ViewerItem item) => item.meta?['motionUrl'] as String?;

  bool _hasOriginalSlot(ViewerItem item) => item.meta?['hasOriginal'] == true;

  String _displayImageUrl(ViewerItem item) {
    final meta = item.meta;
    if (meta == null) return item.payload as String;
    if (_originalReady.contains(item.id) && meta['hdUrl'] != null) {
      return meta['hdUrl'] as String;
    }
    return (meta['previewUrl'] as String?) ?? item.payload as String;
  }

  Future<void> _startLivePlayback(String itemId, String url) async {
    await _stopLivePlayback();
    final c = VideoPlayerController.networkUrl(Uri.parse(url));
    setState(() {
      _playingItemId = itemId;
      _videoCtrl = c;
    });
    try {
      await c.initialize();
      c.addListener(_onVideoTick);
      await c.play();
    } catch (_) {
      await _stopLivePlayback();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法播放演示视频（网络或格式）')),
        );
      }
    }
    if (mounted) setState(() {});
  }

  void _onVideoTick() {
    final c = _videoCtrl;
    if (c == null || !c.value.isInitialized) return;
    final d = c.value.duration;
    if (d == Duration.zero) return;
    if (c.value.position >= d - const Duration(milliseconds: 100)) {
      _stopLivePlayback();
    }
  }

  Future<void> _stopLivePlayback() async {
    _videoCtrl?.removeListener(_onVideoTick);
    await _videoCtrl?.dispose();
    _videoCtrl = null;
    _playingItemId = null;
    if (mounted) setState(() {});
  }

  Future<void> _mockDownloadOriginal(String itemId) async {
    if (_originalDownloading.contains(itemId) ||
        _originalReady.contains(itemId)) {
      return;
    }
    setState(() => _originalDownloading.add(itemId));
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;
    setState(() {
      _originalDownloading.remove(itemId);
      _originalReady.add(itemId);
    });
  }

  @override
  Widget build(BuildContext context) {
    // 与 MediaViewer.open 相同：外包 Theme + 透明 Material，满足 ListTile、按钮等
    // 对祖先的要求，避免文字样式/墨水异常或调试下误判的「黄线」。
    final theme = Theme.of(context);
    return Theme(
      data: theme,
      child: Material(
        type: MaterialType.transparency,
        child: MediaViewer(
          items: _items,
          initialIndex: widget.initialIndex.clamp(0, _items.length - 1),
          controller: _viewerController,
          config: const ViewerInteractionConfig(
            defaultShownExtent: 0.5,
          ),
          onPageChanged: (_) {
            // 翻页时停止 Live 播放，避免后台占用解码器
            if (_playingItemId != null) {
              _stopLivePlayback();
            }
          },
          pageBuilder: (ctx, pageCtx) {
            final item = pageCtx.item;
            final motion = _motionUrl(item);

            if (_playingItemId == item.id) {
              final c = _videoCtrl;
              if (c == null || !c.value.isInitialized) {
                return ViewerMediaCoverFrame(
                  revealProgress: pageCtx.infoRevealProgress,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white70),
                  ),
                );
              }
              return ViewerMediaCoverFrame(
                revealProgress: pageCtx.infoRevealProgress,
                child: Center(
                  child: AspectRatio(
                    aspectRatio:
                        c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
                    child: VideoPlayer(c),
                  ),
                ),
              );
            }

            final url = _displayImageUrl(item);
            return ViewerMediaCoverFrame(
              revealProgress: pageCtx.infoRevealProgress,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onLongPress: _isLivePhoto(item) && motion != null
                    ? () => _startLivePlayback(item.id, motion)
                    : null,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image,
                        color: Colors.white54, size: 64),
                  ),
                ),
              ),
            );
          },
          pageOverlayBuilder: (ctx, pageCtx) {
            if (!_isLivePhoto(pageCtx.item)) return null;
            final motion = _motionUrl(pageCtx.item);
            if (motion == null) return null;

            final badgeOpacity = ((pageCtx.barsVisible ? 1.0 : 0.72) *
                    (1.0 - pageCtx.dismissProgress * 0.55))
                .clamp(0.15, 1.0);

            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Align(
                alignment: Alignment.topLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Opacity(
                      opacity: badgeOpacity,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.motion_photos_on,
                                color: Colors.white,
                                size: 18,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.black45,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        textStyle: const TextStyle(
                          decoration: TextDecoration.none,
                        ),
                      ),
                      onPressed: () =>
                          _startLivePlayback(pageCtx.item.id, motion),
                      icon: const Icon(Icons.play_circle_outline, size: 20),
                      label: const Text('播放实况'),
                    ),
                  ],
                ),
              ),
            );
          },
          infoBuilder: (ctx, pageCtx) {
            final meta = pageCtx.item.meta ?? {};
            final canOriginal = _hasOriginalSlot(pageCtx.item);
            final id = pageCtx.item.id;
            final ready = _originalReady.contains(id);
            final loading = _originalDownloading.contains(id);

            return ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                ListTile(
                  leading: const Icon(Icons.title),
                  title: Text(
                    meta['title']?.toString() ?? pageCtx.item.id,
                    style: const TextStyle(decoration: TextDecoration.none),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: Text(
                    meta['date']?.toString() ?? '-',
                    style: const TextStyle(decoration: TextDecoration.none),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: Text(
                    meta['location']?.toString() ?? '-',
                    style: const TextStyle(decoration: TextDecoration.none),
                  ),
                ),
                if (canOriginal)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            textStyle: const TextStyle(
                              decoration: TextDecoration.none,
                            ),
                          ),
                          onPressed: ready || loading
                              ? null
                              : () => _mockDownloadOriginal(id),
                          icon: loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(ready
                                  ? Icons.check_circle
                                  : Icons.hd_outlined),
                          label: Text(
                            ready
                                ? '已加载原图'
                                : loading
                                    ? '正在加载原图…'
                                    : '查看原图（模拟下载）',
                            style: const TextStyle(
                                decoration: TextDecoration.none),
                          ),
                        ),
                        if (ready)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              '已切换到 meta.hdUrl 展示（业务可换成本地文件）',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.black54),
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            );
          },
          topBarBuilder: (ctx, barCtx) {
            final title = barCtx.item.meta?['title'] ?? barCtx.item.id;
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$title',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (barCtx.isZoomed)
                              const Text(
                                '双指缩放中 — 底栏已简化',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 11),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        '${barCtx.index + 1}/${_items.length}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          bottomBarBuilder: (ctx, barCtx) {
            final item = barCtx.item;
            final live = _isLivePhoto(item);
            final motion = _motionUrl(item);

            if (barCtx.isZoomed) {
              return const SizedBox.shrink();
            }

            return Container(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    if (live && motion != null)
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white24,
                        ),
                        onPressed: () => _startLivePlayback(item.id, motion),
                        child: const Row(
                          children: [
                            Icon(Icons.motion_photos_on, size: 20),
                            SizedBox(width: 8),
                            Text('播放 Live'),
                          ],
                        ),
                      ),
                    if (live && motion != null) const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '上滑信息 · 单击隐藏栏 · 双指缩放',
                        textAlign: TextAlign.end,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          decoration: TextDecoration.none,
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          overlayBuilder: (ctx, barCtx) {
            if (_playingItemId == null) return const SizedBox.shrink();

            return Stack(
              children: [
                Positioned(
                  top: MediaQuery.paddingOf(ctx).top + 56,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Text(
                          '实况播放中 · 结束后自动回到静态封面',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                ),
                // 信息面板展开时略抬高提示条，避免与面板重叠。
                Positioned(
                  bottom: 12 +
                      MediaQuery.sizeOf(ctx).height *
                          0.5 *
                          barCtx.infoRevealProgress.clamp(0.0, 1.0),
                  left: 12,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      child: Text(
                        'bars: ${barCtx.barsVisible} · zoom: ${barCtx.isZoomed}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
