import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'yuni_photo_view_method_channel.dart';

abstract class YuniPhotoViewPlatform extends PlatformInterface {
  /// 子类注册时需携带同一 [token]。
  YuniPhotoViewPlatform() : super(token: _token);

  static final Object _token = Object();

  static YuniPhotoViewPlatform _instance = MethodChannelYuniPhotoView();

  /// 当前平台实现，默认可变通道实现。
  static YuniPhotoViewPlatform get instance => _instance;

  /// 各平台在注册时替换为各自的 [YuniPhotoViewPlatform] 子类。
  static set instance(YuniPhotoViewPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('getPlatformVersion 尚未实现。');
  }
}
