import 'package:flutter/material.dart';

import '../core/viewer_desktop_chrome.dart';
import '../core/viewer_state.dart';

/// 桌面模式下的默认控件区：**顶部工具条**
/// （左：返回、翻页；右：信息、缩放）。
///
/// 需要别的布局或按钮时，请使用 [MediaViewer.desktopChromeBuilder] 自行构建，
/// [ViewerDesktopChromeContext] 中已提供 [ViewerDesktopChromeContext.closeViewer]、
/// [ViewerDesktopChromeContext.goToPrevious] 等全部操作回调。
class DefaultViewerDesktopChrome extends StatelessWidget {
  const DefaultViewerDesktopChrome({super.key, required this.desktopCtx});

  final ViewerDesktopChromeContext desktopCtx;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final topInset = MediaQuery.paddingOf(context).top;

    return Stack(
      fit: StackFit.expand,
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.96),
              border: Border(
                bottom: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(10, topInset + 6, 10, 8),
              child: Row(
                children: [
                  _CircleToolButton(
                    scheme: scheme,
                    icon: Icons.arrow_back_rounded,
                    tooltip: '返回',
                    onPressed: desktopCtx.closeViewer,
                  ),
                  const SizedBox(width: 6),
                  _CircleToolButton(
                    scheme: scheme,
                    icon: Icons.chevron_left_rounded,
                    tooltip: '上一页',
                    onPressed: desktopCtx.canGoToPrevious
                        ? desktopCtx.goToPrevious
                        : null,
                  ),
                  const SizedBox(width: 6),
                  _CircleToolButton(
                    scheme: scheme,
                    icon: Icons.chevron_right_rounded,
                    tooltip: '下一页',
                    onPressed:
                        desktopCtx.canGoToNext ? desktopCtx.goToNext : null,
                  ),
                  const Spacer(),
                  if (desktopCtx.hasInfoPanel) ...[
                    _CircleToolButton(
                      scheme: scheme,
                      icon: desktopCtx.infoState == InfoState.shown
                          ? Icons.info_rounded
                          : Icons.info_outline_rounded,
                      tooltip: desktopCtx.infoState == InfoState.shown
                          ? '收起信息'
                          : '信息',
                      onPressed: desktopCtx.toggleInfo,
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (desktopCtx.config.enableZoom) ...[
                    _CircleToolButton(
                      scheme: scheme,
                      icon: Icons.zoom_out_rounded,
                      tooltip: '缩小',
                      onPressed:
                          desktopCtx.canZoomOut ? desktopCtx.zoomOut : null,
                    ),
                    const SizedBox(width: 6),
                    _CircleToolButton(
                      scheme: scheme,
                      icon: Icons.zoom_in_rounded,
                      tooltip: '放大',
                      onPressed:
                          desktopCtx.canZoomIn ? desktopCtx.zoomIn : null,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CircleToolButton extends StatelessWidget {
  const _CircleToolButton({
    required this.scheme,
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final ColorScheme scheme;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.9),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              icon,
              size: 22,
              color: enabled
                  ? scheme.onSurface
                  : scheme.onSurface.withValues(alpha: 0.35),
            ),
          ),
        ),
      ),
    );
  }
}
