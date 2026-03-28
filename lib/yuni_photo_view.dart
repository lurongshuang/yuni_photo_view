
import 'yuni_photo_view_platform_interface.dart';

export 'src/models/media_item.dart';
export 'src/controllers/media_viewer_controller.dart';
export 'src/widgets/yuni_media_hero_wrapper.dart';
export 'src/widgets/yuni_media_viewer.dart';
export 'src/gestures/yuni_media_gesture_handler.dart';

class YuniPhotoView {
  Future<String?> getPlatformVersion() {
    return YuniPhotoViewPlatform.instance.getPlatformVersion();
  }
}
