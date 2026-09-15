import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult
} from '@ohos/flutter_ohos';
import StandardMethodCodec from '@ohos/flutter_ohos/src/main/ets/plugin/common/StandardMethodCodec';
import { deviceInfo } from '@kit.BasicServicesKit';
import { hidebug, hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'ZeroInspectorKitPlugin';
const CHANNEL_NAME: string = 'zero_inspector_kit';
const HILOG_DOMAIN: number = 0x0000;
const DEFAULT_LOG_LIMIT: number = 100;
const KB_TO_BYTES: number = 1024;

/// OpenHarmony 平台实现 / OpenHarmony platform implementation
///
/// 与 Android / iOS 端共用同一条 MethodChannel（"zero_inspector_kit"）与方法名，
/// 保证 Dart 层（lib/src/platform/platform_channel.dart）零改动即可工作。
/// Shares the same MethodChannel ("zero_inspector_kit") and method names with the
/// Android / iOS implementations, so the Dart layer
/// (lib/src/platform/platform_channel.dart) works unchanged.
export default class ZeroInspectorKitPlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;

  /// 插件唯一类名，必须与 pubspec.yaml 中 ohos.pluginClass 一致
  /// Unique class name, must match ohos.pluginClass in pubspec.yaml
  getUniqueClassName(): string {
    return TAG;
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL_NAME, StandardMethodCodec.INSTANCE);
    this.channel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null);
      this.channel = null;
    }
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    try {
      switch (call.method) {
        case 'getPlatformVersion':
          result.success(this.getPlatformVersion());
          break;
        case 'getNativeLogs':
          result.success(this.getNativeLogs(ZeroInspectorKitPlugin.readLimit(call.args)));
          break;
        case 'startNativeLogListener':
          // hilog 对应用进程只写不读，无监听器可挂，保持接口兼容
          // hilog is write-only for apps; nothing to listen to, kept for API parity
          result.success(null);
          break;
        case 'stopNativeLogListener':
          result.success(null);
          break;
        case 'getProcessMemoryInfo':
          result.success(this.getProcessMemoryInfo());
          break;
        default:
          result.notImplemented();
          break;
      }
    } catch (err) {
      const message: string = (err as Error).message;
      hilog.error(HILOG_DOMAIN, TAG, 'onMethodCall failed: %{public}s', message);
      result.error('OHOS_ERROR', `ZeroInspectorKit: ${call.method} failed: ${message}`, null);
    }
  }

  /// 获取平台版本 / Get platform version
  private getPlatformVersion(): string {
    try {
      return `OpenHarmony ${deviceInfo.displayVersion}`;
    } catch (err) {
      return 'OpenHarmony';
    }
  }

  /// 读取 Dart 侧传入的 limit 参数 / Read the limit argument sent from Dart
  private static readLimit(args: Object | null | undefined): number {
    try {
      if (args !== null && args !== undefined) {
        const params: Map<string, Object> = args as Map<string, Object>;
        const raw: Object | undefined = params.get('limit');
        const limit: number = parseInt(String(raw), 10);
        if (!Number.isNaN(limit) && limit > 0) {
          return limit;
        }
      }
    } catch (err) {
      hilog.warn(HILOG_DOMAIN, TAG, 'readLimit failed, use default: %{public}s', JSON.stringify(err));
    }
    return DEFAULT_LOG_LIMIT;
  }

  /// 获取原生日志 / Get native logs
  ///
  /// OpenHarmony 的 hilog 对三方应用只提供写入能力，不提供回读接口（不像 Android
  /// 的 logcat -d），因此这里返回一条提示，日志请在终端用 hdc 抓取：
  ///   hdc shell "hilog -t <limit>"
  /// OpenHarmony's hilog is write-only for third-party apps (unlike Android's
  /// `logcat -d`), so a hint line is returned. Fetch logs from a terminal instead:
  ///   hdc shell "hilog -t <limit>"
  private getNativeLogs(limit: number): Array<string> {
    const logs: Array<string> = new Array<string>();
    logs.push(
      `[ZeroInspectorKit] hilog cannot be read back inside an app process on ` +
        `OpenHarmony; run: hdc shell "hilog -t ${limit}"`
    );
    return logs;
  }

  /// 获取进程级内存信息 / Get process-level memory info
  ///
  /// 数据来源 @kit.PerformanceAnalysisKit 的 hidebug（读取 /proc/{pid}/smaps_rollup、
  /// /proc/meminfo），全部字段统一转换为字节，与 Android / iOS 端保持一致。
  /// Data comes from hidebug (@kit.PerformanceAnalysisKit); every field is
  /// converted to bytes to stay consistent with the Android / iOS implementations.
  ///
  /// - rss / totalRss:  进程 RSS（hidebug rss）
  /// - totalPss:        进程 PSS（hidebug pss）
  /// - nativePss:       Native 堆已分配字节（hidebug getNativeHeapAllocatedSize）
  /// - dalvikPss:       ArkTS 虚拟机堆已用大小（对应 Android 的 Dalvik/ART 槽位）
  /// - *PrivateDirty:   进程私有脏页（hidebug privateDirty）
  /// - totalMem / availMem: 系统总内存 / 可用内存（hidebug getSystemMemInfo）
  private getProcessMemoryInfo(): Map<string, Object> {
    const info: Map<string, Object> = new Map<string, Object>();

    // 1. 进程内存分项（KB）/ 1. Process memory breakdown (KB)
    let pssKb: number = 0;
    let rssKb: number = 0;
    let vssKb: number = 0;
    let privateDirtyKb: number = 0;
    let sharedDirtyKb: number = 0;
    try {
      const nativeMemInfo = hidebug.getAppNativeMemInfo();
      pssKb = ZeroInspectorKitPlugin.toNumber(nativeMemInfo.pss);
      rssKb = ZeroInspectorKitPlugin.toNumber(nativeMemInfo.rss);
      vssKb = ZeroInspectorKitPlugin.toNumber(nativeMemInfo.vss);
      privateDirtyKb = ZeroInspectorKitPlugin.toNumber(nativeMemInfo.privateDirty);
      sharedDirtyKb = ZeroInspectorKitPlugin.toNumber(nativeMemInfo.sharedDirty);
    } catch (err) {
      hilog.warn(HILOG_DOMAIN, TAG, 'getAppNativeMemInfo failed: %{public}s', JSON.stringify(err));
    }

    info.set('rss', rssKb * KB_TO_BYTES);
    info.set('totalRss', rssKb * KB_TO_BYTES);
    info.set('totalPss', pssKb * KB_TO_BYTES);
    info.set('nativePss', 0);
    info.set('dalvikPss', 0);
    info.set('otherPss', 0);
    info.set('totalPrivateDirty', privateDirtyKb * KB_TO_BYTES);
    info.set('nativePrivateDirty', privateDirtyKb * KB_TO_BYTES);
    info.set('dalvikPrivateDirty', 0);
    info.set('otherPrivateDirty', sharedDirtyKb * KB_TO_BYTES);
    info.set('totalSwapPss', 0);
    info.set('dalvikRss', 0);
    info.set('nativeRss', 0);
    info.set('otherRss', 0);
    info.set('virtualMemory', vssKb * KB_TO_BYTES);

    // 2. Native 堆（字节）/ 2. Native heap (bytes)
    try {
      info.set('nativePss', ZeroInspectorKitPlugin.toNumber(hidebug.getNativeHeapAllocatedSize()));
    } catch (err) {
      hilog.warn(HILOG_DOMAIN, TAG, 'getNativeHeapAllocatedSize failed: %{public}s', JSON.stringify(err));
    }

    // 3. ArkTS 虚拟机堆（KB）→ 占用 Android 的 dalvikPss 槽位
    // 3. ArkTS VM heap (KB) → occupies the Android dalvikPss slot
    try {
      const vmMemoryInfo = hidebug.getAppVMMemoryInfo();
      info.set('dalvikPss', ZeroInspectorKitPlugin.toNumber(vmMemoryInfo.heapUsed) * KB_TO_BYTES);
    } catch (err) {
      hilog.warn(HILOG_DOMAIN, TAG, 'getAppVMMemoryInfo failed: %{public}s', JSON.stringify(err));
    }

    // 4. iOS 专有字段，OHOS 无对应指标，填 0 保持 Map 结构一致
    // 4. iOS-only fields; fill 0 to keep the Map structure consistent
    info.set('physicalFootprint', 0);
    info.set('internalCompressed', 0);
    info.set('internalSize', 0);
    info.set('graphics', 0);

    // 5. 系统内存（KB）/ 5. System memory (KB)
    let totalMemKb: number = 0;
    let availMemKb: number = 0;
    try {
      const systemMemInfo = hidebug.getSystemMemInfo();
      totalMemKb = ZeroInspectorKitPlugin.toNumber(systemMemInfo.totalMem);
      availMemKb = ZeroInspectorKitPlugin.toNumber(systemMemInfo.availableMem);
    } catch (err) {
      hilog.warn(HILOG_DOMAIN, TAG, 'getSystemMemInfo failed: %{public}s', JSON.stringify(err));
    }
    info.set('totalMem', totalMemKb * KB_TO_BYTES);
    info.set('availMem', availMemKb * KB_TO_BYTES);
    info.set('threshold', 0);
    // 可用内存低于总量 10% 视为低内存（Android 侧由 ActivityManager 判定）
    // Treat <10% available as low memory (Android uses ActivityManager for this)
    info.set('lowMemory', totalMemKb > 0 && availMemKb < totalMemKb * 0.1);

    return info;
  }

  /// hidebug 返回 bigint，而 StandardMethodCodec 不支持 bigint，统一转为 number
  /// hidebug returns bigint which StandardMethodCodec cannot encode; convert to number
  private static toNumber(value: bigint): number {
    const parsed: number = parseInt(value.toString(), 10);
    return Number.isNaN(parsed) ? 0 : parsed;
  }
}
