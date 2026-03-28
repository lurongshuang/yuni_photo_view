import 'package:flutter/foundation.dart';

/// 媒体类型的枚举
enum YuniMediaType {
  image,
  video,
  pdf,
  doc,
  other,
}

/// 媒体项的基础抽象类
/// 插件的使用者需要继承此类或直接使用此类的实现
@immutable
abstract class YuniMediaItem {
  final String id;
  final YuniMediaType mediaType;
  
  /// 可选的原始数据，供使用者在回调中自由使用
  final dynamic rawData;

  const YuniMediaItem({
    required this.id,
    required this.mediaType,
    this.rawData,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is YuniMediaItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// 默认的媒体项实现
class YuniMediaItemImpl extends YuniMediaItem {
  final String? url;
  final String? thumbnailUrl;
  final double? width;
  final double? height;

  const YuniMediaItemImpl({
    required super.id,
    required super.mediaType,
    super.rawData,
    this.url,
    this.thumbnailUrl,
    this.width,
    this.height,
  });
}
