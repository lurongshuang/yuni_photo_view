import 'package:flutter/material.dart';
import 'package:yuni_photo_view/yuni_photo_view.dart';

import '../utils/demo_data.dart';

/// 案例 5：全自定义顶栏、底栏与全屏 Overlay，演示 [ViewerBarContext] 各字段。
///
/// 测试要点：
/// 1. [ViewerBarContext.barsVisible]：顶栏标题在全屏时略变淡；Overlay 在栏隐藏时提示「点击屏幕恢复」。
/// 2. [ViewerBarContext.infoRevealProgress]：底栏胶片条随上拉淡出；顶栏渐变高度收缩；Overlay 调试条位置上移。
/// 3. [ViewerBarContext.dismissProgress]：Overlay 中展示下拉关闭进度。
/// 4. [ViewerBarContext.infoState]：信息展开时顶栏标题切换为相册名（与单图标题区分）。
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
        return _InfoPanel(meta: meta);
      },
      topBarBuilder: (ctx, barCtx) => _AdaptiveTopBar(
        barCtx: barCtx,
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
      // 底栏胶片条：随信息面板上拉进度淡出。
      bottomBarBuilder: (ctx, barCtx) => _FilmstripBar(
        items: DemoData.images,
        currentIndex: barCtx.index,
        infoRevealProgress: barCtx.infoRevealProgress,
        onTap: (i) => _controller.jumpToPage(i),
      ),
      // 全屏 Overlay：演示栏可见性、信息展开进度、下拉关闭进度。
      overlayBuilder: (ctx, barCtx) => _StateOverlay(barCtx: barCtx),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('全自定义栏 + 状态感知')),
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

// ── 自适应顶栏 ─────────────────────────────────────────────────────────────────
//
// 说明：barsVisible 控制标题浓淡；infoRevealProgress 控制渐变条高度；
// infoState 为已展开时标题改为相册文案。

class _AdaptiveTopBar extends StatelessWidget {
  const _AdaptiveTopBar({
    required this.barCtx,
    required this.total,
    required this.isFavourite,
    required this.onClose,
    required this.onFavourite,
    required this.onShare,
  });

  final ViewerBarContext barCtx;
  final int total;
  final bool isFavourite;
  final VoidCallback onClose;
  final VoidCallback onFavourite;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    // 渐变条高度随信息面板上拉从 100 收到 60，减轻压住面板顶部内容的观感。
    final gradientH = 100.0 - (barCtx.infoRevealProgress.clamp(0.0, 1.0) * 40);

    // 全屏隐藏栏时标题先变淡（与框架淡出栏呼应）。
    final titleOpacity = barCtx.barsVisible ? 1.0 : 0.4;

    // 信息已展开时显示相册名，而非当前图标题。
    final title = barCtx.infoState == InfoState.shown
        ? '2026年3月 旅行'
        : (barCtx.item.meta?['title'] ?? '');

    return Container(
      height: gradientH,
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
                onPressed: onClose,
              ),
              Expanded(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: titleOpacity,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              // 页码角标
              Text(
                '${barCtx.index + 1} / $total',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
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

// ── 胶片条底栏 ─────────────────────────────────────────────────────────────────
//
// 说明：上拉进度约 0→0.4 时胶片条从不透明到透明；外层还有框架随顶底栏可见性变化的透明度动画，二者相乘。

class _FilmstripBar extends StatelessWidget {
  const _FilmstripBar({
    required this.items,
    required this.currentIndex,
    required this.infoRevealProgress,
    required this.onTap,
  });

  final List<ViewerItem> items;
  final int currentIndex;
  final double infoRevealProgress;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    // 信息面板上拉进度约 0～40% 时，胶片条由完全不透明过渡到全透明。
    final opacity = (1.0 - infoRevealProgress / 0.4).clamp(0.0, 1.0);

    return Opacity(
      opacity: opacity,
      child: IgnorePointer(
        // 透明时不接受触摸，防止误触
        ignoring: opacity < 0.05,
        child: Container(
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
        ),
      ),
    );
  }
}

// ── 全屏状态浮层 ─────────────────────────────────────────────────────────────
//
// 本层不受框架对顶底栏的 AnimatedOpacity 控制，显隐需自行实现。
//
// 演示：栏隐藏时右下角提示；左下角调试条随信息进度与下拉关闭进度更新。

class _StateOverlay extends StatelessWidget {
  const _StateOverlay({required this.barCtx});

  final ViewerBarContext barCtx;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 全屏时（顶底栏隐藏）显示的恢复提示。
        AnimatedPositioned(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          right: 16,
          // 栏隐藏时提示移入可视区；栏显示时移到屏外。
          bottom: barCtx.barsVisible ? -64 : 80,
          child: _FullscreenHint(
            visible: !barCtx.barsVisible,
          ),
        ),

        // 左下角调试条：随信息面板上移以免被遮挡。
        Positioned(
          left: 12,
          // 与信息面板高度联动上移。
          bottom: 12 +
              MediaQuery.of(context).size.height *
                  0.48 *
                  barCtx.infoRevealProgress.clamp(0.0, 1.0),
          child: _DebugStatusBadge(barCtx: barCtx),
        ),
      ],
    );
  }
}

// ── 全屏提示组件 ─────────────────────────────────────────────────────────────

class _FullscreenHint extends StatelessWidget {
  const _FullscreenHint({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: visible ? 1.0 : 0.0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app_outlined, color: Colors.white70, size: 14),
            SizedBox(width: 6),
            Text(
              '点击屏幕恢复',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 实时状态调试角标 ─────────────────────────────────────────────────────────

class _DebugStatusBadge extends StatelessWidget {
  const _DebugStatusBadge({required this.barCtx});

  final ViewerBarContext barCtx;

  @override
  Widget build(BuildContext context) {
    final infoP = (barCtx.infoRevealProgress * 100).round();
    final dimP = (barCtx.dismissProgress * 100).round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white70, fontSize: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 信息面板上拉进度（示意条）
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('info  '),
                _MiniBar(
                  value: barCtx.infoRevealProgress.clamp(0.0, 1.0),
                  color: Colors.tealAccent,
                ),
                Text('  $infoP%'),
              ],
            ),
            const SizedBox(height: 3),
            // 下拉关闭进度
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('dimis '),
                _MiniBar(
                  value: barCtx.dismissProgress,
                  color: Colors.orangeAccent,
                ),
                Text('  $dimP%'),
              ],
            ),
            const SizedBox(height: 3),
            // 顶底栏是否可见 + 信息展开枚举状态
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  barCtx.barsVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 10,
                  color: Colors.white54,
                ),
                const SizedBox(width: 4),
                Text(barCtx.infoState == InfoState.shown
                    ? 'info: shown'
                    : 'info: hidden'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  const _MiniBar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: value,
          backgroundColor: Colors.white12,
          valueColor: AlwaysStoppedAnimation(color),
          minHeight: 4,
        ),
      ),
    );
  }
}

// ── 信息面板内容 ─────────────────────────────────────────────────────────────

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.meta});

  final Map<String, dynamic> meta;

  @override
  Widget build(BuildContext context) {
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
  }
}
