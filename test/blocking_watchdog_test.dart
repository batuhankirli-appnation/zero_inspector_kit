import 'package:flutter_test/flutter_test.dart';
import 'package:zero_inspector_kit/zero_inspector_kit.dart';

void main() {
  late BlockingWatchdogService service;

  setUp(() {
    service = BlockingWatchdogService.instance..stop();
    // 阈值是单例状态，先复位为默认值，避免上一个用例的自定义阈值泄漏过来。
    // The threshold is singleton state; reset it so a custom value from a
    // previous test cannot leak into the next one.
    service.start(thresholdMs: BlockingWatchdogService.defaultThresholdMs);
    service.stop();
    service.clear();
  });

  tearDown(() {
    service.stop();
    service.clear();
  });

  test('is off by default', () {
    expect(service.isRunning, isFalse);
    expect(service.events, isEmpty);
    expect(service.thresholdMs, BlockingWatchdogService.defaultThresholdMs);
  });

  test('the first heartbeat never counts as blocking', () {
    service.handleTick(DateTime.fromMillisecondsSinceEpoch(1000));
    expect(service.events, isEmpty);
  });

  test('a gap below the threshold is ignored', () {
    final t0 = DateTime.fromMillisecondsSinceEpoch(1000);
    service.handleTick(t0);
    service.handleTick(t0.add(const Duration(milliseconds: 120)));
    expect(service.events, isEmpty);
  });

  test('a gap at or above the threshold is recorded', () {
    final t0 = DateTime.fromMillisecondsSinceEpoch(1000);
    final t1 = t0.add(const Duration(milliseconds: 850));
    service.handleTick(t0);
    service.handleTick(t1);

    expect(service.eventCount, 1);
    final event = service.events.single;
    expect(event.durationMs, 850);
    expect(event.startAt, t0);
    expect(event.endAt, t1);
    expect(event.durationText, '850ms');
  });

  test('durations above one second are formatted in seconds', () {
    final t0 = DateTime.fromMillisecondsSinceEpoch(1000);
    service.handleTick(t0);
    service.handleTick(t0.add(const Duration(milliseconds: 1800)));
    expect(service.events.single.durationText, '1.80s');
  });

  test('nearby logs are attached to the blocking record', () {
    final t0 = DateTime.fromMillisecondsSinceEpoch(1000);
    InspectorService.instance.clearAll();
    InspectorService.instance.addLogEntry(
      LogEntry(
        id: 'near-1',
        level: LogLevel.info,
        message: 'parsing a huge payload',
        timestamp: t0.add(const Duration(milliseconds: 100)),
        tag: 'watchdog-test',
      ),
    );

    service.handleTick(t0);
    service.handleTick(t0.add(const Duration(milliseconds: 600)));

    expect(service.events.single.nearbyLogs, isNotEmpty);
    expect(service.events.single.nearbyLogs.first, contains('huge payload'));
    InspectorService.instance.clearAll();
  });

  test('the record ring caps at 50 entries', () {
    var now = DateTime.fromMillisecondsSinceEpoch(1000);
    service.handleTick(now);
    for (var i = 0; i < 80; i++) {
      now = now.add(const Duration(milliseconds: 500));
      service.handleTick(now);
    }
    expect(service.eventCount, 50);
    expect(service.longestBlockingMs, 500);
  });

  test('start/stop toggle the heartbeat and clear() empties records', () {
    service.start();
    expect(service.isRunning, isTrue);
    // 重复 start 不应重置已有记录 / Re-starting must not drop existing records
    final t0 = DateTime.fromMillisecondsSinceEpoch(1000);
    service.handleTick(t0);
    service.handleTick(t0.add(const Duration(milliseconds: 400)));
    expect(service.eventCount, 1);

    service.start();
    expect(service.eventCount, 1);

    service.clear();
    expect(service.eventCount, 0);

    service.stop();
    expect(service.isRunning, isFalse);
  });

  test('start() accepts a custom threshold', () {
    service.start(thresholdMs: 1000);
    expect(service.thresholdMs, 1000);

    final t0 = DateTime.fromMillisecondsSinceEpoch(1000);
    service.handleTick(t0);
    service.handleTick(t0.add(const Duration(milliseconds: 500)));
    expect(service.events, isEmpty, reason: '500ms is below the 1000ms bar');
  });
}
