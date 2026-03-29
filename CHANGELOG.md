# Changelog

## 0.2.0

- **Breaking:** `ViewerItem` 改为抽象类；通用数据请使用 `DefaultViewerItem`，或自行 `extends ViewerItem`。
- 桌面端：`ViewerDesktopUiMode`、`desktopChromeBuilder`、`DefaultViewerDesktopChrome`、程序化缩放与快捷键。
- `ViewerInteractionConfig.resolveForShell()`、`ViewerBarContext.usesDesktopUi`。
- 缩放：程序化放大锚定视口中心（全局坐标修正）。
- 示例：`example` 含综合案例、桌面自定义顶栏、macOS 网络 entitlement 等。

## 0.1.0

- 初始公开版本：全屏 `MediaViewer`、分页、`PhotoView` 缩放、上滑信息面板、顶底栏与 overlay 槽位、`MediaViewerController`、`ViewerHero` / `ViewerMediaCoverFrame` 辅助组件。
