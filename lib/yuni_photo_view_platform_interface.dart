import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'yuni_photo_view_method_channel.dart';

abstract class YuniPhotoViewPlatform extends PlatformInterface {
  /// Constructs a YuniPhotoViewPlatform.
  YuniPhotoViewPlatform() : super(token: _token);

  static final Object _token = Object();

  static YuniPhotoViewPlatform _instance = MethodChannelYuniPhotoView();

  /// The default instance of [YuniPhotoViewPlatform] to use.
  ///
  /// Defaults to [MethodChannelYuniPhotoView].
  static YuniPhotoViewPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [YuniPhotoViewPlatform] when
  /// they register themselves.
  static set instance(YuniPhotoViewPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
