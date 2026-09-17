import 'package:flutter_test/flutter_test.dart';
import 'package:zero_inspector_kit/zero_inspector_kit.dart';

void main() {
  final base = DateTime.now().millisecondsSinceEpoch;

  NetworkRequest netAt(int offsetMs) => NetworkRequest(
    id: 'net-$offsetMs',
    method: 'GET',
    url: 'https://example.com/api/$offsetMs',
    requestTime: base + offsetMs,
  );

  LogEntry logAt(int offsetMs) => LogEntry(
    id: 'log-$offsetMs',
    level: LogLevel.info,
    message: 'message $offsetMs',
    timestamp: DateTime.fromMillisecondsSinceEpoch(base + offsetMs),
    tag: 'timeline-test',
  );

  RouteEntry routeAt(int offsetMs) => RouteEntry(
    id: 'route-$offsetMs',
    routeName: '/page-$offsetMs',
    timestamp: DateTime.fromMillisecondsSinceEpoch(base + offsetMs),
    action: RouteAction.push,
  );

  setUp(() {
    InspectorService.instance.clearAll();
    ErrorService.instance.clear();
    AlertService.instance.clearAll();
  });

  test('build() merges every source newest-first', () {
    InspectorService.instance
      ..addNetworkRequest(netAt(0))
      ..addRouteEntry(routeAt(500))
      ..addLogEntry(logAt(1000));

    final events = TimelineService.instance.build();

    expect(events.length, 3);
    expect(events.map((e) => e.kind).toList(), [
      TimelineEventKind.log,
      TimelineEventKind.route,
      TimelineEventKind.network,
    ]);
    // 标题带上方法与路由名，便于在列表里一眼识别 / Titles carry method / route name
    expect(events[2].title, contains('GET'));
    expect(events[1].title, contains('/page-500'));
  });

  test('build() honours the kind filter', () {
    InspectorService.instance
      ..addNetworkRequest(netAt(0))
      ..addLogEntry(logAt(1000));

    final onlyNetwork = TimelineService.instance.build(
      kinds: {TimelineEventKind.network},
    );
    expect(onlyNetwork.length, 1);
    expect(onlyNetwork.single.kind, TimelineEventKind.network);
  });

  test('build() includes errors and alerts', () {
    ErrorService.instance.report(StateError('boom'), StackTrace.current);
    AlertService.instance.restore([
      AlertEvent(source: 'memory', message: '512 MB used'),
    ]);

    final events = TimelineService.instance.build();

    expect(
      events.map((e) => e.kind),
      containsAll([TimelineEventKind.error, TimelineEventKind.alert]),
    );
    final alert = events.firstWhere((e) => e.kind == TimelineEventKind.alert);
    expect(alert.title, '512 MB used');
    expect(alert.subtitle, 'memory');
  });

  test('build() returns an empty list when nothing was captured', () {
    expect(TimelineService.instance.build(), isEmpty);
  });

  test('contextAround() keeps only the window, oldest-first', () {
    // 网络在 0ms、路由在 500ms、日志在 1000ms；聚焦路由 ±400ms → [100, 900]，
    // 网络与日志都被裁掉，只留 route。验证窗口裁剪真的生效。
    // Network at 0ms, route at 500ms, log at 1000ms; focusing the route with a
    // ±400ms window → [100, 900], so both neighbors are clipped and only the
    // route remains. Verifies the window clipping actually works.
    InspectorService.instance
      ..addNetworkRequest(netAt(0))
      ..addRouteEntry(routeAt(500))
      ..addLogEntry(logAt(1000));

    final anchor = TimelineService.instance
        .build(kinds: {TimelineEventKind.route})
        .single;
    final context = TimelineService.instance.contextAround(
      anchor,
      window: const Duration(milliseconds: 400),
    );

    expect(context.map((e) => e.kind).toList(), [TimelineEventKind.route]);
  });

  test('contextAround() widens to cover everything at ±10s', () {
    InspectorService.instance
      ..addNetworkRequest(netAt(0))
      ..addRouteEntry(routeAt(500))
      ..addLogEntry(logAt(1000));

    final anchor = TimelineService.instance
        .build(kinds: {TimelineEventKind.route})
        .single;
    final context = TimelineService.instance.contextAround(anchor);

    expect(context.length, 3);
    // 正序：早 → 晚 / Oldest first
    expect(context.first.timestamp.isBefore(context.last.timestamp), isTrue);
  });

  test('event key is stable per record and time text is HH:mm:ss.SSS', () {
    InspectorService.instance.addNetworkRequest(netAt(0));
    final first = TimelineService.instance.build().single;
    final second = TimelineService.instance.build().single;

    // 归并每次都重建事件对象，展开态必须依赖 key 而非对象身份。
    // Events are rebuilt on every merge, so expansion state relies on the key,
    // never on object identity.
    expect(first.key, second.key);
    expect(
      RegExp(r'^\d{2}:\d{2}:\d{2}\.\d{3}$').hasMatch(first.timeText),
      isTrue,
    );
  });
}
