/// 主线程阻塞事件 / Main-thread blocking event
///
/// 一次"心跳超时"代表 UI isolate 在 [durationMs] 内没能响应心跳定时器，
/// 通常是同步重活（大 JSON 解析、密集 build）、锁等待或平台通道阻塞。
/// A heartbeat timeout means the UI isolate failed to answer the watchdog timer
/// for [durationMs] — usually a heavy synchronous task (big JSON parse, dense
/// build), a lock wait, or a blocked platform channel.
class BlockingEvent {
  /// 阻塞开始（上一次正常心跳时刻，即阻塞区间的近似起点）
  /// Blocking start (the last healthy heartbeat — approximate start of the stall)
  final DateTime startAt;

  /// 阻塞结束（恢复后第一次心跳时刻）/ Blocking end (first heartbeat after recovery)
  final DateTime endAt;

  /// 阻塞时长（毫秒）/ Blocking duration (ms)
  final int durationMs;

  /// 阻塞窗口附近的日志摘要，用于定位"卡在做什么"
  /// Log summaries around the stall window, to identify what was blocking
  final List<String> nearbyLogs;

  const BlockingEvent({
    required this.startAt,
    required this.endAt,
    required this.durationMs,
    this.nearbyLogs = const <String>[],
  });

  /// 时长文本（超过 1 秒用秒表示）/ Duration text (seconds above 1s)
  String get durationText => durationMs >= 1000
      ? '${(durationMs / 1000).toStringAsFixed(2)}s'
      : '${durationMs}ms';
}
