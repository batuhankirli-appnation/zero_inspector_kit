import '../models/error_record.dart';
import '../models/log_entry.dart';
import '../models/network_request.dart';
import '../models/route_entry.dart';
import '../models/timeline_event.dart';
import 'alert_service.dart';
import 'error_service.dart';
import 'inspector_service.dart';

/// 统一会话时间线服务 / Unified session timeline service
///
/// 把已有的五类数据（网络 / 日志 / 异常 / 路由 / 告警）按时间归并成一条流，
/// 让面板能回答「这个请求前后还发生了什么」——单个标签页做不到这件事。
/// Merges the five existing data categories (network / log / error / route /
/// alert) into one time-ordered stream so the panel can answer "what else
/// happened around this request?" — no single tab can.
///
/// 无状态设计：不常驻监听任何 notifier，只在 UI 需要时归并一次（由 Timeline
/// Viewer 在数据变化通知后重算）。这样面板未打开时零开销，也避免服务成为
/// 数据所有者的第二份真相（数据仍各自归属原服务）。
/// Stateless by design: it listens to nothing and merges only when the UI asks
/// (the timeline viewer recomputes after a data-change notification). Zero cost
/// while the panel is closed, and no second source of truth — data still lives
/// in its own service.
class TimelineService {
  TimelineService._();

  /// 单例实例 / Singleton instance
  static final TimelineService instance = TimelineService._();

  /// 归并结果默认上限（避免长会话下列表过长）/ Default merge cap
  static const int defaultLimit = 800;

  /// 上下文窗口默认时长 / Default context window
  static const Duration defaultContextWindow = Duration(seconds: 10);

  /// 上下文查询时的扫描上限（需覆盖全部在库数据）/ Scan cap for context queries
  static const int _contextScanLimit = 4000;

  /// 归并全部来源，按时间**倒序**（最新在前）。
  /// Merge every source, **newest first**.
  ///
  /// [kinds] 为空表示全部来源；[limit] 限制返回条数。
  /// A null [kinds] means every source; [limit] caps the result.
  List<TimelineEvent> build({
    Set<TimelineEventKind>? kinds,
    int limit = defaultLimit,
  }) {
    final enabled = kinds ?? TimelineEventKind.values.toSet();
    final events = <TimelineEvent>[];
    final inspector = InspectorService.instance;

    if (enabled.contains(TimelineEventKind.network)) {
      for (final r in inspector.networkRequests) {
        events.add(_fromNetwork(r));
      }
    }
    if (enabled.contains(TimelineEventKind.log)) {
      for (final l in inspector.logEntries) {
        events.add(_fromLog(l));
      }
    }
    if (enabled.contains(TimelineEventKind.route)) {
      for (final r in inspector.routeEntries) {
        events.add(_fromRoute(r));
      }
    }
    if (enabled.contains(TimelineEventKind.error)) {
      for (final e in ErrorService.instance.errors) {
        events.add(_fromError(e));
      }
    }
    if (enabled.contains(TimelineEventKind.alert)) {
      for (final a in AlertService.instance.events) {
        events.add(_fromAlert(a));
      }
    }

    events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (events.length > limit) return events.sublist(0, limit);
    return events;
  }

  /// 取 [anchor] 前后 [window] 内的事件，按时间**正序**（从早到晚，像讲故事）。
  /// Events within ±[window] of [anchor], **oldest first** (reads like a story).
  ///
  /// 这是时间线的核心价值：点任意一条事件，只保留它前后若干秒的全部来源事件，
  /// 一眼看清因果（例如"路由跳转 → 两个请求 → 一条 error 日志 → 5xx 告警"）。
  /// This is the point of the timeline: focus one event and keep only the
  /// surrounding seconds across all sources, so causality is visible at a glance
  /// (e.g. "route push → two requests → an error log → a 5xx alert").
  List<TimelineEvent> contextAround(
    TimelineEvent anchor, {
    Duration window = defaultContextWindow,
    Set<TimelineEventKind>? kinds,
  }) {
    final all = build(kinds: kinds, limit: _contextScanLimit);
    final start = anchor.timestamp.subtract(window);
    final end = anchor.timestamp.add(window);
    final inWindow =
        all
            .where(
              (e) => !e.timestamp.isBefore(start) && !e.timestamp.isAfter(end),
            )
            .toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return inWindow;
  }

  /// 网络请求 → 时间线事件 / Network request → timeline event
  static TimelineEvent _fromNetwork(NetworkRequest r) {
    final status = r.statusCode?.toString() ?? '--';
    return TimelineEvent(
      kind: TimelineEventKind.network,
      timestamp: DateTime.fromMillisecondsSinceEpoch(r.requestTime),
      title: '${r.method} $status · ${r.url}',
      subtitle: r.durationText == '-' ? null : r.durationText,
      detail:
          '${r.method} ${r.url}\nstatus: $status\nduration: ${r.durationText}',
      sourceId: r.id,
    );
  }

  /// 日志 → 时间线事件 / Log entry → timeline event
  static TimelineEvent _fromLog(LogEntry l) {
    final firstLine = l.message.split('\n').first.trim();
    return TimelineEvent(
      kind: TimelineEventKind.log,
      timestamp: l.timestamp,
      title: firstLine.isEmpty ? '(empty message)' : firstLine,
      subtitle: l.tag != null ? '${l.levelText} · ${l.tag}' : l.levelText,
      detail: l.message,
      sourceId: l.id,
    );
  }

  /// 异常聚合 → 时间线事件 / Aggregated error → timeline event
  static TimelineEvent _fromError(ErrorRecord e) {
    return TimelineEvent(
      kind: TimelineEventKind.error,
      timestamp: e.lastSeen,
      title: e.count > 1 ? '${e.type} ×${e.count}' : e.type,
      subtitle: e.message,
      detail: e.sampleStack ?? e.message,
      sourceId: e.id,
    );
  }

  /// 路由 → 时间线事件 / Route entry → timeline event
  static TimelineEvent _fromRoute(RouteEntry r) {
    return TimelineEvent(
      kind: TimelineEventKind.route,
      timestamp: r.timestamp,
      title: '${r.actionText} · ${r.routeName}',
      subtitle: r.arguments == null || r.arguments!.isEmpty
          ? null
          : 'args: ${r.arguments!.keys.join(', ')}',
      detail: r.arguments?.toString() ?? 'no arguments',
      sourceId: r.id,
    );
  }

  /// 告警 → 时间线事件 / Alert event → timeline event
  static TimelineEvent _fromAlert(AlertEvent a) {
    return TimelineEvent(
      kind: TimelineEventKind.alert,
      timestamp: a.time,
      title: a.message,
      subtitle: a.source,
      detail: '${a.source}\n${a.message}',
    );
  }
}
