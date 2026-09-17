/// 统一时间线的事件来源 / Event source on the unified timeline
///
/// 对应面板里已有的五类数据：网络 / 日志 / 异常 / 路由 / 告警。
/// Mirrors the five data categories already in the panel: network / log /
/// error / route / alert.
enum TimelineEventKind { network, log, error, route, alert }

/// [TimelineEventKind] 的展示文本 / Display text for [TimelineEventKind]
extension TimelineEventKindText on TimelineEventKind {
  /// 来源短标签（列表 chip 用）/ Short source label (list chip)
  String get label {
    switch (this) {
      case TimelineEventKind.network:
        return 'NET';
      case TimelineEventKind.log:
        return 'LOG';
      case TimelineEventKind.error:
        return 'ERR';
      case TimelineEventKind.route:
        return 'ROUTE';
      case TimelineEventKind.alert:
        return 'ALERT';
    }
  }
}

/// 统一时间线事件 / Unified timeline event
///
/// 把网络请求、日志、异常、路由与告警归一成同一种记录，从而能回答
/// 「这个请求的前后还发生了什么」——这是单个标签页无法回答的问题。
/// Normalizes network requests, logs, errors, routes and alerts into one record
/// type so the panel can answer "what else happened around this request?" —
/// something no single tab can answer.
class TimelineEvent {
  /// 事件来源 / Event source
  final TimelineEventKind kind;

  /// 事件时间 / Event timestamp
  final DateTime timestamp;

  /// 主标题（单行展示，UI 负责截断）/ Main title (single line; UI truncates)
  final String title;

  /// 副标题（可选）/ Optional subtitle
  final String? subtitle;

  /// 完整详情（展开后展示）/ Full detail (shown when expanded)
  final String detail;

  /// 原始记录 id（用于回查原数据，可为空）/ Source record id (may be null)
  final String? sourceId;

  const TimelineEvent({
    required this.kind,
    required this.timestamp,
    required this.title,
    this.subtitle,
    this.detail = '',
    this.sourceId,
  });

  /// 展开态的稳定 key：事件对象每次归并都重建，不能用对象身份做展开态标识。
  /// Stable key for expansion state: events are rebuilt on every merge, so
  /// object identity cannot identify an expanded row.
  String get key =>
      '${kind.name}|${sourceId ?? ''}|${timestamp.microsecondsSinceEpoch}';

  /// 时间文本（HH:mm:ss.SSS）/ Time text (HH:mm:ss.SSS)
  String get timeText {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(timestamp.hour)}:${two(timestamp.minute)}:${two(timestamp.second)}'
        '.${timestamp.millisecond.toString().padLeft(3, '0')}';
  }
}
