import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:yuni_photo_view/yuni_photo_view.dart';

import '../utils/demo_data.dart';

/// 案例：ViewerMediaCoverFrame 复杂案例展示
///
/// 演示在 [ViewerMediaCoverFrame] 中加入：
/// 1. 带有自定义叠加层（标签/装饰）的图片。
/// 2. 完整比例适配的视频播放器。
/// 3. 撑满全视口的自定义卡片（layoutChildToViewport: true）。
class ViewerMediaCoverFrameCase extends StatelessWidget {
  const ViewerMediaCoverFrameCase({super.key});

  @override
  Widget build(BuildContext context) {
    // 构造混合类型的演示数据
    final items = [
      ...DemoData.images.take(1), // 普通图片
      const DefaultViewerItem(
        id: 'tall_image',
        kind: 'image',
        payload: 'https://picsum.photos/seed/tall/600/3000',
        meta: {'title': '极长图（3000h）'},
      ),
      const DefaultViewerItem(
        id: 'wide_image',
        kind: 'image',
        payload: 'https://picsum.photos/seed/wide/3000/600',
        meta: {'title': '极宽图（3000w）'},
      ),
      const DefaultViewerItem(
        id: 'small_image',
        kind: 'image',
        payload: 'https://picsum.photos/seed/small/100/100',
        meta: {'title': '极小图（100x100）'},
      ),
      ...DemoData.videos.take(1), // 视频案例
      const DefaultViewerItem(
        id: 'tall_video',
        kind: 'video',
        payload:
            'https://sns-video-hw.xhscdn.com/pre_post/1040g2t031ucqi83n1s704a4e9ih49np5omkdmgg',
        meta: {'title': '竖屏视频（测试）'},
        hasInfo: true,
      ),
      const DefaultViewerItem(
        id: 'custom_layout',
        kind: 'custom',
        payload: 'Custom Card',
        meta: {'title': '全屏自定义布局'},
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('CoverFrame 复杂案例')),
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
          final title = item.meta?['title'] ??
              (item.kind == 'image'
                  ? '图片'
                  : (item.kind == 'video' ? '视频' : '自定义'));
          return GestureDetector(
            onTap: () => _open(ctx, items, i),
            child: Container(
              color: Colors.grey.shade200,
              padding: const EdgeInsets.all(4),
              alignment: Alignment.center,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11),
              ),
            ),
          );
        },
      ),
    );
  }

  void _open(BuildContext context, List<ViewerItem> items, int initialIndex) {
    MediaViewer.open(
      context,
      items: items,
      initialIndex: initialIndex,
      pageBuilder: (ctx, pageCtx) {
        final item = pageCtx.item;

        // 场景 1：图片 + 内部叠加装饰
        if (item.kind == 'image') {
          return ViewerMediaCoverFrame(
            revealProgressListenable: pageCtx.infoRevealProgressListenable,
            child: Center(
              child: Stack(
                children: [
                  Image.network(
                    item.payload as String,
                    fit: BoxFit.contain, // 自然比例
                  ),
                  // 叠加在图片各处的装饰，会随 Frame 的缩放和位移一起插值
                  Positioned(
                    left: 20,
                    bottom: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.id == 'small_image' ? '极小图' : '图片装饰',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // 场景 2：视频播放器
        if (item.kind == 'video') {
          return _VideoFrameItem(pageCtx: pageCtx);
        }

        // 场景 3：自定义全视口布局
        return ViewerMediaCoverFrame(
          revealProgressListenable: pageCtx.infoRevealProgressListenable,
          layoutChildToViewport: true, // 撑满整个视口，不保留自然高测量
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade300, Colors.purple.shade300],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.dashboard_customize,
                      size: 64, color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    '这是一个自定义卡片\nlayoutChildToViewport: true',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('交互按钮'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      infoBuilder: (ctx, pageCtx) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '案例说明',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                '当前演示的是 ${pageCtx.item.kind} 类型在 ViewerMediaCoverFrame 中的表现。'
                '\n\n上滑查看时，内容会从“居中包含”平滑过渡到“贴顶铺满”。'
                '对于自定义布局，可以开启 layoutChildToViewport 让其撑满视口。',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 100), // 撑开高度
            ],
          ),
        );
      },
    );
  }
}

/// 负责视频初始化和在 Frame 内展示的组件
class _VideoFrameItem extends StatefulWidget {
  const _VideoFrameItem({required this.pageCtx});

  final ViewerPageContext pageCtx;

  @override
  State<_VideoFrameItem> createState() => _VideoFrameItemState();
}

class _VideoFrameItemState extends State<_VideoFrameItem> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    debugPrint(
        '[ViewerLog] _VideoFrameItemState.initState for ${widget.pageCtx.item.id}');
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.pageCtx.item.payload as String),
    )..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _controller?.play();
        _controller?.setLooping(true);
      });
  }

  @override
  void dispose() {
    debugPrint(
        '[ViewerLog] _VideoFrameItemState.dispose for ${widget.pageCtx.item.id}');
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
        '[ViewerLog] _VideoFrameItemState.build for ${widget.pageCtx.item.id}');
    if (_controller == null || !_controller!.value.isInitialized) {
      return ViewerMediaCoverFrame(
        revealProgressListenable: widget.pageCtx.infoRevealProgressListenable,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return ViewerMediaCoverFrame(
      revealProgressListenable: widget.pageCtx.infoRevealProgressListenable,
      layoutChildToViewport: true,
      child: Center(
        child: AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: VideoPlayer(_controller!),
        ),
      ),
    );
  }
}
