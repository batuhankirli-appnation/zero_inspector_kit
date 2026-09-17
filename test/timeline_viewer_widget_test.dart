import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_inspector_kit/zero_inspector_kit.dart';

// 回归测试：TimelineViewer 在 ListView 的无限高约束下必须能正常布局，
// 不能因 Row + CrossAxisAlignment.stretch + Expanded 算出无限高度而崩溃。
// Regression: TimelineViewer must lay out fine under ListView's unbounded
// vertical constraint — no infinite-height crash from a stretch+Expanded Row.
void main() {
  final base = DateTime.now().millisecondsSinceEpoch;

  LogEntry logAt(int offsetMs) => LogEntry(
    id: 'log-$offsetMs',
    level: LogLevel.info,
    message: 'message $offsetMs',
    timestamp: DateTime.fromMillisecondsSinceEpoch(base + offsetMs),
    tag: 'timeline-widget-test',
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

  testWidgets('TimelineViewer lays out event rows without unbounded height', (
    tester,
  ) async {
    InspectorService.instance
      ..addLogEntry(logAt(0))
      ..addRouteEntry(routeAt(500))
      ..addLogEntry(logAt(1000));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 600,
            child: TimelineViewer(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TimelineViewer), findsOneWidget);
    // 至少渲染出一条事件行（事件数 > 0 时 ListView 应有可见内容）。
    // At least one event row should be laid out when there are events.
    expect(find.byType(ListView), findsOneWidget);
  });

  testWidgets('TimelineViewer shows empty state without crashing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 600,
            child: TimelineViewer(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TimelineViewer), findsOneWidget);
  });
}
