import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'yuni_photo_view_platform_interface.dart';

/// 通过 MethodChannel 与原生通信的 [YuniPhotoViewPlatform] 实现。
class MethodChannelYuniPhotoView extends YuniPhotoViewPlatform {
  /// 与原生侧约定的通道名。
  @visibleForTesting
  final methodChannel = const MethodChannel('yuni_photo_view');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
