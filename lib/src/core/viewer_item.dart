/// 查看器中的一条数据项。
///
/// 框架只承载业务数据，具体画面全部由 [ViewerPageBuilder] 渲染。
class ViewerItem {
  const ViewerItem({
    required this.id,
    this.kind,
    this.payload,
    this.meta,
    this.extra,
    this.hasInfo = true,
  });

  /// 唯一标识。
  final String id;

  /// 可选类型提示（如 `image`、`video`、`file`），仅供业务使用，框架不解析。
  final String? kind;

  /// 业务自定义载荷（URL、路径、模型等）。
  final dynamic payload;

  /// 键值元数据（如 EXIF、尺寸、日期）。
  final Map<String, dynamic>? meta;

  /// 任意扩展字段，原样传给各 Builder。
  final dynamic extra;

  /// 是否支持上滑信息面板。为 `false` 时该页隐藏面板并关闭对应手势。
  final bool hasInfo;

  ViewerItem copyWith({
    String? id,
    String? kind,
    dynamic payload,
    Map<String, dynamic>? meta,
    dynamic extra,
    bool? hasInfo,
  }) {
    return ViewerItem(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      payload: payload ?? this.payload,
      meta: meta ?? this.meta,
      extra: extra ?? this.extra,
      hasInfo: hasInfo ?? this.hasInfo,
    );
  }

  @override
  String toString() => 'ViewerItem(id: $id, kind: $kind, hasInfo: $hasInfo)';
}
