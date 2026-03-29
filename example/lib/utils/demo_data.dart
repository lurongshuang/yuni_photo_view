import 'package:yuni_photo_view/yuni_photo_view.dart';

/// 各示例共用的演示数据（网络图片与视频 URL）。
class DemoData {
  DemoData._();

  /// 横图、竖图、方图混合的网络图片列表，用于多数案例。
  static const List<ViewerItem> images = [
    ViewerItem(
      id: 'img_1',
      kind: 'image',
      payload: 'https://picsum.photos/seed/yuniA/1200/800',
      meta: {
        'title': '山间日落',
        'date': '2026-03-27 22:25',
        'location': '北京市，顺义区，信中北街',
        'size': '649 KB',
        'resolution': '3000×4000',
        'device': 'Galaxy S25+',
        'lens': '广角镜头 · 23mm',
        'iso': '2500',
        'focalLength': '67mm',
        'ev': '0.0 ev',
        'aperture': 'f/1.8',
        'shutter': '1/17 s',
      },
    ),
    ViewerItem(
      id: 'img_2',
      kind: 'image',
      payload: 'https://picsum.photos/seed/yuniB/800/1200',
      meta: {
        'title': '城市夜景',
        'date': '2026-03-26 21:10',
        'location': '上海市，浦东新区',
        'size': '1.2 MB',
        'resolution': '4000×3000',
        'device': 'iPhone 15 Pro',
        'lens': '主摄 · 24mm',
        'iso': '800',
        'focalLength': '24mm',
        'ev': '-0.3 ev',
        'aperture': 'f/1.78',
        'shutter': '1/60 s',
      },
    ),
    ViewerItem(
      id: 'img_3',
      kind: 'image',
      payload: 'https://picsum.photos/seed/yuniC/1000/1000',
      meta: {
        'title': '海边黄昏',
        'date': '2026-03-25 18:44',
        'location': '广东省，深圳市，海边公园',
        'size': '874 KB',
        'resolution': '3024×3024',
        'device': 'Google Pixel 9',
        'lens': '标准 · 25mm',
        'iso': '64',
        'focalLength': '25mm',
        'ev': '+0.7 ev',
        'aperture': 'f/1.68',
        'shutter': '1/800 s',
      },
    ),
    ViewerItem(
      id: 'img_4',
      kind: 'image',
      payload: 'https://picsum.photos/seed/yuniD/1600/900',
      meta: {
        'title': '草原晨雾',
        'date': '2026-03-20 06:30',
        'location': '内蒙古，呼伦贝尔',
        'size': '2.1 MB',
        'resolution': '4032×2268',
        'device': 'Galaxy S25+',
        'lens': '长焦 · 70mm',
        'iso': '200',
        'focalLength': '70mm',
        'ev': '+0.3 ev',
        'aperture': 'f/2.0',
        'shutter': '1/250 s',
      },
    ),
    ViewerItem(
      id: 'img_5',
      kind: 'image',
      payload: 'https://picsum.photos/seed/yuniE/900/1600',
      meta: {
        'title': '秋叶飘落',
        'date': '2026-10-15 14:22',
        'location': '浙江省，杭州市，西湖',
        'size': '1.5 MB',
        'resolution': '2268×4032',
        'device': 'iPhone 15 Pro Max',
        'lens': '超广角 · 13mm',
        'iso': '100',
        'focalLength': '13mm',
        'ev': '0.0 ev',
        'aperture': 'f/2.2',
        'shutter': '1/500 s',
      },
    ),
    // 无 Info 的一条：用于演示该页上滑信息手势被关闭。
    ViewerItem(
      id: 'img_6',
      kind: 'image',
      payload: 'https://picsum.photos/seed/yuniF/1200/675',
      hasInfo: false,
    ),
  ];

  /// 与 [images] 相同，但全部 `hasInfo: false`（用于「纯无 Info」对比时可复用）。
  static List<ViewerItem> get noInfoImages =>
      images.map((e) => e.copyWith(hasInfo: false)).toList();

  /// 综合案例专用：普通图 + Live 样式（仅 meta，无真实 .livp）+ 可模拟「查看原图」。
  static List<ViewerItem> get comprehensiveItems => [
        images[0].copyWith(
          meta: {
            ...?images[0].meta,
            'title': '普通照片',
            'hasOriginal': true,
            'previewUrl': images[0].payload,
            'hdUrl': 'https://picsum.photos/seed/yuniA_hd/2400/1600',
          },
        ),
        const ViewerItem(
          id: 'live_demo',
          kind: 'image',
          payload: 'https://picsum.photos/seed/liveCover/900/1200',
          meta: {
            'title': 'Live Photo（样式演示）',
            'date': '2026-03-28 10:00',
            'location': '演示位置',
            'size': '2.4 MB',
            'resolution': '3024×4032',
            // 业务约定：有 Live 样式 + 配套视频 URL（解析与解码在业务侧）
            'livePhoto': true,
            'motionUrl': 'https://www.w3schools.com/html/mov_bbb.mp4',
            'hasOriginal': false,
          },
        ),
        images[2].copyWith(
          meta: {
            ...?images[2].meta,
            'title': '另一张（含原图）',
            'hasOriginal': true,
            'previewUrl': images[2].payload,
            'hdUrl': 'https://picsum.photos/seed/yuniC_hd/2000/2000',
          },
        ),
      ];

  /// 视频类 [ViewerItem] 示例（画面由业务用 pageBuilder 渲染，插件只提供壳）。
  static const List<ViewerItem> videos = [
    ViewerItem(
      id: 'vid_1',
      kind: 'video',
      payload: 'https://www.w3schools.com/html/mov_bbb.mp4',
      meta: {'title': '示例视频 1', 'duration': '0:10'},
      hasInfo: true,
    ),
    ViewerItem(
      id: 'vid_2',
      kind: 'video',
      payload: 'https://www.w3schools.com/html/movie.mp4',
      meta: {'title': '示例视频 2', 'duration': '0:07'},
      hasInfo: false,
    ),
  ];
}
