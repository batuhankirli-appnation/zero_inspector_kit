# zero_inspector_kit · OpenHarmony Adaptation

> One-line in-app developer console: network / logs / database / memory / FPS / routes. Auto-disabled in release builds.
> 一行接入的应用内调试台：网络 / 日志 / 数据库 / 内存 / FPS / 路由。release 构建自动关闭。

This document describes the OpenHarmony (HarmonyOS NEXT) adaptation scope, integration steps and
known differences of `zero_inspector_kit`. 本文件说明本库在 OpenHarmony 平台上的适配范围与已知差异。

## 1. Adaptation status / 适配状态

| Item / 项目 | Status / 状态 |
|---|---|
| Platform registration / 平台注册 | ✅ `flutter.plugin.platforms.ohos` declared in `pubspec.yaml` |
| Native implementation / 原生实现 | ✅ `ohos/` HAR module (ArkTS), class `ZeroInspectorKitPlugin` |
| MethodChannel | ✅ `zero_inspector_kit` (identical to Android / iOS) |
| Dependency adaptation / 依赖鸿蒙化 | ⚠️ OHOS-flavored dependencies required, see §5 |

Current version / 当前版本：`1.12.0`

## 2. Requirements / 环境要求

- Flutter OHOS SDK (e.g. `3.35.x-ohos` / `3.41.x-ohos`) from [flutter_flutter](https://atomgit.com/openharmony-tpc/flutter_flutter)
- DevEco Studio (matching API version) + a HarmonyOS NEXT device
- OpenHarmony API **12+** (memory collection uses `hidebug.getAppNativeMemInfo()` / `getSystemMemInfo()`)

> ⚠️ The **standard Flutter SDK does not support `--platforms=ohos`**. Use the Flutter OHOS SDK.
> 标准 Flutter SDK 不支持 `--platforms=ohos`，必须使用 Flutter OHOS SDK。

## 3. Integration / 接入

### 3.1 Add the dependency / 添加依赖

```yaml
dependencies:
  zero_inspector_kit: ^1.12.0
```

### 3.2 Generate the ohos projects (first time only) / 生成鸿蒙工程（仅首次）

```bash
flutter create . --template=plugin --platforms=ohos
flutter pub get
```

### 3.3 Usage / 使用

Identical to Android / iOS — no platform checks needed. 与 Android / iOS 完全一致，无需平台判断：

```dart
void main() {
  ZeroInspectorKit.runAppWithInspector(const MyApp());
}
```

## 4. Native API parity / 原生接口对照

Channel `zero_inspector_kit`, codec `StandardMethodCodec`. 通道名与 Android / iOS 一致。

| Method / 方法 | Android | iOS | OpenHarmony | Notes / 说明 |
|---|---|---|---|---|
| `getPlatformVersion` | ✅ | ✅ | ✅ | Returns `OpenHarmony <displayVersion>` |
| `getProcessMemoryInfo` | ✅ | ✅ | ✅ | See below / 见下表 |
| `getNativeLogs` | ✅ logcat | ✅ | ⚠️ | hilog is write-only for apps; returns a hint line. Use `hdc shell "hilog -t <limit>"` |
| `startNativeLogListener` | ✅ | ✅ | ⚠️ | No-op returning `null` for API parity / 保持接口兼容 |
| `stopNativeLogListener` | ✅ | ✅ | ⚠️ | ditto / 同上 |

`getProcessMemoryInfo` fields (bytes, consistent with Android / iOS):

| Field / 字段 | OpenHarmony source / 数据来源 |
|---|---|
| `rss` / `totalRss` | `hidebug.getAppNativeMemInfo().rss` (KB → B) |
| `totalPss` | `hidebug.getAppNativeMemInfo().pss` (KB → B) |
| `nativePss` | `hidebug.getNativeHeapAllocatedSize()` |
| `dalvikPss` | ArkTS VM heap usage, `hidebug.getAppVMMemoryInfo().heapUsed` (reuses the Android Dalvik slot) |
| `totalPrivateDirty` / `nativePrivateDirty` | `hidebug.getAppNativeMemInfo().privateDirty` (KB → B) |
| `totalMem` / `availMem` | `hidebug.getSystemMemInfo().totalMem` / `.availableMem` (KB → B) |
| `lowMemory` | available < 10% of total |
| `physicalFootprint` / `internalCompressed` / `graphics` | Always 0 (iOS-only metrics, kept for Map parity) |

## 5. Dependencies: no `dependency_overrides` / 依赖：不使用 override

### 5.1 Why no override in the plugin / 为什么不在插件里写 override

- `dependency_overrides` apply **only to the root package** and are **never propagated** to
  downstream apps. Declaring them in `zero_inspector_kit/pubspec.yaml` only affects local
  development; after publishing they have **no effect** for consumers (OHOS included).
  `dependency_overrides` 只对 **root package** 生效，**不会传递给下游 App**；写在本插件的
  pubspec 里只在本地开发时有效，**发布后对使用者完全无效**（ohos 上也拿不到鸿蒙版）。
- Declaring them in the **app** would **replace** the official Android / iOS implementations —
  exactly what we avoid. 写在 **App 侧**则会**替换**该 App 在 Android / iOS 上的官方实现。

### 5.2 Option 1: federated platform packages (add, don't replace) / 做法一：federated 平台包

`path_provider_ohos@2.2.1` is a real example / 实例：

```yaml
flutter:
  plugin:
    implements: path_provider      # implements path_provider instead of replacing it
    platforms:
      ohos:
        package: io.flutter.plugins.pathprovider
        pluginClass: PathProviderPlugin
        dartPluginClass: PathProviderOhos
```

Such a package is registered for **ohos** only; Android / iOS keep using the official
`path_provider_android` / `path_provider_foundation` with **zero behavior change**. It is an
*addition*, not an override — therefore it is declared in this plugin's `pubspec.yaml` and consumers
get it automatically via `flutter pub get`.
这类包只在 ohos 构建时注册，Android / iOS 行为零变化，因此直接写进本插件 pubspec，使用者自动获得。

```yaml
dependencies:
  path_provider: ^2.1.3
  share_plus: ^13.2.0
  path_provider_ohos: ^2.2.1   # ohos only, inert elsewhere / 仅 ohos 生效，其它平台 inert
  share_plus_ohos: ^1.0.0
```

### 5.3 sqflite: switching to sqflite_sqlcipher / sqflite 改用 sqflite_sqlcipher

The official `sqflite` has no ohos implementation, and its OHOS fork is a **same-named fork**
(`name: sqflite`, 2.2.8+3) usable only via `dependency_overrides`, which would downgrade
Android / iOS from 2.4.4 — so it is **not used**. This branch uses **`sqflite_sqlcipher`**:
`sqflite` 官方版无 ohos 实现，其鸿蒙版又是同名 fork（2.2.8+3），只能用 override 替换并会让
Android / iOS 从 2.4.4 降级 —— 因此不用它，改用已适配 ohos 的 `sqflite_sqlcipher`：

```yaml
sqflite_sqlcipher:
  git:
    url: https://atomgit.com/flutter_ohos_plugin/sqflite_sqlcipher.git
    ref: d8835f7aaa9daecde2ab097fb374d025600aab93   # branch br_ohos
```

Why it is a drop-in replacement / 为什么可直接替代:

- It shares `sqflite_common` with `sqflite`, so `Database` and callback types are identical.
- **Without a `password` it is plain SQLite**: Dart omits the parameter when null and the native
  side uses `encrypt = password != null && length > 0` → existing unencrypted databases open fine.
- It is a separate package name, so it does not conflict with `sqflite` and needs no override.

Dispatch lives in `lib/src/services/sqlite_backend.dart`: ohos uses sqlcipher, other platforms keep
the official `sqflite` (Android / iOS behavior unchanged).
分派逻辑见 `lib/src/services/sqlite_backend.dart`：ohos 走 sqlcipher，其它平台仍走官方 sqflite。

> ⚠️ This is a **git dependency**; pub.dev rejects packages with git dependencies, so this branch is
> **not used for pub.dev publishing** (see AGENTS.md "OHOS branch policy").
> ⚠️ 这是 git 依赖，pub.dev 禁止发布含 git 依赖的包，因此本分支不用于 pub.dev 发布。

| Dependency | Handling / 处理 | Behavior on ohos / ohos 上的表现 |
|---|---|---|
| `sqflite` | Kept for Android / iOS / desktop; ohos uses `sqflite_sqlcipher` | ✅ Persistence and DB viewer both work |
| `device_info_plus` | **Not bundled**: `device_info_plus_ohos` requires `sdk ">=2.19.6 <3.0.0"` and lacks an `implements` declaration — incompatible and ineffective | Falls back to the OS name (built-in ohos branch) |

## 6. Feature availability / 功能可用性

| Feature / 能力 | OpenHarmony | Notes / 说明 |
|---|---|---|
| Network inspection / 网络抓包 | ✅ | `HttpOverrides`, platform-agnostic |
| Logs / 日志 | ✅ | Dart `print` / `debugPrint` / Flutter errors |
| Database / 数据库 | ✅ | Requires OHOS `sqflite` + `path_provider` |
| Memory / 内存 | ✅ | RSS / PSS / private dirty + VM Service Dart heap |
| FPS | ✅ | `SchedulerBinding.addTimingsCallback` |
| Routes / 路由 | ✅ | `NavigatorObserver` |
| Widget tree / Widget 树 | ✅ | |
| Native log read-back / 原生日志回读 | ❌ | Platform limitation, see §4 |

## 7. Run the example / 运行示例

```bash
cd example
flutter pub get
flutter run -d <ohos-device>
```

On first run, open `example/ohos` in DevEco Studio to apply **auto-signing**, then run `flutter run`.
首次运行需在 DevEco Studio 打开 `example/ohos` 完成自动签名，再回到命令行运行。

## 8. Known differences / 已知差异

1. **hilog cannot be read back** from an app process (no `logcat -d` equivalent); `getNativeLogs`
   returns a hint line.
2. **`bigint` values** returned by `hidebug` are converted to `number` on the native side
   (`StandardMethodCodec` cannot encode `bigint`).
3. **Memory field semantics**: OpenHarmony has no Dalvik / Native PSS breakdown, so `dalvikPss`
   carries the ArkTS VM heap usage and `nativePss` the allocated native heap bytes.
4. **`Platform.isOhos` / `TargetPlatform.ohos` are not used** — they only exist in the Flutter OHOS
   SDK. The package uses `Platform.operatingSystem == 'ohos'` so it still compiles on the standard
   Flutter SDK.

## 9. Links / 相关链接

- Flutter OHOS SDK: <https://atomgit.com/openharmony-tpc/flutter_flutter>
- Adapted plugin list / 已适配三方库清单: <https://atomgit.com/CPF-Flutter/docs/blob/main/ThirdpartyLibrarites.md>
- Chinese adaptation notes / 中文适配说明: [README.OpenHarmony_CN.md](./README.OpenHarmony_CN.md)
