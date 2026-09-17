# zero_inspector_kit · OpenHarmony 适配说明

> 一行接入的应用内调试台：网络 / 日志 / 数据库 / 内存 / FPS / 路由。release 构建自动关闭。
> One-line in-app developer console: network / logs / database / memory / FPS / routes. Auto-disabled in release builds.

本文件说明 `zero_inspector_kit` 在 OpenHarmony（HarmonyOS NEXT）平台上的适配范围、接入方式与已知差异。
This document describes the OpenHarmony (HarmonyOS NEXT) adaptation scope, integration steps and known differences of `zero_inspector_kit`.

## 一、适配状态 / Adaptation status

| 项目 / Item | 状态 / Status |
|---|---|
| 平台注册 / Platform registration | ✅ `pubspec.yaml` 已声明 `flutter.plugin.platforms.ohos` |
| 原生实现 / Native implementation | ✅ `ohos/` HAR 模块（ArkTS），类名 `ZeroInspectorKitPlugin` |
| MethodChannel 通道 / Channel | ✅ `zero_inspector_kit`（与 Android / iOS 完全一致） |
| 依赖鸿蒙化 / Dependency adaptation | ⚠️ 需使用鸿蒙版依赖，见「五、依赖」/ needs OHOS-flavored deps, see §5 |

当前版本 / Current version：`1.12.0`

## 二、环境要求 / Requirements

