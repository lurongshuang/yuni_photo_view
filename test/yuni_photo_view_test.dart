import 'package:flutter_test/flutter_test.dart';
import 'package:yuni_photo_view/yuni_photo_view.dart';
import 'package:yuni_photo_view/yuni_photo_view_platform_interface.dart';
import 'package:yuni_photo_view/yuni_photo_view_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockYuniPhotoViewPlatform
    with MockPlatformInterfaceMixin
    implements YuniPhotoViewPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final YuniPhotoViewPlatform initialPlatform = YuniPhotoViewPlatform.instance;

  test('$MethodChannelYuniPhotoView is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelYuniPhotoView>());
  });

  test('getPlatformVersion', () async {
    YuniPhotoView yuniPhotoViewPlugin = YuniPhotoView();
    MockYuniPhotoViewPlatform fakePlatform = MockYuniPhotoViewPlatform();
    YuniPhotoViewPlatform.instance = fakePlatform;

    expect(await yuniPhotoViewPlugin.getPlatformVersion(), '42');
  });
}
