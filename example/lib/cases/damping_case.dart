import 'package:flutter/material.dart';
import 'package:yuni_photo_view/yuni_photo_view.dart';

import '../utils/demo_data.dart';

/// Case 7 — Real-time damping tuning.
///
/// Demonstrates:
/// - Three sliders that update all three damping coefficients in real time.
/// - Viewer is opened with the current values each time.
/// - Great for understanding how damping feels.
class DampingCase extends StatefulWidget {
  const DampingCase({super.key});

  @override
  State<DampingCase> createState() => _DampingCaseState();
}

class _DampingCaseState extends State<DampingCase> {
  double _infoUp = 0.88;
  double _infoDown = 0.85;
  double _dismiss = 0.55;

  void _open(BuildContext context) {
    MediaViewer.open(
      context,
      items: DemoData.images,
      config: ViewerInteractionConfig(
        infoDragUpDamping: _infoUp,
        infoRestoreDownDamping: _infoDown,
        viewerDismissDownDamping: _dismiss,
      ),
      pageBuilder: (ctx, pageCtx) => ViewerMediaCoverFrame(
        revealProgress: pageCtx.infoRevealProgress,
        child: Image.network(pageCtx.item.payload as String),
      ),
      infoBuilder: (ctx, pageCtx) {
        final meta = pageCtx.item.meta ?? {};
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(meta['title'] ?? '',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('上滑阻尼: ${_infoUp.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.grey)),
              Text('下滑阻尼: ${_infoDown.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.grey)),
              Text('Dismiss 阻尼: ${_dismiss.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
      topBarBuilder: (ctx, _) => SafeArea(
        child: Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('阻尼参数调试')),
      body: Column(
        children: [
          const SizedBox(height: 16),
          _DampingSlider(
            label: 'infoDragUpDamping（info 上滑阻尼）',
            value: _infoUp,
            onChanged: (v) => setState(() => _infoUp = v),
          ),
          _DampingSlider(
            label: 'infoRestoreDownDamping（info 下滑还原阻尼）',
            value: _infoDown,
            onChanged: (v) => setState(() => _infoDown = v),
          ),
          _DampingSlider(
            label: 'viewerDismissDownDamping（Dismiss 阻尼）',
            value: _dismiss,
            onChanged: (v) => setState(() => _dismiss = v),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('使用当前参数打开查看器'),
                onPressed: () => _open(context),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _DampingSlider extends StatelessWidget {
  const _DampingSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(label,
                    style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ),
              const SizedBox(width: 8),
              Text(value.toStringAsFixed(2),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: value,
            min: 0.1,
            max: 1.0,
            divisions: 18,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