- Flutter OHOS SDK（如 `3.35.x-ohos` / `3.41.x-ohos`，来自 [flutter_flutter](https://atomgit.com/openharmony-tpc/flutter_flutter)）
- DevEco Studio（配套 API 版本）+ HarmonyOS NEXT 真机
- OpenHarmony API **12+**（原生内存采集使用 `hidebug.getAppNativeMemInfo()` / `getSystemMemInfo()`）

> ⚠️ 标准 Flutter SDK **不支持** `--platforms=ohos`，必须使用 Flutter OHOS SDK 才能生成 / 构建鸿蒙工程。
> The standard Flutter SDK does **not** support `--platforms=ohos`; use the Flutter OHOS SDK.

## 三、接入 / Integration

### 3.1 添加依赖 / Add the dependency

```yaml
dependencies:
  zero_inspector_kit: ^1.12.0
```

### 3.2 生成鸿蒙工程（仅首次）/ Generate the ohos projects (first time only)

在插件根目录执行（会生成 `example/ohos/` 宿主工程，并补全插件侧 `ohos/` 目录）：
Run at the plugin root (generates the `example/ohos/` host project and completes the plugin-side `ohos/` module):

```bash
flutter create . --template=plugin --platforms=ohos
flutter pub get
```

### 3.3 使用 / Usage

Dart 层与 Android / iOS 完全一致，无需任何平台判断：
The Dart API is identical to Android / iOS — no platform checks needed:

```dart
void main() {
  ZeroInspectorKit.runAppWithInspector(const MyApp());
}
```

## 四、原生接口对照 / Native API parity

通道名 `zero_inspector_kit`，编解码器 `StandardMethodCodec`。
Channel: `zero_inspector_kit`, codec: `StandardMethodCodec`.

| 方法 / Method | Android | iOS | OpenHarmony | 说明 / Notes |
|---|---|---|---|---|
| `getPlatformVersion` | ✅ | ✅ | ✅ | 返回 `OpenHarmony <displayVersion>` |
| `getProcessMemoryInfo` | ✅ | ✅ | ✅ | 见下表 / see below |
| `getNativeLogs` | ✅ logcat | ✅ | ⚠️ | hilog 对三方应用只写不读，返回提示行；请用 `hdc shell "hilog -t <limit>"` 抓取<br>hilog is write-only for apps; fetch with `hdc shell "hilog -t <limit>"` |
| `startNativeLogListener` | ✅ | ✅ | ⚠️ | 无对应能力，返回 `null` 保持接口兼容 / no-op for API parity |
| `stopNativeLogListener` | ✅ | ✅ | ⚠️ | 同上 / ditto |

`getProcessMemoryInfo` 字段（单位：字节，与 Android / iOS 一致）：
`getProcessMemoryInfo` fields (in bytes, consistent with Android / iOS):

| 字段 / Field | OpenHarmony 数据来源 / Source |
|---|---|
| `rss` / `totalRss` | `hidebug.getAppNativeMemInfo().rss` (KB → B) |
| `totalPss` | `hidebug.getAppNativeMemInfo().pss` (KB → B) |
| `nativePss` | `hidebug.getNativeHeapAllocatedSize()` |
| `dalvikPss` | ArkTS 虚拟机堆已用大小 `hidebug.getAppVMMemoryInfo().heapUsed`（对应 Android Dalvik 槽位） |
| `totalPrivateDirty` / `nativePrivateDirty` | `hidebug.getAppNativeMemInfo().privateDirty` (KB → B) |
| `totalMem` / `availMem` | `hidebug.getSystemMemInfo().totalMem` / `.availableMem` (KB → B) |
| `lowMemory` | 可用内存 < 总内存 10% / available < 10% of total |
| `physicalFootprint` / `internalCompressed` / `graphics` | 恒为 0（iOS 专有指标，保持 Map 结构一致） |

> 注：`hidebug` 接口会读取 `/proc/{pid}/smaps_rollup`，官方建议避免在主线程高频调用；本插件每 3 秒
> 采集一次，仅在打开内存面板时启用，属于调试期开销。
> Note: `hidebug` reads `/proc/{pid}/smaps_rollup`; the plugin samples every 3s and only while
> memory monitoring is enabled (debug-time cost only).

## 五、依赖：不使用 dependency_overrides / Dependencies: no `dependency_overrides`

### 5.1 为什么不在插件里写 override / Why no override in the plugin

- `dependency_overrides` 只对 **root package** 生效，**不会传递给依赖本插件的下游 App**。
  写在 `zero_inspector_kit/pubspec.yaml` 里只在本地开发 / 测试时有效，**发布后对使用者完全无效**
  （ohos 上也拿不到鸿蒙版）。
  `dependency_overrides` only apply to the **root package** and are **never propagated** to
  downstream apps. Declaring them in this plugin only affects local development; after publishing
  they have **no effect** for consumers (OHOS included).
- 写在 **App 侧**则会**替换**该 App 在 Android / iOS 上的官方实现 —— 这正是要避免的。
  Declaring them in the **app** would **replace** the official Android / iOS implementations —
  exactly what we want to avoid.

### 5.2 做法一：federated 平台包（追加，不替换）/ Option 1: federated platform packages (add, don't replace)

以 `path_provider_ohos@2.2.1` 为例 / Take `path_provider_ohos@2.2.1` as an example:

```yaml
flutter:
  plugin:
    implements: path_provider      # 声明"我实现了 path_provider"，而不是替换它
    platforms:
      ohos:
        package: io.flutter.plugins.pathprovider
        pluginClass: PathProviderPlugin
        dartPluginClass: PathProviderOhos
```

这类包只在 **ohos** 构建时被 flutter 工具注册；Android / iOS 仍然走官方的
`path_provider_android` / `path_provider_foundation`，**行为零变化**。所以是"加依赖"而非"覆盖依赖"，
可以安全写进本插件的 `pubspec.yaml`，使用者 `flutter pub get` 即自动获得：
Such packages are registered for **ohos** only; Android / iOS keep using the official
`path_provider_android` / `path_provider_foundation` with **zero behavior change**. They are an
*addition*, not an override, so they are declared in this plugin's `pubspec.yaml` and consumers get
them automatically via `flutter pub get`:

```yaml
dependencies:
  path_provider: ^2.1.3
  share_plus: ^13.2.0
  path_provider_ohos: ^2.2.1   # 仅 ohos 生效，其它平台 inert / ohos only, inert elsewhere
  share_plus_ohos: ^1.0.0
```

### 5.3 sqflite：改用 sqflite_sqlcipher / sqflite: switching to sqflite_sqlcipher

`sqflite` 官方版没有 ohos 原生实现，它的鸿蒙版又是**同名 fork**（`name: sqflite`，2.2.8+3），
只能靠 `dependency_overrides` 替换 —— 会把 Android / iOS 从 2.4.4 降到 2.2.8+3，因此**不用它**。
本分支改用 **`sqflite_sqlcipher`**（已适配 ohos）：
The official `sqflite` has no ohos implementation, and its OHOS fork is a **same-named fork**
(2.2.8+3) usable only via `dependency_overrides`, which would downgrade Android / iOS from 2.4.4 —
so it is **not used**. This branch uses **`sqflite_sqlcipher`** (ohos-ready) instead:

```yaml
sqflite_sqlcipher:
  git:
    url: https://atomgit.com/flutter_ohos_plugin/sqflite_sqlcipher.git
    ref: d8835f7aaa9daecde2ab097fb374d025600aab93   # 分支 br_ohos
```

为什么它能直接替代 / Why it is a drop-in replacement:

- 与 `sqflite` 同源于 `sqflite_common`，`Database`、回调类型完全一致；
- **不传 `password` 时就是明文 SQLite**：Dart 侧 `password == null` 不发该参数，
  原生 `encrypt = password != null && length > 0` → false，因此能打开用户已有的普通数据库；
- 是独立包名，与 `sqflite` 不冲突，无需 override。

分派逻辑在 `lib/src/services/sqlite_backend.dart`：ohos 走 sqlcipher，其它平台仍走官方 `sqflite`
（Android / iOS 行为不变）。
Dispatch lives in `lib/src/services/sqlite_backend.dart`: ohos uses sqlcipher, other platforms keep
the official `sqflite` (Android / iOS behavior unchanged).

> ⚠️ 这是 **git 依赖**，pub.dev 禁止发布含 git 依赖的包，因此**本分支不用于 pub.dev 发布**
> （详见 AGENTS.md「OpenHarmony 适配分支策略」）。
> ⚠️ This is a **git dependency**; pub.dev rejects packages with git dependencies, so this branch is
> **not used for pub.dev publishing** (see AGENTS.md "OHOS branch policy").

| 依赖 / Dependency | 处理 / Handling | ohos 上的表现 / Behavior on ohos |
|---|---|---|
| `sqflite` | 保留（Android / iOS / 桌面使用）+ ohos 走 `sqflite_sqlcipher` | ✅ 持久化与数据库查看均可用 |
| `device_info_plus` | **不内置**：`device_info_plus_ohos` 的 environment 是 `sdk ">=2.19.6 <3.0.0"`，且缺少 `implements` 声明 —— 与本包约束冲突且不会生效 | 自动回退为 OS 名称（已内置 ohos 分支） |

若你的 App 确实需要在 ohos 上使用 SQLite 能力，可**在 App 自己的 pubspec.yaml** 中 override
（风险由 App 侧承担，不影响本插件的其他使用者）：
If your app does need SQLite on ohos, override it **in your app's own pubspec.yaml** (the app owns
the risk; other consumers of this plugin are unaffected):

