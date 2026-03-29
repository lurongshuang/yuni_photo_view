import 'package:flutter/material.dart';
import 'package:yuni_photo_view/yuni_photo_view.dart';

import '../utils/demo_data.dart';

/// Case 5 — 全自定义 top/bottom 栏 + Overlay，演示新上下文字段。
///
/// **测试维度**
/// 1. [ViewerBarContext.barsVisible]
///    • TopBar: 标题在全屏时变为半透明（内容变化，框架的 AnimatedOpacity 负责整体淡出）
///    • OverlayBuilder: bars 隐藏时右下角出现 "点击屏幕恢复" 提示，bars 显示时消失
///
/// 2. [ViewerBarContext.infoRevealProgress]  ← 实时连续值，随 info 上拉更新
///    • BottomBar（胶片条）随 info 上拉平滑淡出（progress 0→0.4 → opacity 1→0）
///    • TopBar 渐变蒙层高度随 info 上拉收缩（不遮住 info 面板上边缘）
///    • OverlayBuilder 中的页码角标随 info 上拉上移（跟 info 面板保持间距）
///
/// 3. [ViewerBarContext.dismissProgress]
///    • OverlayBuilder 中的调试状态条随 dismiss 拖动实时更新
///
/// 4. [ViewerBarContext.infoState] (enum 二值)
///    • TopBar 标题在 info shown 时显示相册名称（而不是图片标题）
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
      // 胶片条：随 infoRevealProgress 平滑淡出
      bottomBarBuilder: (ctx, barCtx) => _FilmstripBar(
        items: DemoData.images,
        currentIndex: barCtx.index,
        infoRevealProgress: barCtx.infoRevealProgress,
        onTap: (i) => _controller.jumpToPage(i),
      ),
      // Overlay：演示 barsVisible、infoRevealProgress、dismissProgress
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
// 演示维度：
//   • barsVisible      → 全屏时标题文字变为半透明（即将被框架淡出，内容先变化）
//   • infoRevealProgress → 渐变蒙层高度随 info 上拉从 100px 缩到 60px
//   • infoState        → info shown 时显示 "相册" 而非图片标题

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
    // 渐变高度随 info 上拉从 100 → 60 收缩（避免视觉上压盖 info 顶部内容）
    final gradientH = 100.0 - (barCtx.infoRevealProgress.clamp(0.0, 1.0) * 40);

    // 全屏时标题变半透明（提示用户 bars 将消失）
    final titleOpacity = barCtx.barsVisible ? 1.0 : 0.4;

    // info shown 时显示相册名而非图片标题
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
// 演示维度：
//   • infoRevealProgress → progress 0→0.4 时 opacity 1→0，info 显示后完全消失
//   框架的 AnimatedOpacity (barsVisible) 叠加在外层；
//   这里内部再做一层随 info 变化的淡出，两者相乘。

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
    // info 上拉 0→40% 时胶片条从完全可见到完全透明
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                          color:
                              selected ? Colors.white : Colors.transparent,
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

// ── 状态 Overlay ──────────────────────────────────────────────────────────────
//
// Overlay 不被框架的 AnimatedOpacity 包裹，需要自己管理可见性。
//
// 演示维度：
//   • barsVisible=false  → 右下角出现 "点击恢复" 提示（全屏提示）
//   • infoRevealProgress → 调试状态条平滑更新（实时连续值展示）
//   • dismissProgress    → dismiss 进度实时展示

class _StateOverlay extends StatelessWidget {
  const _StateOverlay({required this.barCtx});

  final ViewerBarContext barCtx;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── 全屏提示（barsVisible = false 时出现）────────────────────────
        AnimatedPositioned(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          right: 16,
          // bars 隐藏时提示从屏幕外滑入，否则滑到屏幕外
          bottom: barCtx.barsVisible ? -64 : 80,
          child: _FullscreenHint(
            visible: !barCtx.barsVisible,
          ),
        ),

        // ── 实时状态调试条（左下角，info 上拉时随之向上偏移）─────────────
        Positioned(
          left: 12,
          // 随 info 上拉同步上移，避免被 info 面板遮挡
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

// ── 全屏提示 Widget ───────────────────────────────────────────────────────────

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

// ── 实时状态调试角标 ───────────────────────────────────────────────────────────

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
            // info 进度 —— 彩色进度条
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
            // dismiss 进度
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
            // bars 可见 + infoState
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

// ── Info 面板 ─────────────────────────────────────────────────────────────────

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
