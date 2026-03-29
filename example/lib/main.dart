import 'package:flutter/material.dart';

import 'cases/basic_case.dart';
import 'cases/custom_info_case.dart';
import 'cases/damping_case.dart';
import 'cases/full_custom_bar_case.dart';
import 'cases/hero_case.dart';
import 'cases/mirrored_info_case.dart';
import 'cases/minimal_case.dart';
import 'cases/no_info_case.dart';

void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YuniPhotoView 示例',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const _CaseListPage(),
    );
  }
}

class _CaseListPage extends StatelessWidget {
  const _CaseListPage();

  @override
  Widget build(BuildContext context) {
    final cases = <_CaseEntry>[
      _CaseEntry(
        title: '1. 基础用法',
        subtitle: '图片列表 + 默认 info + 默认顶栏',
        builder: (_) => const BasicCase(),
      ),
      _CaseEntry(
        title: '2. 最简集成',
        subtitle: '仅 pageBuilder，无 info/bar',
        builder: (_) => const MinimalCase(),
      ),
      _CaseEntry(
        title: '3. 自定义 Info 面板',
        subtitle: '丰富的 EXIF + 地图占位 + 长内容上滑',
        builder: (_) => const CustomInfoCase(),
      ),
      _CaseEntry(
        title: '4. 无 Info 页面',
        subtitle: 'hasInfo=false 时手势被禁用',
        builder: (_) => const NoInfoCase(),
      ),
      _CaseEntry(
        title: '5. 自定义顶/底栏',
        subtitle: '渐变顶栏、缩略图底栏、dismiss 透明联动',
        builder: (_) => const FullCustomBarCase(),
      ),
      _CaseEntry(
        title: '6. Hero 动画',
        subtitle: '从列表缩略图进入，返回时 Hero 回程',
        builder: (_) => const HeroCase(),
      ),
      _CaseEntry(
        title: '7. 阻尼参数调试',
        subtitle: '实时滑块调整三类阻尼系数',
        builder: (_) => const DampingCase(),
      ),
      _CaseEntry(
        title: '8. Info 镜像同步',
        subtitle: 'infoSyncMode=mirrored，翻页保持展开',
        builder: (_) => const MirroredInfoCase(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('YuniPhotoView 示例'),
        centerTitle: true,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: cases.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
        itemBuilder: (ctx, i) {
          final c = cases[i];
          return ListTile(
            title: Text(c.title,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(c.subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(ctx, MaterialPageRoute(builder: c.builder)),
          );
        },
      ),
    );
  }
}

class _CaseEntry {
  const _CaseEntry({
    required this.title,
    required this.subtitle,
    required this.builder,
  });

  final String title;
  final String subtitle;
  final WidgetBuilder builder;
}
