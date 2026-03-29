import 'package:flutter/material.dart';
import 'package:yuni_photo_view/yuni_photo_view.dart';

import '../utils/demo_data.dart';

/// 案例：桌面端自定义控件条（`desktopChromeBuilder`）。
///
/// - 使用 [ViewerDesktopUiMode.force] 在非 macOS 上也能看到桌面顶栏，便于调试 UI。
/// - 真实上架 macOS / Windows 时可改回 [ViewerDesktopUiMode.auto]。
/// - 本例不传 [topBarBuilder]，避免与桌面顶栏重复；业务按钮在 [desktopChromeBuilder] 内自由扩展。
class DesktopCustomChromeCase extends StatelessWidget {
  const DesktopCustomChromeCase({super.key});

  static const _desktopConfig = ViewerInteractionConfig(
    desktopUiMode: ViewerDesktopUiMode.force,
    enableTapToToggleBars: false,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('桌面自定义控件条')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '打开后顶部为「自定义」工具条：左侧返回/翻页，中间标题，'
              '右侧信息/缩放，以及一颗星形业务按钮（演示任意自定义操作）。',
              style: TextStyle(height: 1.4),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.desktop_windows_outlined),
              label: const Text('打开查看器（自定义 desktopChrome）'),
              onPressed: () => _open(context),
            ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    MediaViewer.open(
      context,
      items: DemoData.images,
      initialIndex: 0,
      config: _desktopConfig,
      pageBuilder: _buildPage,
      infoBuilder: _buildInfo,
      desktopChromeBuilder: _buildDesktopChrome,
    );
  }

  Widget _buildPage(BuildContext context, ViewerPageContext pageCtx) {
    final url = pageCtx.item.payload as String;
    return ViewerMediaCoverFrame(
      revealProgress: pageCtx.infoRevealProgress,
      child: Image.network(
        url,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: CircularProgressIndicator(color: Colors.white70),
          );
        },
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
        ),
      ),
    );
  }

  Widget _buildInfo(BuildContext context, ViewerPageContext pageCtx) {
    final meta = pageCtx.item.meta ?? {};
    return ListTile(
      title: Text(meta['title']?.toString() ?? pageCtx.item.id),
      subtitle: const Text('桌面案例 · 信息面板仍由 toggleInfo 控制'),
    );
  }

  /// 完全自定义顶栏：仍通过 [ViewerDesktopChromeContext] 调用框架能力。
  Widget _buildDesktopChrome(
    BuildContext context,
    ViewerDesktopChromeContext d,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final top = MediaQuery.paddingOf(context).top;

    return Align(
      alignment: Alignment.topCenter,
      child: Material(
        elevation: 2,
        color: scheme.primaryContainer.withValues(alpha: 0.95),
        child: Padding(
          padding: EdgeInsets.fromLTRB(8, top + 6, 8, 8),
          child: Row(
            children: [
              IconButton(
                tooltip: '返回',
                onPressed: d.closeViewer,
                icon: Icon(Icons.arrow_back_rounded,
                    color: scheme.onPrimaryContainer),
              ),
              IconButton(
                tooltip: '上一页',
                onPressed: d.canGoToPrevious ? d.goToPrevious : null,
                icon: Icon(Icons.chevron_left_rounded,
                    color: scheme.onPrimaryContainer),
              ),
              IconButton(
                tooltip: '下一页',
                onPressed: d.canGoToNext ? d.goToNext : null,
                icon: Icon(Icons.chevron_right_rounded,
                    color: scheme.onPrimaryContainer),
              ),
              Expanded(
                child: Text(
                  '自定义桌面栏 · ${d.currentIndex + 1} / ${d.itemCount}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (d.hasInfoPanel)
                IconButton(
                  tooltip: d.infoState == InfoState.shown ? '收起信息' : '信息',
                  onPressed: d.toggleInfo,
                  icon: Icon(
                    d.infoState == InfoState.shown
                        ? Icons.info_rounded
                        : Icons.info_outline_rounded,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              if (d.config.enableZoom) ...[
                IconButton(
                  tooltip: '缩小',
                  onPressed: d.canZoomOut ? d.zoomOut : null,
                  icon: Icon(Icons.zoom_out_rounded,
                      color: scheme.onPrimaryContainer),
                ),
                IconButton(
                  tooltip: '放大',
                  onPressed: d.canZoomIn ? d.zoomIn : null,
                  icon: Icon(Icons.zoom_in_rounded,
                      color: scheme.onPrimaryContainer),
                ),
              ],
              // —— 以下为「业务自定义」示例：与框架 API 无关，可换成分享/收藏/下载等 ——
              IconButton(
                tooltip: '业务按钮示例（收藏）',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('已触发业务逻辑：${d.currentItem.id}'),
                      behavior: SnackBarBehavior.floating,
                      width: 360,
                    ),
                  );
                },
                icon: Icon(Icons.star_rounded, color: scheme.tertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
