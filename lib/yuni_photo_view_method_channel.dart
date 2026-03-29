import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'yuni_photo_view_platform_interface.dart';

/// An implementation of [YuniPhotoViewPlatform] that uses method channels.
class MethodChannelYuniPhotoView extends YuniPhotoViewPlatform {
  /// The method channel used to interact with the native platform.
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
