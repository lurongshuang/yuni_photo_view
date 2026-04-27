# yuni_photo_view

[![pub package](https://img.shields.io/pub/v/yuni_photo_view.svg)](https://pub.dev/packages/yuni_photo_view)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**YuniPhotoView** 是一套 Flutter **生产级全屏媒体查看交互框架**。它提供了一套完整的“壳层”交互方案：分页管理、物理级缩放、异步分页加载、插槽系统、下拉关闭手势以及桌面端深度适配。

> **核心哲学**：本包**不直接渲染**图片或视频。所有具体的媒体渲染逻辑均由业务在 `pageBuilder` 等回调中完成，从而实现 UI 表现与业务逻辑的极致解耦。

---

## 🔥 核心特性

- **分页与物理缩放**：
  - 内置高性能 `PageView`。当内容放大时自动拦截翻页手势，确保缩放与翻页互不干扰。
  - **物理级不动点投影**：采用全局坐标投影算法，确保双击缩放点在任何嵌套布局下都能像素级精准对位。
- **双向异步分页加载 (Bi-directional Paging)**：
  - 支持 `openPaging` 模式。
  - **向后加载**：滑到列表末尾或初始项数不足时自动触发 `onLoadMore`。
  - **向前加载**：滑到列表开头或初始项数不足时自动触发 `onLoadPrevious`，并支持头部插入数据后的索引自动纠偏（视觉无跳变）。
- **插槽系统 (Slots)**：
  - **underMediaBuilder**：支持在媒体层与背景层之间插入自定义布局（如立体投影、底衬装饰），插槽内容随内容同步缩放。
- **业务数据透传 (Extra Payload)**：
  - `ViewerItem` 内置 `extra` 字段，业务数据可直接穿透壳层，在水印、详情面板中通过上下文直接读取。
- **下拉关闭手势**：
  - 丝滑的下拉跟手关闭，背景透明度与缩放联动。支持自定义触发阈值与回弹阻尼。
- **交互级动效定制**：
  - 暴露全链路动画参数（时长、曲线），让开发者能够调校出“弹簧”或“匀速”等差异化手感。
- **桌面端深度优化**：
  - 自动适配 macOS/Windows/Linux/Web。
  - 完整控件条方案：翻页、缩放步进、全键盘快捷键绑定。

---

## 📦 快速开始

### 1. 固定列表模式 (Basic)

```dart
import 'package:yuni_photo_view/yuni_photo_view.dart';

MediaViewer.open(
  context,
  items: [
    DefaultViewerItem(id: '1', payload: 'https://example.com/a.jpg'),
  ],
  pageBuilder: (ctx, pageCtx) {
    return Image.network(pageCtx.item.payload as String);
  },
);
```

### 2. 双向异步分页模式 (Paging)

```dart
MediaViewer.openPaging(
  context,
  initialItems: items,
  initialHasPrevious: true, // 初始是否有上一页
  onLoadMore: (lastItem) async {
    final nextItems = await api.fetchNextPage(after: lastItem.id);
    return PagingResult(items: nextItems, hasMore: true);
  },
  onLoadPrevious: (firstItem) async {
    // 向前加载更多数据
    final prevItems = await api.fetchPrevPage(before: firstItem.id);
    return PagingResult(items: prevItems, hasMore: true);
  },
  pageBuilder: (ctx, pageCtx) => Image.network(pageCtx.item.payload),
);
```

> **提示**：框架在初始化时会自动检查 `loadThreshold`。如果初始数据量少于阈值，会立即并发触发向后和向前的加载回调。

---

## 🛠️ API 详解

### 1. MediaViewer 核心参数

| 参数 | 说明 |
| :--- | :--- |
| `items` | 数据源。支持 `DefaultViewerItem` 或子类自定义字段。 |
| `pageBuilder` | **核心插槽**。构建每一页的主内容。 |
| `underMediaBuilder` | **新增插槽**。媒体层下方的叠加层（如自定义阴影）。 |
| `pageOverlayBuilder`| **浮层插槽**。随内容翻页，但不会被缩放。 |
| `onLoadMore` | **向后加载回调**。接收 `lastItem` 参数，返回 `PagingResult`。 |
| `onLoadPrevious` | **向前加载回调**。接收 `firstItem` 参数，返回 `PagingResult`。 |
| `initialHasPrevious` | 初始时是否允许向前加载。 |
| `loadThreshold` | 触发分页加载的阈值（默认 3）。当距离边缘不足此数量时触发回调。 |
| `theme` | `ViewerTheme`。管理颜色、动效 Duration/Curve。 |
| `config` | `InteractionConfig`。管理手势阈值、阻尼。 |

### 2. ViewerInteractionConfig (交互微调)

| 参数 | 默认值 | 说明 |
| :--- | :--- | :--- |
| `verticalDragMinStartDistance` | `3.0` | **手势门限**。微调纵向滑动触发关闭/面板的灵敏度，解决横滑误触。 |
| `infoSyncMode` | `perPage` | `mirrored` 模式下所有页共享 Info 面板展开状态。 |
| `defaultShownExtent` | `0.42` | Info 面板默认展开的屏幕高度比例。 |

### 3. ViewerTheme (动效定制)

| 参数 | 默认值 | 说明 |
| :--- | :--- | :--- |
| `zoomDuration` | `250ms` | 双击/程序化缩放的动画时长。 |
| `zoomCurve` | `easeInOut` | 缩放动画曲线（推荐尝试 `elasticOut`）。 |
| `barsToggleDuration` | `240ms` | 顶底栏显隐切换时长。 |

---

## 🧩 数据模型与上下文

### **ViewerItem.enableGestureScaling (手势缩放控制)**
您可以为每个 `ViewerItem` 单独控制是否启用手势缩放功能：
```dart
DefaultViewerItem(
  id: 'img_1',
  payload: 'https://example.com/photo.jpg',
  enableGestureScaling: false,  // 禁用双指捏合和双击缩放
)
```
- **默认值**: `true` (启用手势缩放)
- **适用场景**: 
  - 文档预览：禁用缩放，只允许滑动翻页
  - 视频播放：避免手势冲突
  - 自定义交互：需要自己处理手势的场景
- **向后兼容**: 现有代码无需修改，默认保持启用状态

### **ViewerItem.extra (业务 Payload)**
您可以在构造 `ViewerItem` 时传入自定义业务字典：
```dart
DefaultViewerItem(
  id: 'img_1',
  extra: {'isVIP': true, 'watermark': 'Yuni'}
)
```
随后在任何 Builder 中，通过 `pageCtx.extra` 或 `barCtx.item.extra` 直接获取，实现 UI 联动。

### **ViewerPageContext (单页实时状态)**
- `infoRevealProgress`: `0.0` (收起) ~ `1.0` (展开)。可用于驱动图片向上偏移避让面板。
- `dismissProgress`: 下拉关闭进度。

---

## 🚀 进阶：不动点缩放原理
系统使用全局坐标投影公式 `P2 = V - (V - P1) * (S2 / S1)`。无论您的 `MediaViewer` 被嵌套在多复杂的组件树下（如抽屉、对话框、带偏移的层级），点击位置都能精准映射回媒体内容的物理像素点，彻底解决手势漂移。

## 许可证

MIT — 见 [LICENSE](LICENSE)。
