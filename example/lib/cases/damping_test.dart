import 'package:flutter/material.dart';
import 'package:yuni_photo_view/yuni_photo_view.dart';
import '../utils.dart';

class DampingTestGallery extends StatefulWidget {
  const DampingTestGallery({super.key});

  @override
  State<DampingTestGallery> createState() => _DampingTestGalleryState();
}

class _DampingTestGalleryState extends State<DampingTestGallery> {
  double _infoShowDamping = 0.2;
  double _infoHideDamping = 0.5;
  double _dismissDamping = 1.0;

  @override
  Widget build(BuildContext context) {
    final items = generateItems(12, YuniMediaType.image);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('精细三态阻尼测试'),
      ),
      body: Column(
        children: [
          _buildControlPanel(),
          const Divider(height: 1),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index] as YuniMediaItemImpl;
                return YuniMediaHeroWrapper(
                  heroTag: 'damping_${item.id}',
                  onTap: () => openViewer(
                    context, 
                    items, 
                    index, 
                    'damping_', 
                    infoShowDamping: _infoShowDamping,
                    infoHideDamping: _infoHideDamping,
                    dismissDamping: _dismissDamping,
                  ),
                  child: Container(
                    color: Colors.grey[200],
                    child: Image.network(item.thumbnailUrl!, fit: BoxFit.cover),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blueGrey[50],
      child: Column(
        children: [
          _buildSliderRow(
            '展开阻尼 (infoShow)', 
            '上划显示详情时的阻力',
            _infoShowDamping, 
            0.05, 
            1.0, 
            (val) => setState(() => _infoShowDamping = val),
          ),
          const SizedBox(height: 12),
          _buildSliderRow(
            '收回阻尼 (infoHide)', 
            '从详情下划收回时的阻力',
            _infoHideDamping, 
            0.05, 
            1.0, 
            (val) => setState(() => _infoHideDamping = val),
          ),
          const SizedBox(height: 12),
          _buildSliderRow(
            '返回阻尼 (dismiss)', 
            '全屏下划关闭整体时的阻力',
            _dismissDamping, 
            0.1, 
            2.0, 
            (val) => setState(() => _dismissDamping = val),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderRow(String title, String subtitle, double value, double min, double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(value.toStringAsFixed(2), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          ],
        ),
        Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
