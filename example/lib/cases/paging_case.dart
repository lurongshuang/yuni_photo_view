import 'package:flutter/material.dart';
import 'package:yuni_photo_view/yuni_photo_view.dart';
import '../utils/demo_data.dart';

/// 分页加载案例：演示如何使用 MediaViewer.openPaging 实现“加载更多”功能。
class PagingCase extends StatefulWidget {
  const PagingCase({super.key});

  @override
  State<PagingCase> createState() => _PagingCaseState();
}

class _PagingCaseState extends State<PagingCase> {
  int _fetchCount = 0;

  /// 模拟网络异步请求新数据
  Future<PagingResult> _loadMore(ViewerItem lastItem) async {
    debugPrint('[PagingLog] 正在基于最后一项加载更多: ${lastItem.id}');
    await Future.delayed(const Duration(seconds: 1)); // 模拟延迟
    _fetchCount++;

    // 构造一批新项目
    final List<ViewerItem> newItems = DemoData.images.map((item) {
      final defaultItem = item as DefaultViewerItem;
      return defaultItem.copyWith(
        id: '${item.id}_p$_fetchCount',
        meta: {
          ...?item.meta,
          'title': '分页加载第 $_fetchCount 批',
        },
      );
    }).toList();

    return PagingResult(
      items: newItems,
      hasMore: _fetchCount < 3, // 模拟总共只有 3 批数据
    );
  }

  void _open(BuildContext context) {
    _fetchCount = 0; // 重置计数

    MediaViewer.openPaging(
      context,
      initialItems: List.from(DemoData.images),
      onLoadMore: _loadMore,
      initialHasMore: true,
      loadThreshold: 2, // 距离末尾 2 张就开始加载
      pageBuilder: (ctx, pageCtx) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Image.network(
                  pageCtx.item.payload as String,
                  fit: BoxFit.contain,
                ),
              ),
              Container(
                color: Colors.black54,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Text(
                  'ID: ${pageCtx.item.id}\n'
                  '${pageCtx.item.meta?['title'] ?? ''}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
        );
      },
      topBarBuilder: (ctx, barCtx) => SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(ctx),
            ),
            const Spacer(),
            Text(
              '已加载批次: $_fetchCount',
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('异步分页加载')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.autorenew, size: 64, color: Colors.deepPurple),
            const SizedBox(height: 16),
            const Text('滑动手感演示：滑到末尾前将自动请求新数据'),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => _open(context),
              child: const Text('打开分页查看器'),
            ),
          ],
        ),
      ),
    );
  }
}
