import 'package:flutter_test/flutter_test.dart';
import 'package:yuni_photo_view/yuni_photo_view.dart';

void main() {
  group('DefaultViewerItem', () {
    test('holds id and payload', () {
      const item = DefaultViewerItem(id: 'a', payload: 'https://example.com/x.jpg');
      expect(item.id, 'a');
      expect(item.payload, 'https://example.com/x.jpg');
      expect(item.hasInfo, true);
    });

    test('copyWith overrides hasInfo', () {
      const item = DefaultViewerItem(id: 'b', hasInfo: true);
      final next = item.copyWith(hasInfo: false);
      expect(next.hasInfo, false);
      expect(next.id, 'b');
    });

    test('copyWith overrides enableGestureScaling', () {
      const item = DefaultViewerItem(id: 'c', enableGestureScaling: true);
      final next = item.copyWith(enableGestureScaling: false);
      expect(next.enableGestureScaling, false);
      expect(next.id, 'c');
    });

    test('copyWith preserves enableGestureScaling when not specified', () {
      const item = DefaultViewerItem(id: 'd', enableGestureScaling: false);
      final next = item.copyWith(hasInfo: false);
      expect(next.enableGestureScaling, false);
      expect(next.id, 'd');
    });

    test('toString includes enableGestureScaling when true', () {
      const item = DefaultViewerItem(id: 'e', enableGestureScaling: true);
      final str = item.toString();
      expect(str, contains('enableGestureScaling'));
      expect(str, contains('true'));
    });

    test('toString includes enableGestureScaling when false', () {
      const item = DefaultViewerItem(id: 'f', enableGestureScaling: false);
      final str = item.toString();
      expect(str, contains('enableGestureScaling'));
      expect(str, contains('false'));
    });
  });

  group('ViewerInteractionConfig', () {
    test('usesDesktopUi respects force', () {
      const c = ViewerInteractionConfig(desktopUiMode: ViewerDesktopUiMode.force);
      expect(c.usesDesktopUi, true);
    });

    test('resolveForShell tightens gestures on desktop', () {
      const c = ViewerInteractionConfig(
        desktopUiMode: ViewerDesktopUiMode.force,
        enableHorizontalPaging: true,
        enableDismissGesture: true,
        enableInfoGesture: true,
      );
      final r = c.resolveForShell();
      expect(r.enableHorizontalPaging, false);
      expect(r.enableDismissGesture, false);
      expect(r.enableInfoGesture, false);
    });
  });
}
