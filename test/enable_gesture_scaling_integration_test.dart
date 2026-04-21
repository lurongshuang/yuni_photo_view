import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuni_photo_view/yuni_photo_view.dart';

void main() {
  group('enableGestureScaling Integration Tests', () {
    testWidgets('MediaViewer respects enableGestureScaling=false', (tester) async {
      // 创建一个禁用手势缩放的ViewerItem
      final items = [
        const DefaultViewerItem(
          id: 'test-1',
          payload: 'https://example.com/image.jpg',
          enableGestureScaling: false,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaViewer(
              items: items,
              pageBuilder: (context, pageCtx) {
                return Container(
                  color: Colors.blue,
                  child: Center(
                    child: Text('Item ${pageCtx.item.id}'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证MediaViewer已构建
      expect(find.text('Item test-1'), findsOneWidget);
      
      // 注意：由于PhotoView的手势是通过disableGestures控制的，
      // 这里主要验证构建没有错误，实际手势行为需要在真实设备上测试
    });

    testWidgets('MediaViewer respects enableGestureScaling=true (default)', (tester) async {
      // 创建一个启用手势缩放的ViewerItem（默认值）
      final items = [
        const DefaultViewerItem(
          id: 'test-2',
          payload: 'https://example.com/image.jpg',
          // enableGestureScaling默认为true
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaViewer(
              items: items,
              pageBuilder: (context, pageCtx) {
                return Container(
                  color: Colors.green,
                  child: Center(
                    child: Text('Item ${pageCtx.item.id}'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证MediaViewer已构建
      expect(find.text('Item test-2'), findsOneWidget);
    });

    testWidgets('MediaViewer handles mixed enableGestureScaling values', (tester) async {
      // 创建混合了启用和禁用手势缩放的ViewerItem列表
      final items = [
        const DefaultViewerItem(
          id: 'enabled-1',
          payload: 'https://example.com/image1.jpg',
          enableGestureScaling: true,
        ),
        const DefaultViewerItem(
          id: 'disabled-1',
          payload: 'https://example.com/image2.jpg',
          enableGestureScaling: false,
        ),
        const DefaultViewerItem(
          id: 'enabled-2',
          payload: 'https://example.com/image3.jpg',
          enableGestureScaling: true,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaViewer(
              items: items,
              pageBuilder: (context, pageCtx) {
                return Container(
                  color: pageCtx.item.enableGestureScaling 
                      ? Colors.green 
                      : Colors.red,
                  child: Center(
                    child: Text(
                      'Item ${pageCtx.item.id}\n'
                      'Gesture: ${pageCtx.item.enableGestureScaling ? "Enabled" : "Disabled"}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证第一个item（启用手势）
      expect(find.textContaining('Item enabled-1'), findsOneWidget);
      expect(find.textContaining('Gesture: Enabled'), findsOneWidget);
    });

    testWidgets('Custom ViewerItem subclass without override uses default', (tester) async {
      // 创建自定义ViewerItem子类（不覆盖enableGestureScaling）
      final items = [
        const _TestCustomItem(id: 'custom-1'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaViewer(
              items: items,
              pageBuilder: (context, pageCtx) {
                return Container(
                  color: Colors.purple,
                  child: Center(
                    child: Text(
                      'Custom Item ${pageCtx.item.id}\n'
                      'Gesture: ${pageCtx.item.enableGestureScaling ? "Enabled" : "Disabled"}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证自定义item使用默认值（true）
      expect(find.textContaining('Custom Item custom-1'), findsOneWidget);
      expect(find.textContaining('Gesture: Enabled'), findsOneWidget);
    });
  });
}

/// 测试用的自定义ViewerItem子类（不覆盖enableGestureScaling）
class _TestCustomItem extends ViewerItem {
  const _TestCustomItem({required this.id});

  @override
  final String id;

  @override
  bool get hasInfo => true;
}
