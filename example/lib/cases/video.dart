import 'package:flutter/material.dart';
import 'package:yuni_photo_view/yuni_photo_view.dart';
import '../utils.dart';

class VideoGallery extends StatelessWidget {
  const VideoGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final items = generateItems(5, YuniMediaType.video);
    return Scaffold(
      appBar: AppBar(title: const Text('视频模拟')),
      body: buildGrid(context, items, 'vid_'),
    );
  }
}
