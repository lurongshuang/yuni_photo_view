import 'package:flutter/material.dart';
import 'package:yuni_photo_view/yuni_photo_view.dart';
import '../utils.dart';

class StandardGallery extends StatelessWidget {
  const StandardGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final items = generateItems(10, YuniMediaType.image);
    return Scaffold(
      appBar: AppBar(title: const Text('标准图片画廊')),
      body: buildGrid(context, items, 'std_'),
    );
  }
}
