# yuni_photo_view

[![pub package](https://img.shields.io/pub/v/yuni_photo_view.svg)](https://pub.dev/packages/yuni_photo_view)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**YuniPhotoView** 是一套 Flutter **全屏媒体查看壳层**：基于 **PageView** 的分页、**PhotoView** 双指/双击缩放、底部 **上滑信息面板**、**下拉关闭**，以及可选的 **顶栏 / 底栏 / 全局浮层** 槽位；在桌面端还可启用 **工具条**（上一页/下一页、缩放、信息、返回）与快捷键。

**本包不绘制你的图片或视频**。URL、`video_player`、解码与布局均由业务在 `pageBuilder`、`infoBuilder` 等回调中完成。

---

## 能力一览

| 模块 | 说明 |
|------|------|
| **分页** | `PageView`，放大时可禁止横滑；桌面端可默认改为仅按钮翻页。 |
| **缩放** | 集成 `PhotoView.customChild`；支持 `ViewerPageController` / `MediaViewerController` **程序化放大/缩小/还原**。 |
| **信息面板** | 底部面板，拖动吸附；触屏上滑或桌面按钮展开。 |
| **关闭** | 下拉跟手关闭（可关），与 `Navigator.pop`、`onDismiss` 一致。 |
| **操作栏** | `topBarBuilder`、`bottomBarBuilder`、`overlayBuilder`、单页 `pageOverlayBuilder`。 |
| **桌面** | `ViewerDesktopUiMode`（`auto` / `force` / `never`）、`desktopChromeBuilder`、默认顶栏、`CallbackShortcuts`。 |
| **数据模型** | 抽象类 **`ViewerItem`** + 默认实现 **`DefaultViewerItem`**；可 `extends ViewerItem` 承载领域模型。 |
| **辅助组件** | `ViewerMediaCoverFrame`（随信息进度在 contain/cover 间过渡）、`ViewerHero`（列表缩略图与查看页 Hero）。 |
| **外部控制** | `MediaViewerController`：跳转页、信息显隐、顶底栏、缩放指令。 |

---

## 安装

```yaml
dependencies:
  yuni_photo_view: ^0.2.0
```

---

## 快速开始

```dart
import 'package:yuni_photo_view/yuni_photo_view.dart';

await MediaViewer.open(
  context,
  items: [
    DefaultViewerItem(id: '1', payload: 'https://example.com/a.jpg'),
    DefaultViewerItem(id: '2', payload: 'https://example.com/b.jpg'),
  ],
  pageBuilder: (ctx, pageCtx) {
    final url = pageCtx.item.payload as String;
    return ViewerMediaCoverFrame(
      revealProgress: pageCtx.infoRevealProgress,
      child: Image.network(url, fit: BoxFit.contain),
    );
  },
  infoBuilder: (ctx, pageCtx) => Text('元数据 ${pageCtx.item.id}'),
  topBarBuilder: (ctx, barCtx) => AppBar(
    title: Text(barCtx.item.id),
    leading: IconButton(
      icon: const Icon(Icons.close),
      onPressed: () => Navigator.of(ctx).pop(),
    ),
  ),
);
```

---

## 主要 API（库导出）

- **`MediaViewer` / `MediaViewer.open`**：路由入口与 `Stack` 层级。
- **`DefaultViewerItem`**：`id`、`kind`、`payload`、`meta`、`extra`、`hasInfo`、`copyWith`。
- **`ViewerItem`**：抽象基类；可子类化以携带强类型数据。
- **`ViewerInteractionConfig`**：阻尼、阈值、手势开关、**`ViewerDesktopUiMode`**、`resolveForShell()`。
- **`ViewerTheme`**：背景、信息面板外观、动画时长与曲线。
- **`MediaViewerController`**：命令式翻页 / 信息 / 栏显隐 / 缩放。
- **`ViewerPageContext` / `ViewerBarContext`**：传给各 Builder 的上下文。
- **`ViewerDesktopChromeContext` / `ViewerDesktopChromeBuilder`**：自定义桌面工具条。
- **`DefaultViewerDesktopChrome`**：内置顶栏（返回、翻页、信息、缩放）。
- **`ViewerHero`**、**`ViewerMediaCoverFrame`**：可选体验增强。

完整 API 文档见 [pub.dev 文档](https://pub.dev/documentation/yuni_photo_view/latest/)。

---

## 桌面端与 macOS

- 使用 `ViewerInteractionConfig(desktopUiMode: ViewerDesktopUiMode.auto)`：在 Windows / macOS / Linux **原生**宿主上自动启用桌面 UI；Web 大屏等可用 **`force`**。
- 需要完全自定义顶栏时传 **`desktopChromeBuilder`**；若仍要横滑翻页、下拉关闭、拖信息面板，可打开 `desktopAllowSwipePaging` 等开关。
- **macOS 沙盒**：使用 `Image.network` 时需在应用的 **`.entitlements`** 中开启出站网络 **`com.apple.security.network.client`**；本仓库 **example** 已配置示例。

---

## 示例工程

[`example/`](example/) 内含：网格进入、综合案例、自定义顶底栏、Hero、阻尼调试、镜像 Info、**桌面自定义控件条** 等。

```bash
cd example && flutter run
```

---

## 插件与 MethodChannel

包在工程上注册为 **Flutter 插件**（占位 **`MethodChannel` `yuni_photo_view`**）。查看器 UI **不依赖** 该通道；除非你扩展原生逻辑，否则可忽略 `getPlatformVersion` 等占位 API。

---

## 维护者：发布到 pub.dev

1. 保持 Git 工作区干净；若存在 **ImmichFrame** 等「已提交又被 ignore」的目录，请先理顺（移出版本库或取消忽略）。
2. 执行 `flutter test`。
3. `dart pub publish --dry-run` — 压缩包应在约数百 KB（`.pubignore` 已排除 `build/` 等）。
4. 在 [pub.dev](https://pub.dev/) 注册并登录：`dart pub login`。
5. `dart pub publish`，按浏览器提示确认。

---

## 许可证

MIT — 见 [LICENSE](LICENSE)。
