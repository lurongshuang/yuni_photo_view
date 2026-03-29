/// 查看器中的一条数据项抽象。
///
/// 框架只强依赖 [id]、[hasInfo]；其余字段由子类按需覆盖。
///
/// **快速接入**：使用 [DefaultViewerItem]，字段与旧版普通类一致。
///
/// **领域模型**：自定义 `class MyEntry extends ViewerItem`，实现 [id]、[hasInfo] 并覆盖 [payload] 等；
/// 在 [ViewerPageBuilder] 里用类型判断即可。
abstract class ViewerItem {
  /// 子类构造请使用 `super()`；抽象类本身不可直接 `ViewerItem()` 实例化。
  const ViewerItem();

  /// 唯一标识（Hero、列表 key、日志等）。
  String get id;

  /// 是否支持信息面板；为 `false` 时该页隐藏面板并关闭对应手势。
  bool get hasInfo;

  /// 可选类型提示（如 `image`、`video`），框架不解析。
  String? get kind => null;

  /// 通用载荷；默认 `null`，常用 [DefaultViewerItem] 或子类覆盖。
  Object? get payload => null;

  /// 键值元数据；默认 `null`。
  Map<String, dynamic>? get meta => null;

  /// 扩展字段；默认 `null`。
  Object? get extra => null;

  @override
  String toString() => 'ViewerItem(id: $id, kind: $kind, hasInfo: $hasInfo)';
}

/// 默认具体条目：适合 URL / meta 等通用字段的快速接入；可变副本用 [copyWith]。
class DefaultViewerItem extends ViewerItem {
  const DefaultViewerItem({
    required this.id,
    this.kind,
    this.payload,
    this.meta,
    this.extra,
    this.hasInfo = true,
  }) : super();

  @override
  final String id;

  @override
  final String? kind;

  @override
  final dynamic payload;

  @override
  final Map<String, dynamic>? meta;

  @override
  final dynamic extra;

  @override
  final bool hasInfo;

  DefaultViewerItem copyWith({
    String? id,
    String? kind,
    dynamic payload,
    Map<String, dynamic>? meta,
    dynamic extra,
    bool? hasInfo,
  }) {
    return DefaultViewerItem(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      payload: payload ?? this.payload,
      meta: meta ?? this.meta,
      extra: extra ?? this.extra,
      hasInfo: hasInfo ?? this.hasInfo,
    );
  }

  @override
  String toString() =>
      'DefaultViewerItem(id: $id, kind: $kind, hasInfo: $hasInfo)';
}
