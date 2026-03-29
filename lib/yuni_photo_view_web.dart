// 若不希望在此忽略，可将 Web 实现拆成独立 package。
// ignore: avoid_web_libraries_in_flutter

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'yuni_photo_view_platform_interface.dart';

/// 插件在 Web 上的 [YuniPhotoViewPlatform] 实现。
class YuniPhotoViewWeb extends YuniPhotoViewPlatform {
  YuniPhotoViewWeb();

  static void registerWith(Registrar registrar) {
    YuniPhotoViewPlatform.instance = YuniPhotoViewWeb();
  }

  @override
  Future<String?> getPlatformVersion() async {
    final version = web.window.navigator.userAgent;
    return version;
  }
}
