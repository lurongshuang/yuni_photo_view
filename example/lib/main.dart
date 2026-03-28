import 'package:flutter/material.dart';
import 'cases/standard.dart';
import 'cases/video.dart';
import 'cases/minimal.dart';
import 'cases/custom_info.dart';
import 'cases/damping_test.dart';

void main() {
  runApp(const MaterialApp(home: HomePage()));
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yuni Photo View 多维度测试')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTestTile(
            context,
            '标准图片画廊',
            '支持 Hero 动画、上滑详情、常规 Overlay',
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StandardGallery())),
          ),
          _buildTestTile(
            context,
            '模拟视频播放器',
            '演示如何扩展自定义媒体渲染器 (Video Mock)',
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VideoGallery())),
          ),
          _buildTestTile(
            context,
            '极简阅读模式',
            '无 Overlay，无详情层，纯粹的沉浸式体验',
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MinimalGallery())),
          ),
          _buildTestTile(
            context,
            '自定义深色详情页',
            '演示不同风格的 Info Layer 布局',
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomInfoGallery())),
          ),
          _buildTestTile(
            context,
            '阻尼手感自定义测试',
            '实时调节并体验上滑/下滑的不同物理阻尼 (upDamping, downDamping)',
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DampingTestGallery())),
          ),
        ],
      ),
    );
  }

  Widget _buildTestTile(BuildContext context, String title, String subtitle, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