```yaml
dependency_overrides:
  sqflite:
    git:
      url: https://gitcode.com/openharmony-sig/flutter_sqflite.git
      path: sqflite
```

## 六、功能可用性 / Feature availability

| 能力 / Feature | OpenHarmony | 说明 / Notes |
|---|---|---|
| 网络抓包 / Network inspection | ✅ | 基于 `HttpOverrides`，平台无关 |
| 日志 / Logs | ✅ | Dart 侧 `print` / `debugPrint` / Flutter 错误全捕获 |
| 数据库 / Database | ✅ | 依赖鸿蒙版 `sqflite` + `path_provider` |
| 内存 / Memory | ✅ | 进程 RSS / PSS / 私有脏页 + VM Service Dart Heap |
| FPS / 帧率 | ✅ | `SchedulerBinding.addTimingsCallback` |
| 路由 / Routes | ✅ | `NavigatorObserver` |
| Widget 树 / Widget tree | ✅ | |
| 原生日志回读 / Native log read-back | ❌ | 平台限制，见第四节 / platform limitation, see §4 |

## 七、运行示例 / Run the example

```bash
cd example
flutter pub get
flutter run -d <ohos-device>
```

首次运行需在 DevEco Studio 中打开 `example/ohos` 完成**自动签名**，再回到命令行 `flutter run`。
On first run, open `example/ohos` in DevEco Studio to apply **auto-signing**, then run
`flutter run` from the CLI.

## 八、已知差异 / Known differences

1. **hilog 不可回读**：应用进程内无法读取系统日志（Android 的 `logcat -d` 没有对应能力），
   `getNativeLogs` 返回提示行。
2. **hidebug 返回的 `bigint`** 已在原生侧转换为 `number`（`StandardMethodCodec` 不支持 `bigint`）。
3. **内存字段语义**：OpenHarmony 没有 Dalvik / Native PSS 分项，`dalvikPss` 复用为 ArkTS 虚拟机堆，
   `nativePss` 复用为 native heap 已分配字节。
4. **`Platform.isOhos` / `TargetPlatform.ohos` 不可用**：它们是 Flutter OHOS SDK 扩展，本包统一用
   `Platform.operatingSystem == 'ohos'` 判断，保证标准 Flutter SDK 上也能编译。

## 九、相关链接 / Links

- Flutter OHOS SDK：<https://atomgit.com/openharmony-tpc/flutter_flutter>
- 已适配三方库清单：<https://atomgit.com/CPF-Flutter/docs/blob/main/ThirdpartyLibrarites.md>
- 主文档 / Main README：[README.md](./README.md)
