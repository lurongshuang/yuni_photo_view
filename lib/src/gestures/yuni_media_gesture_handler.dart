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

  const YuniMediaGestureHandler({
    super.key,
    required this.child,
    required this.controller,
    required this.onDismiss,
    this.infoLayer,
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
      // 关键修复：如果在吸附态下下拉 (delta.dy > 0)，则强制解除吸附，
      // 并让 _rawDy 从最大阻尼负值开始向 0 偏移，从而实现“下拉回弹”。
      if (details.delta.dy > 0) {
        widget.controller.setIsSnappedToDetails(false);
        // 此处不 return，继续执行下面的 _rawDy 累加
      } else {
        return; // 上滑依然交给内部 ScrollView
      }
    }

    setState(() {
      _rawDy += details.delta.dy;
      // 限制 _rawDy，防止在吸附态下拉时瞬间跳变，给一个平滑感
      _updateControllerProgress();
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    // 即使被 snapped 也要判断，但逻辑上我们已经在 Update 里解除 snapped 了
    if (widget.controller.isSnappedToDetails) return;

    final screenHeight = MediaQuery.of(context).size.height;
    final velocity = details.velocity.pixelsPerSecond.dy;

    // 0.2 阻尼下的最大行程
    double damping = 0.2;
    double maxRawDy = -screenHeight * 0.5 / damping;

    if (_rawDy < 0) {
      // 上滑进度: 0.0 (全屏) -> 1.0 (详情)
      double upProgress = (_rawDy / maxRawDy).clamp(0.0, 1.0);

      // 关键修复：如果在详情态/半路位置快速向下划 (velocity > 800)，触发回弹至全屏
      if (velocity > 800) {
        _snapTo(0, false);
      }
      // 优化判定：超过 80% 进程，或极快地 flick 上滑才吸附
      else if (velocity < -1200 || upProgress > 0.8) {
        _snapTo(maxRawDy, true);
      } else {
        _snapTo(0, false);
      }
    } else {
      // 下滑关闭判定
      if (velocity > 800 || _rawDy > 150) {
        widget.onDismiss();
      } else {
        _snapTo(0, false);
      }
    }
  }

  void _snapTo(double target, bool isSnapped) {
    _dyAnimation = _animController.drive(
      Tween<double>(
        begin: _rawDy,
        end: target,
      ).chain(CurveTween(curve: Curves.easeOutQuart)),
    );
    _animController.reset();
    _animController.forward().then((_) {
      if (mounted) {
        widget.controller.setIsSnappedToDetails(isSnapped);
      }
    });
    _dyAnimation.addListener(() {
      setState(() {
        _rawDy = _dyAnimation.value;
        _updateControllerProgress();
      });
    });
  }

  void _updateControllerProgress() {
    final screenHeight = MediaQuery.of(context).size.height;
    double damping = 0.2;
    double maxRawDy = -screenHeight * 0.5 / damping;

    if (_rawDy < 0) {
      double progress = (_rawDy / maxRawDy).clamp(0.0, 2.0); // 允许略微超过 1.0 以支持压盖
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
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final mediaSize =
        widget.controller.currentMediaSize ?? Size(screenWidth, screenHeight);

    // --- 物理插值计算 ---
    double damping = 0.2;
    double uiOffset = _rawDy < 0 ? _rawDy * damping : _rawDy; 
    
    // 上滑进度: [_maxRawDy, 0] -> [1.0, 0.0]
    double maxRawDy = -screenHeight * 0.5 / damping;
    double upProgress = (_rawDy / maxRawDy).clamp(0.0, 2.0);
    
    // 下滑进度: [0, screenHeight/2] -> [0.0, 1.0]
    double downProgress = (_rawDy / (screenHeight / 2)).clamp(0.0, 1.0);

    // 1. 计算初始与目标状态
    double containScale = min(screenWidth / mediaSize.width, screenHeight / mediaSize.height);
    double renderHeightAtContain = mediaSize.height * containScale;
    double initialTop = (screenHeight - renderHeightAtContain) / 2.0;

    // 2. 关键：计算图片顶部在全屏坐标系中的相对 Alignment
    // (-1.0 为顶部, 0.0 为中心, 1.0 为底部)
    double topAlignmentY = (initialTop / (screenHeight / 2.0)) - 1.0;

    // 3. 变换参数计算
    // 最终位移：为了抵消初始居中位移，需要平移 -initialTop * upProgress
    double detailTranslateY = -initialTop * upProgress;
    
    // 4. BoxFit.cover 缩放因子
    double viewportW = screenWidth;
    double viewportH = screenHeight * 0.5;
    double scaleFactorW = viewportW / (mediaSize.width * containScale);
    double scaleFactorH = viewportH / (mediaSize.height * containScale);
    double targetScale = max(scaleFactorW, scaleFactorH);
    double detailScale = 1.0 + (targetScale - 1.0) * min(1.0, upProgress);

    // 5. 信息层参数
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
            child: _rawDy < 0
                ? Transform.translate(
                    offset: Offset(0, detailTranslateY),
                    child: Transform.scale(
                      scale: detailScale,
                      alignment: Alignment(0, topAlignmentY),
                      child: widget.child,
                    ),
                  )
                : Transform.translate(
                    offset: Offset(0, uiOffset),
                    child: Transform.scale(
                      scale: (1.0 - (downProgress * 0.25)).clamp(0.75, 1.0),
                      child: Opacity(
                        opacity: widget.controller.opacity,
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
