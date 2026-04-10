# yuni_photo_view

[![pub package](https://img.shields.io/pub/v/yuni_photo_view.svg)](https://pub.dev/packages/yuni_photo_view)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**YuniPhotoView** 是一套 Flutter **全屏媒体查看交互框架**。它提供了一套完整的“壳层”能力：分页管理、PhotoView 集成、吸附式信息面板、下拉跟手关闭、顶部/底部操作栏补位，以及针对桌面端的全面适配。

> **核心哲学**：本包**不绘制**具体的媒体内容（图片或视频）。具体的解码、渲染布局均由业务在 `pageBuilder` 等回调中完成，从而实现与业务逻辑的高度解耦。

---

## 核心特性

- **分页与缩放**：内置 `PageView`。图片放大时自动禁止横滑翻页，确保手势不冲突。支持通过控制器程序化控制缩放。
- **信息面板**：底部弹性面板，支持拖拽吸附。在触屏上支持手势上滑，桌面端支持通过按钮/快捷键展开。
- **下拉关闭**：丝滑的下拉跟手关闭手势，背景透明度随进度变化，支持自定义回弹阻尼。
- **桌面端增强**：自动识别 macOS/Windows/Linux。提供专门的桌面工具条（翻页、缩放、旋转预览、信息开关）。支持键盘快捷键。
- **相册卡片模式**：支持图片在“有圆角/有边距的卡片态”与“无圆角/无边距的全屏态”之间平滑切换。
- **图片感知背景**：内置 `ViewerDiffuseBackground`，支持从 URL 自动取色并根据图片比例自适应对齐。

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
  // 背景装饰（可选）
  backgroundBuilder: (ctx, pageCtx) => ViewerDiffuseBackground(
    pageCtx: pageCtx,
    url: pageCtx.item.payload as String,
  ),
  infoBuilder: (ctx, pageCtx) => Text('元数据 ${pageCtx.item.id}'),
);
```

---

## 组件与参数详解

### 1. MediaViewer (主入口)

使用 `MediaViewer.open(context, ...)` 静态方法快速启动查看器。

| 参数 | 类型 | 说明与场景 |
| :--- | :--- | :--- |
| `items` | `List<ViewerItem>` | **必填**。数据源列表。建议使用 `DefaultViewerItem` 或继承它以携带更多信息。 |
| `pageBuilder` | `ViewerPageBuilder` | **必填**。构建每一页的主内容（图片/视频）。提供 `ViewerPageContext` 包含当前页缩放进度。 |
| `backgroundBuilder`| `ViewerPageOverlayBuilder` | **可选**。构建垫在媒体下层的背景（如模糊球、装饰图）。会随翻页切换。 |
| `infoBuilder` | `ViewerInfoBuilder` | **可选**。底部信息面板内容。若为 null，则该页不显示信息面板。 |
| `topBarBuilder` | `ViewerBarBuilder` | **可选**。自定义顶栏。框架会自动处理其显隐动画。 |
| `bottomBarBuilder` | `ViewerBarBuilder` | **可选**。自定义底栏（通常放置页码、收藏、操作按钮）。 |
| `onPageChanged` | `Function(int)` | **业务钩子**。当页面切换完成时回调。 |
| `onDismiss` | `VoidCallback` | **业务钩子**。当查看器彻底关闭（下拉或返回）时回调。 |
| `theme` | `ViewerTheme` | **样式**。控制颜色、圆角、动画时长。 |
| `config` | `InteractionConfig` | **手势**。微调阻尼、阈值、手势开关。 |

---

### 2. ViewerInteractionConfig (交互配置)

控制手势手感、物理阈值以及桌面端行为。

| 参数 | 默认值 | 说明与场景 |
| :--- | :--- | :--- |
| `infoDragUpDamping` | `0.88` | **阻尼**。上滑拉高信息面板时的阻抗感。 |
| `viewerDismissDownDamping` | `0.55` | **阻尼**。下拉关闭时的跟手程度感。 |
| `enableDismissGesture` | `true` | **开关**。设为 false 则只能通过返回键关闭。 |
| `enableTapToToggleBars`| `true` | **开关**。单击内容区是否切换工具栏显隐。 |
| `desktopUiMode` | `auto` | **桌面模式**。支持 `auto` (自动识别平台), `force` (强制启用), `never` (仅触屏模式)。 |
| `infoSyncMode` | `perPage` | **信息同步**。`perPage` 表示每页独立记忆高度；`mirrored` 表示所有页共享高度。 |

---

### 3. ViewerTheme (主题定制)

定义查看器的视觉表现，特别是对于“相册卡片模式”的控制。

| 参数 | 默认值 | 说明与场景 |
| :--- | :--- | :--- |
| `backgroundColor` | `Colors.black` | **背景色**。下拉过程中其透明度会逐渐升高。 |
| `infoBorderRadius` | `14 (top)` | **圆角**。信息面板底座顶部的圆角。 |
| `mediaCardInset` | `zero` | **外框边距**。设置为如 `EdgeInsets.all(10)`，则在工具栏显示且未放大时，图片会呈现“悬浮卡片”感。 |
| `mediaCardBorderRadius`| `0` | **外框圆角**。配合 `mediaCardInset` 使用，实现图片边框的平滑圆角动画。 |
| `infoShowDuration` | `320ms` | **时长**。由于底层使用 `Ticking` 驱动，该值决定展开吸附的速度。 |

---

### 4. 辅助增强组件 (Helper Widgets)

#### **ViewerHero**
用于实现从缩略图到大图查看器的极致平滑过渡。
- `tag`: 唯一标识。
- `imageProvider`: 用于插值的图片提供者（如 `NetworkImage(url)`）。
- `thumbnailCornerRadius`: 列表中缩略图的圆角。
- `viewCornerRadius`: 进入大图模式后的圆角（通常设为 18~20）。

#### **ViewerMediaCoverFrame**
包裹在 `pageBuilder` 内部。
- `revealProgress`: 传入 `pageCtx.infoRevealProgress`。
- **作用**: 当底部信息面板上滑时，内容会自动从 `contain` 模式向顶部偏移并转为 `cover` 裁剪感，保持视觉焦点。

#### **ViewerDiffuseBackground**
专门用于 `backgroundBuilder` 的装饰组件。
- `url`: 传入图片 URL，组件会自动从图片中**提取主题色**作为装饰色。
- `pageCtx`: 用于感知当前页面的缩放和圆角状态。
- **特性**: 自动感知图片显示尺寸，确保装饰球始终紧贴图片边缘（对横轴/纵显图做了适配）。

---

### 5. 数据上下文与模型 (Context & Models)

在各构造器回调中，你会获得以下对象：

#### **ViewerItem (数据基类)**
查看器对每一页数据的抽象契约。框架仅感知以下核心字段：
- `id`: **必填**。唯一标识（Hero 动画、分页 Key、性能优化）。
- `hasInfo`: 是否支持显示信息面板。若为 `false`，则自动收起信息并禁止相关手势。

> **自定义模型建议**: 我们不再在基类中强制提供 `payload` 或 `meta` 等通用字段。建议通过 `class MyMedia extends ViewerItem` 定义您业务所需的强类型字段（如 `url`, `title`, `duration` 等），随后在 `pageBuilder` 中进行简单的类型转换即可。

#### **DefaultViewerItem (默认实现)**
为了快速接入或简单的 URL 查看场景，我们提供了这一默认实现类。它内置了 `payload` (通常存 URL)、`meta` (键值对)、`kind` 等常用字段。

#### **ViewerPageContext (单页实时上下文)**
在 `pageBuilder`, `backgroundBuilder`, `infoBuilder` 等回调中提供：
- `index`: 当前页下标。
- `itemCount`: 列表总数（便于在页面内显示页码）。
- `infoRevealProgress`: **核心字段**。0.0 为完全隐藏，1.0 为默认高度。可用于联动动画。
- `availableSize`: 剔除掉信息面板后的有效可视区域。
- `barsVisible`: 全局顶底栏是否处于显示状态（单击切换）。
- `dismissProgress`: 下拉关闭进度（0.0~1.0）。

#### **ViewerBarContext (全局栏上下文)**
仅在 `topBarBuilder` 和 `bottomBarBuilder` 中提供：
- `index` / `itemCount`: 当前页码与总数。
- `isZoomed`: 当前内容是否处于放大状态。
- `dismissProgress`: 下拉关闭进度，可用于在下拉时渐隐工具栏内容。
- `infoRevealProgress`: 信息面板上拉进度，可用于底栏避让。

---

## 许可证

MIT — 见 [LICENSE](LICENSE)。
