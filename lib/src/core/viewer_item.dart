/// A single item in the viewer.
///
/// The framework only carries business data here.
/// All content rendering is delegated to [pageBuilder].
class ViewerItem {
  const ViewerItem({
    required this.id,
    this.kind,
    this.payload,
    this.meta,
    this.extra,
    this.hasInfo = true,
  });

  /// Unique identifier for this item.
  final String id;

  /// Optional type hint ('image', 'video', 'file', etc.).
  /// Purely informational — the framework never inspects this.
  final String? kind;

  /// Any business-specific data (url, file path, model, etc.).
  final dynamic payload;

  /// Key/value metadata (EXIF, size, date, …).
  final Map<String, dynamic>? meta;

  /// Arbitrary extra data passed through to builders.
  final dynamic extra;

  /// Whether this item supports the info sheet gesture.
  /// When [false], the info panel is hidden and its gesture is disabled.
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
