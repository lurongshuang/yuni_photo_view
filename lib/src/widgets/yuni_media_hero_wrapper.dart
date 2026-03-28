import 'package:flutter/material.dart';

/// 用于 Hero 动画的包裹组件
/// 使用者需要在列表页中使用此组件包裹每个媒体项
class YuniMediaHeroWrapper extends StatelessWidget {
  final String heroTag;
  final Widget child;
  final VoidCallback? onTap;

  const YuniMediaHeroWrapper({
    super.key,
    required this.heroTag,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Hero(
        tag: heroTag,
        // 确保在飞行过程中保持正确的缩放比
        flightShuttleBuilder: (
          BuildContext flightContext,
          Animation<double> animation,
          HeroFlightDirection flightDirection,
          BuildContext fromHeroContext,
          BuildContext toHeroContext,
        ) {
          final Hero toHero = toHeroContext.widget as Hero;
          return Center(
            child: toHero.child,
          );
        },
        child: child,
      ),
    );
  }
}
