import 'package:flutter/material.dart';
import 'package:yuni_photo_view/yuni_photo_view.dart';
import '../utils.dart';

class CustomInfoGallery extends StatelessWidget {
  const CustomInfoGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final items = generateItems(10, YuniMediaType.image);
    return Scaffold(
      appBar: AppBar(title: const Text('自定义详情')),
      body: buildGrid(context, items, 'cus_'),
    );
  }
}
