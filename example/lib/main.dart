// YuniPhotoView 示例应用：入口为案例列表，点选进入各演示页。
import 'package:flutter/material.dart';

import 'cases/basic_case.dart';
import 'cases/comprehensive_case.dart';
import 'cases/custom_info_case.dart';
import 'cases/damping_case.dart';
import 'cases/desktop_custom_chrome_case.dart';
import 'cases/full_custom_bar_case.dart';
import 'cases/hero_case.dart';
import 'cases/hero_custom_case.dart';
import 'cases/mirrored_info_case.dart';
import 'cases/media_card_chrome_case.dart';
import 'cases/minimal_case.dart';
import 'cases/no_info_case.dart';
import 'cases/extensibility_case.dart';
import 'cases/paging_case.dart';

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

/// 主列表：展示各案例标题与说明，导航到对应演示界面。
class _CaseListPage extends StatelessWidget {
  const _CaseListPage();

  @override
  Widget build(BuildContext context) {
    final cases = <_CaseEntry>[
      _CaseEntry(
        title: '0. 综合案例',
        subtitle: 'Live 样式 + 长按/按钮播视频 + 顶底栏 + 上滑原图模拟',
        builder: (_) => const ComprehensiveCase(),
      ),
      _CaseEntry(
        title: '1. 主内容圆角边距',
        subtitle: '栏全显且未缩放时卡片外框；隐藏栏或放大后动画贴边（ViewerTheme）',
        builder: (_) => const MediaCardChromeCase(),
      ),
      _CaseEntry(
        title: '2. 基础用法',
        subtitle: '图片列表 + 默认 info + 默认顶栏',
        builder: (_) => const BasicCase(),
      ),
      _CaseEntry(
        title: '3. 最简集成',
        subtitle: '仅 pageBuilder，无 info/bar',
        builder: (_) => const MinimalCase(),
      ),
      _CaseEntry(
        title: '4. 自定义 Info 面板',
        subtitle: '丰富的 EXIF + 地图占位 + 长内容上滑',
        builder: (_) => const CustomInfoCase(),
      ),
      _CaseEntry(
        title: '5. 无 Info 页面',
        subtitle: 'hasInfo=false 时手势被禁用',
        builder: (_) => const NoInfoCase(),
      ),
      _CaseEntry(
        title: '6. 自定义顶/底栏',
        subtitle: '渐变顶栏、缩略图底栏、dismiss 透明联动',
        builder: (_) => const FullCustomBarCase(),
      ),
      _CaseEntry(
        title: '7. Hero 动画',
        subtitle: '图片专用 ViewerHero.image，共享元素平滑过渡',
        builder: (_) => const HeroCase(),
      ),
      _CaseEntry(
        title: '8. Hero 自定义 Widget',
        subtitle: '非图片卡片使用 ViewerHero.custom，也能正常 Hero',
        builder: (_) => const HeroCustomCase(),
      ),
      _CaseEntry(
        title: '9. 阻尼参数调试',
        subtitle: '实时滑块调整三类阻尼系数',
        builder: (_) => const DampingCase(),
      ),
      _CaseEntry(
        title: '10. Info 镜像同步',
        subtitle: 'infoSyncMode=mirrored，翻页保持展开',
        builder: (_) => const MirroredInfoCase(),
      ),
      _CaseEntry(
        title: '11. 桌面自定义控件条',
        subtitle: 'desktopChromeBuilder + 业务按钮示例（force 模式全平台可预览）',
        builder: (_) => const DesktopCustomChromeCase(),
      ),
      _CaseEntry(
        title: '12. 扩展性：插槽与动效魔改',
        subtitle: 'underMediaBuilder 立体投影、自定义 Duration 与特制 extra 水印',
        builder: (_) => const ExtensibilityCase(),
      ),
      _CaseEntry(
        title: '13. 异步分页加载',
        subtitle: 'onLoadMore 自动预加载（无限滚动效果）',
        builder: (_) => const PagingCase(),
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
            onTap: () =>
                Navigator.push(ctx, MaterialPageRoute(builder: c.builder)),
          );
        },
      ),
    );
  }
}

/// 列表中一条案例的标题、副标题与跳转构建器。
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
