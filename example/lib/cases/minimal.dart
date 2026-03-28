import 'package:flutter/material.dart';
import 'package:yuni_photo_view/yuni_photo_view.dart';
import '../utils.dart';

class MinimalGallery extends StatelessWidget {
  const MinimalGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final items = generateItems(10, YuniMediaType.image);
    return Scaffold(
      appBar: AppBar(title: const Text('极简模式')),
      body: buildGrid(context, items, 'min_', minimal: true),
    );
  }
}
