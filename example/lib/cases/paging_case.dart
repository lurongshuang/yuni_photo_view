import 'package:flutter/material.dart';
import 'package:yuni_photo_view/yuni_photo_view.dart';
import '../utils/demo_data.dart';

/// 双向分页加载案例：演示如何使用 MediaViewer.openPaging 实现“前后加载更多”功能。
class PagingCase extends StatefulWidget {
  const PagingCase({super.key});

  @override
  State<PagingCase> createState() => _PagingCaseState();
}

class _PagingCaseState extends State<PagingCase> {
  int _fetchCount = 0;
  int _fetchPreviousCount = 0;

  /// 模拟网络异步请求新数据（向后加载）
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
          'title': '向后分页加载第 $_fetchCount 批',
        },
      );
    }).toList();

    return PagingResult(
      items: newItems,
      hasMore: _fetchCount < 3, // 模拟总共只有 3 批数据
    );
  }

  /// 模拟网络异步请求新数据（向前加载）
  Future<PagingResult> _loadPrevious(ViewerItem firstItem) async {
    debugPrint('[PagingLog] 正在基于第一项加载向前更多: ${firstItem.id}');
    await Future.delayed(const Duration(seconds: 1)); // 模拟延迟
    _fetchPreviousCount++;

    // 构造一批新项目（反向构造以模拟顺序）
    final List<ViewerItem> newItems = DemoData.images.reversed.map((item) {
      final defaultItem = item as DefaultViewerItem;
      return defaultItem.copyWith(
        id: '${item.id}_prev$_fetchPreviousCount',
        meta: {
          ...?item.meta,
          'title': '向前分页加载第 $_fetchPreviousCount 批',
        },
      );
    }).toList();

    return PagingResult(
      items: newItems,
      hasMore: _fetchPreviousCount < 2, // 模拟总共只有 2 批向前数据
    );
  }

  void _open(BuildContext context) {
    _fetchCount = 0; // 重置计数
    _fetchPreviousCount = 0;

    MediaViewer.openPaging(
      context,
      initialItems: List.from(DemoData.images),
      onLoadMore: _loadMore,
      onLoadPrevious: _loadPrevious,
      initialHasMore: true,
      initialHasPrevious: true,
      loadThreshold: 2, // 距离边缘 2 张就开始加载
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
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '向前已加载: $_fetchPreviousCount',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
                Text(
                  '向后已加载: $_fetchCount',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ],
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
      appBar: AppBar(title: const Text('双向异步分页加载')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.compare_arrows, size: 64, color: Colors.deepPurple),
            const SizedBox(height: 16),
            const Text('双向加载演示：滑到开头或末尾都会触发请求'),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => _open(context),
              child: const Text('打开双向分页查看器'),
            ),
          ],
        ),
      ),
    );
  }
}
