import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:yuni_photo_view/src/core/viewer_item.dart';

void main() {
  group('ViewerItem Gesture Control', () {
    test('generateRandomDefaultViewerItem creates valid instances', () {
      // Smoke test to verify the helper function works
      for (int i = 0; i < 10; i++) {
        final item = generateRandomDefaultViewerItem();
        
        // Verify the item is created successfully
        expect(item, isA<DefaultViewerItem>());
        expect(item.id, isNotEmpty);
        expect(item.enableGestureScaling, isA<bool>());
        expect(item.hasInfo, isA<bool>());
      }
    });

    test('TestViewerItemWithoutOverride inherits default enableGestureScaling', () {
      // Verify that the test subclass without override returns true by default
      final item = TestViewerItemWithoutOverride(id: 'test-1');
      
      expect(item.enableGestureScaling, true);
      expect(item.id, 'test-1');
      expect(item.hasInfo, true);
    });

    test('TestViewerItemWithOverride respects custom enableGestureScaling', () {
      // Verify that the test subclass with override returns the custom value
      final itemEnabled = TestViewerItemWithOverride(
        id: 'test-2',
        gestureEnabled: true,
      );
      final itemDisabled = TestViewerItemWithOverride(
        id: 'test-3',
        gestureEnabled: false,
      );
      
      expect(itemEnabled.enableGestureScaling, true);
      expect(itemDisabled.enableGestureScaling, false);
      expect(itemEnabled.id, 'test-2');
      expect(itemDisabled.id, 'test-3');
    });
  });
}

/// Generates a random [DefaultViewerItem] instance for property-based testing.
///
/// This helper creates varied test data by randomizing all fields including:
/// - [id]: Random string identifier
/// - [kind]: Nullable random string
/// - [payload]: Nullable random dynamic value
/// - [meta]: Nullable random map
/// - [extra]: Nullable random dynamic value
/// - [hasInfo]: Random boolean
/// - [enableGestureScaling]: Random boolean
///
/// **Validates: Requirements 1.1, 1.2, 1.3, 1.4, 1.5**
DefaultViewerItem generateRandomDefaultViewerItem() {
  final random = Random();
  return DefaultViewerItem(
    id: 'id-${random.nextInt(10000)}',
    kind: random.nextBool() ? 'kind-${random.nextInt(100)}' : null,
    payload: random.nextBool() ? 'payload-${random.nextInt(100)}' : null,
    meta: random.nextBool() ? {'key': 'value-${random.nextInt(100)}'} : null,
    extra: random.nextBool() ? 'extra-${random.nextInt(100)}' : null,
    hasInfo: random.nextBool(),
    enableGestureScaling: random.nextBool(),
  );
}

/// Test subclass that does not override [enableGestureScaling].
///
/// This class inherits the default implementation from [ViewerItem],
/// which returns `true` for backward compatibility.
///
/// **Validates: Requirements 2.3, 3.3**
class TestViewerItemWithoutOverride extends ViewerItem {
  const TestViewerItemWithoutOverride({required this.id});

  @override
  final String id;

  @override
  bool get hasInfo => true;
}

/// Test subclass that overrides [enableGestureScaling] with custom logic.
///
/// This class demonstrates how custom subclasses can provide their own
/// gesture scaling behavior by overriding the getter.
///
/// **Validates: Requirements 3.1**
class TestViewerItemWithOverride extends ViewerItem {
  const TestViewerItemWithOverride({
    required this.id,
    required this.gestureEnabled,
  });

  @override
  final String id;

  @override
  bool get hasInfo => true;

  @override
  bool get enableGestureScaling => gestureEnabled;

  final bool gestureEnabled;
}
