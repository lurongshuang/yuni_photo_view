import 'dart:math';
import 'package:flutter/material.dart';
import '../controllers/media_viewer_controller.dart';

/// 像素级还原 iOS 相册手势处理器：
/// - 基于“动态锚定与层级压盖”的物理模型
/// - 0.2x 强阻尼上滑
/// - 终态内部滚动支持
class YuniMediaGestureHandler extends StatefulWidget {
  final Widget child;
  final Widget? infoLayer;
  final YuniMediaViewerController controller;
  final VoidCallback onDismiss;
  final double infoShowDamping;
  final double infoHideDamping;
  final double dismissDamping;

  const YuniMediaGestureHandler({
    super.key,
    required this.child,
    required this.controller,
    required this.onDismiss,
    this.infoLayer,
    this.infoShowDamping = 0.2,
    this.infoHideDamping = 0.5,
    this.dismissDamping = 1.0,
  });

  @override
  State<YuniMediaGestureHandler> createState() =>
      _YuniMediaGestureHandlerState();
}

class _YuniMediaGestureHandlerState extends State<YuniMediaGestureHandler>
    with SingleTickerProviderStateMixin {
  double _rawDy = 0; // 原始垂直位移
  late AnimationController _animController;
  late Animation<double> _dyAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (widget.controller.isSnappedToDetails) {
      if (details.delta.dy > 0) {
        // 在详情态下拉：解除吸附
        widget.controller.setIsSnappedToDetails(false);
      } else {
        // 在详情态依然往上拉：锁定不处理（或由长信息滚动接管）
        return;
      }
    }

    double delta = details.delta.dy;
    double damping;

    if (delta < 0) {
      // 1. 任何时候的上拉（显示或者推进详情）
      damping = widget.infoShowDamping;
    } else {
      // 2. 下拉逻辑
      if (_rawDy < 0) {
        // 从详情/中间态下拉收回
        damping = widget.infoHideDamping;
      } else {
        // 从中心态下拉关闭页面
        damping = widget.dismissDamping;
      }
    }

    setState(() {
      _rawDy += delta * damping;
      _updateControllerProgress();
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final screenHeight = MediaQuery.of(context).size.height;
    final velocity = details.velocity.pixelsPerSecond.dy;

    // 获取图片 Contain 态下的初始偏移，作为吸附的目标值
    final mediaSize = widget.controller.currentMediaSize ??
        Size(MediaQuery.of(context).size.width, screenHeight);
    double containScale =
        min(MediaQuery.of(context).size.width / mediaSize.width, screenHeight / mediaSize.height);
    double renderHeightAtContain = mediaSize.height * containScale;
    double initialTop = (screenHeight - renderHeightAtContain) / 2.0;

    // 现在 _rawDy 直观代表 UI 偏移量，目标吸附点是 -initialTop (抵顶)
    double targetDy = -initialTop;

    // 彻底解耦：使用绝对物理距离作为触发阈值（100px）
    const double triggerDist = 100.0;

    if (_rawDy < 0) {
      // 1. 速度判定 (Flick)：
      if (velocity < -800) {
        // 快速上滑，进入详情
        _snapTo(targetDy, true);
      } else if (velocity > 800) {
        // 快速下滑，收回全屏
        _snapTo(0, false);
      } else {
        // 2. 静态位置判定（基于绝对行程）：
        if (_rawDy < targetDy + triggerDist) {
          // 当前位置已经非常接近详情态（或者行程本身就没超过阈值），则吸附进入详情
          _snapTo(targetDy, true);
        } else if (_rawDy > -triggerDist) {
          // 当前位置已经回退到非常接近全屏态，则收回全屏
          _snapTo(0, false);
        } else {
          // 3. 兜底逻辑：在长行程的中间地带，按中点划分归属
          if (_rawDy < targetDy / 2.0) {
            _snapTo(targetDy, true);
          } else {
            _snapTo(0, false);
          }
        }
      }
    } else {
      // 下拉关闭判定
      if (velocity > 1200 || _rawDy > 150) {
        widget.onDismiss();
      } else {
        _snapTo(0, false);
      }
    }
  }

  void _snapTo(double target, bool isSnapped) {
    _animController.stop();
    _dyAnimation = Tween<double>(begin: _rawDy, end: target).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _dyAnimation.addListener(() {
      setState(() {
        _rawDy = _dyAnimation.value;
        _updateControllerProgress();
      });
    });
    _animController.forward(from: 0.0).then((_) {
      if (mounted) {
        widget.controller.setIsSnappedToDetails(isSnapped);
      }
    });
  }

  void _updateControllerProgress() {
    final screenHeight = MediaQuery.of(context).size.height;
    
    // 获取抵顶所需的总位移
    final mediaSize = widget.controller.currentMediaSize ??
        Size(MediaQuery.of(context).size.width, screenHeight);
    double containScale =
        min(MediaQuery.of(context).size.width / mediaSize.width, screenHeight / mediaSize.height);
    double renderHeightAtContain = mediaSize.height * containScale;
    double initialTop = (screenHeight - renderHeightAtContain) / 2.0;

    if (_rawDy < 0) {
      // 这里的 progress 计算以 initialTop 为 1.0 进度
      double progress = (_rawDy / -initialTop).clamp(0.0, 2.0); 
      widget.controller.setInfoProgress(progress);
      widget.controller.updateOpacity(1.0);
    } else {
      double progress = (_rawDy / (screenHeight / 2)).clamp(0.0, 1.0);
      widget.controller.updateOpacity(1.0 - progress);
      widget.controller.setInfoProgress(0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final mediaSize =
        widget.controller.currentMediaSize ?? Size(screenWidth, screenHeight);

    // 1. 计算初始与目标状态
    double containScale = min(screenWidth / mediaSize.width, screenHeight / mediaSize.height);
    double renderHeightAtContain = mediaSize.height * containScale;
    double initialTop = (screenHeight - renderHeightAtContain) / 2.0;

    // 2. 变换参数计算
    // 在增量模式下，_rawDy 直接就是 UI 位移
    double upProgress = (_rawDy / -initialTop).clamp(0.0, 2.0);
    double downProgress = (_rawDy / (screenHeight * 0.5)).clamp(0.0, 1.0);

    // 关键：计算图片顶部在全屏坐标系中的相对 Alignment
    double topAlignmentY = (initialTop / (screenHeight / 2.0)) - 1.0;

    // BoxFit.cover 缩放因子
    double viewportW = screenWidth;
    double viewportH = screenHeight * 0.5;
    double scaleFactorW = viewportW / (mediaSize.width * containScale);
    double scaleFactorH = viewportH / (mediaSize.height * containScale);
    double targetScale = max(scaleFactorW, scaleFactorH);
    double detailScale = 1.0 + (targetScale - 1.0) * min(1.0, upProgress);

    // 3. 信息层参数
    double infoInitialTop = screenHeight;
    double infoTargetTop = screenHeight * 0.5;
    double infoTop = infoInitialTop - (infoInitialTop - infoTargetTop) * upProgress;
    double infoOpacity = pow(min(1.0, upProgress), 2.0).toDouble();

    return GestureDetector(
      onVerticalDragUpdate: _onVerticalDragUpdate,
      onVerticalDragEnd: _onVerticalDragEnd,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 层级 1: 黑色背景
          Container(
            color: Colors.black.withValues(alpha: widget.controller.opacity),
          ),

          // 层级 2: 图片层 (全屏驱动型容器)
          Positioned.fill(
            child: Transform.translate(
              offset: Offset(0, _rawDy),
              child: Transform.scale(
                scale: _rawDy < 0
                    ? detailScale
                    : (1.0 - (downProgress * 0.25)).clamp(0.75, 1.0),
                alignment: _rawDy < 0 ? Alignment(0, topAlignmentY) : Alignment.center,
                child: Opacity(
                  opacity: _rawDy < 0 ? 1.0 : widget.controller.opacity,
                  child: widget.child,
                ),
              ),
            ),
          ),

          // 层级 3: 详情层（压盖在图片之上）
          if (widget.infoLayer != null && _rawDy < 0)
            Positioned(
              top: infoTop,
              left: 0,
              right: 0,
              bottom: -screenHeight,
              child: Opacity(
                opacity: infoOpacity,
                child: Container(color: Colors.white, child: widget.infoLayer),
              ),
            ),
        ],
      ),
    );
  }
}
