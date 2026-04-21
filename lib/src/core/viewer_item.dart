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

  /// 业务扩展负载：允许开发者在 [ViewerItem] 中携带特定的业务元数据。
  /// [ViewerPageContext] 和 [ViewerBarContext] 会同步透传此字段。
  dynamic get extra => null;

  /// 是否启用手势缩放功能（双指捏合、双击缩放等）。
  ///
  /// 默认返回 `true` 以保持向后兼容性。子类可以覆盖此 getter 以提供自定义行为。
  ///
  /// 当返回 `false` 时，查看器系统将禁用该条目的手势缩放功能。
  bool get enableGestureScaling => true;

  @override
  String toString() => 'ViewerItem(id: $id, hasInfo: $hasInfo)';
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
    this.enableGestureScaling = true,
  }) : super();

  @override
  final String id;

  final String? kind;

  final dynamic payload;

  final Map<String, dynamic>? meta;

  final dynamic extra;

  @override
  final bool hasInfo;

  @override
  final bool enableGestureScaling;

  DefaultViewerItem copyWith({
    String? id,
    String? kind,
    dynamic payload,
    Map<String, dynamic>? meta,
    dynamic extra,
    bool? hasInfo,
    bool? enableGestureScaling,
  }) {
    return DefaultViewerItem(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      payload: payload ?? this.payload,
      meta: meta ?? this.meta,
      extra: extra ?? this.extra,
      hasInfo: hasInfo ?? this.hasInfo,
      enableGestureScaling: enableGestureScaling ?? this.enableGestureScaling,
    );
  }

  @override
  String toString() =>
      'DefaultViewerItem(id: $id, kind: $kind, hasInfo: $hasInfo, enableGestureScaling: $enableGestureScaling)';
}
