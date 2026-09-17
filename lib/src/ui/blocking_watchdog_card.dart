import 'package:flutter/material.dart';

import '../models/blocking_event.dart';
import '../services/blocking_watchdog_service.dart';
import 'theme/inspector_theme.dart';

/// 主线程阻塞看门狗卡片（FPS 页内）/ Main-thread blocking watchdog card (in the FPS tab)
///
/// FPS 只能发现"有帧产出"的卡顿；真正卡死时引擎不产帧，FPS 反而显示空闲。
/// 这里直接按心跳间隔测量 UI isolate 的响应性，展示每次阻塞的时长、时间与
/// 附近日志，补上 FPS 的盲区。
/// FPS only catches jank that still produces frames; during a real stall no
/// frames are produced and FPS reads as idle. This card measures UI-isolate
/// responsiveness directly from heartbeat gaps and shows each stall's duration,
/// time and nearby logs — closing the FPS blind spot.
class BlockingWatchdogCard extends StatefulWidget {
  const BlockingWatchdogCard({super.key});

  @override
  State<BlockingWatchdogCard> createState() => _BlockingWatchdogCardState();
}

class _BlockingWatchdogCardState extends State<BlockingWatchdogCard> {
  @override
  void initState() {
    super.initState();
    BlockingWatchdogService.instance.addListener(_onChanged);
  }

  @override
  void dispose() {
    BlockingWatchdogService.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final service = BlockingWatchdogService.instance;
    final running = service.isRunning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: InspectorColors.card,
        borderRadius: BorderRadius.circular(InspectorDimensions.cardRadius),
        border: Border.all(
          color: running
              ? InspectorColors.success.withValues(alpha: 0.3)
              : InspectorColors.border,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                running
                    ? Icons.hourglass_bottom_rounded
                    : Icons.hourglass_empty_rounded,
                size: 18,
                color: running
                    ? InspectorColors.success
                    : InspectorColors.textHint,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Main-thread Blocking',
                      style: TextStyle(
                        color: InspectorColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      running
                          ? 'Watching · ${BlockingWatchdogService.tickInterval.inMilliseconds}ms heartbeat / '
                                '${service.thresholdMs}ms threshold'
                          : 'Stopped · stalls with no frames are invisible to FPS',
                      style: TextStyle(
                        color: running
                            ? InspectorColors.success
                            : InspectorColors.textHint,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: running,
                activeThumbColor: InspectorColors.success,
                activeTrackColor: InspectorColors.success.withValues(
                  alpha: 0.3,
                ),
                inactiveThumbColor: InspectorColors.textHint,
                inactiveTrackColor: InspectorColors.border,
                onChanged: (value) {
                  if (value) {
                    service.start();
                  } else {
                    service.stop();
                  }
                },
              ),
            ],
          ),
          if (running) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _buildStat(
                  'Stalls',
                  '${service.eventCount}',
                  service.eventCount > 0
                      ? InspectorColors.error
                      : InspectorColors.success,
                ),
                const SizedBox(width: 18),
                _buildStat(
                  'Longest',
                  service.longestBlockingMs > 0
                      ? '${service.longestBlockingMs}ms'
                      : '--',
                  service.longestBlockingMs > 0
                      ? InspectorColors.error
                      : InspectorColors.success,
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => BlockingWatchdogService.instance.clear(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: InspectorColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: InspectorColors.warning.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.refresh_rounded,
                          size: 13,
                          color: InspectorColors.warning,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Reset',
                          style: TextStyle(
                            color: InspectorColors.warning,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (service.events.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: InspectorColors.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: InspectorColors.border, width: 0.5),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 28,
                      color: InspectorColors.success,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'No blocking detected',
                      style: TextStyle(
                        color: InspectorColors.textHint,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                height: 120,
                child: ListView.builder(
                  itemCount: service.events.length,
                  itemBuilder: (context, index) =>
                      _buildRow(service.events[index]),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// 构建统计项 / Build a stat item
  Widget _buildStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: InspectorColors.textHint, fontSize: 11),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  /// 构建单条阻塞记录 / Build a single blocking record row
  Widget _buildRow(BlockingEvent event) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: InspectorColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: InspectorColors.error.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: InspectorColors.error,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                event.durationText,
                style: TextStyle(
                  color: InspectorColors.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _formatTime(event.startAt),
                  style: TextStyle(
                    color: InspectorColors.textHint,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (event.nearbyLogs.isNotEmpty) ...[
            const SizedBox(height: 4),
            for (final line in event.nearbyLogs)
              Padding(
                padding: const EdgeInsets.only(left: 14, top: 2),
                child: Text(
                  line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: InspectorColors.textHint,
                    fontSize: 9,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// 格式化时间（HH:mm:ss.SSS）/ Format time (HH:mm:ss.SSS)
  String _formatTime(DateTime time) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}'
        '.${time.millisecond.toString().padLeft(3, '0')}';
  }
}
