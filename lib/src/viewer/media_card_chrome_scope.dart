import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// 由查看器壳层在启用「主内容卡片」时插入。
///
/// **引用稳定**：[clipRadiusListenable] 在页生命周期内为同一 [ValueNotifier]，
/// 仅其 [ValueListenable.value] 随动画变化，避免每帧触发 [InheritedWidget] 全局重建
///（会与 [PageView] viewport 的 semantics 遍历冲突）。
///
/// [ViewerMediaCoverFrame] 内部用 [ListenableBuilder] 监听该对象，只更新裁剪层。
/// 自定义媒体可用 [maybeOf] 取得 listenable 后自行包 [ClipRRect]。
class MediaCardChromeScope extends InheritedWidget {
  const MediaCardChromeScope({
    super.key,
    required this.clipRadiusListenable,
    required super.child,
  });

  /// 当前应对图片外接矩形使用的圆角半径（已由壳层按动画写好）。
  final ValueListenable<double> clipRadiusListenable;

  static MediaCardChromeScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MediaCardChromeScope>();
  }

  @override
  bool updateShouldNotify(MediaCardChromeScope oldWidget) {
    return oldWidget.clipRadiusListenable != clipRadiusListenable;
  }
}
