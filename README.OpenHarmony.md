# zero_inspector_kit · OpenHarmony Adaptation

> One-line in-app developer console: network / logs / database / memory / FPS / routes. Auto-disabled in release builds.

This document describes the OpenHarmony (HarmonyOS NEXT) adaptation scope, integration steps and known differences of `zero_inspector_kit`.

## 1. Adaptation status

| Item | Status |
|---|---|
| Platform registration | ✅ `flutter.plugin.platforms.ohos` declared in `pubspec.yaml` |
| Native implementation | ✅ `ohos/` HAR module (ArkTS), class `ZeroInspectorKitPlugin` |
| MethodChannel | ✅ `zero_inspector_kit` (identical to Android / iOS) |
| Dependency adaptation | ⚠️ OHOS-flavored dependencies required, see §5 |

Current version: `1.12.0`

## 2. Requirements

- Flutter OHOS SDK (e.g. `3.35.x-ohos` / `3.41.x-ohos`) from [flutter_flutter](https://atomgit.com/openharmony-tpc/flutter_flutter)
- DevEco Studio (matching API version) + a HarmonyOS NEXT device
- OpenHarmony API **12+** (memory collection uses `hidebug.getAppNativeMemInfo()` / `getSystemMemInfo()`)

> ⚠️ The **standard Flutter SDK does not support `--platforms=ohos`**. Use the Flutter OHOS SDK.

## 3. Integration

### 3.1 Add the dependency

```yaml
dependencies:
  zero_inspector_kit: ^1.12.0
```

### 3.2 Generate the ohos projects (first time only)

```bash
flutter create . --template=plugin --platforms=ohos
flutter pub get
```

### 3.3 Usage

Identical to Android / iOS — no platform checks needed.

```dart
void main() {
  ZeroInspectorKit.runAppWithInspector(const MyApp());
}
```

## 4. Native API parity

Channel `zero_inspector_kit`, codec `StandardMethodCodec`.

| Method | Android | iOS | OpenHarmony | Notes |
|---|---|---|---|---|
| `getPlatformVersion` | ✅ | ✅ | ✅ | Returns `OpenHarmony <displayVersion>` |
| `getProcessMemoryInfo` | ✅ | ✅ | ✅ | See below |
| `getNativeLogs` | ✅ logcat | ✅ | ⚠️ | hilog is write-only for apps; returns a hint line. Use `hdc shell "hilog -t <limit>"` |
| `startNativeLogListener` | ✅ | ✅ | ⚠️ | No-op returning `null` for API parity |
| `stopNativeLogListener` | ✅ | ✅ | ⚠️ | ditto |

`getProcessMemoryInfo` fields (bytes, consistent with Android / iOS):

| Field | OpenHarmony source |
|---|---|
| `rss` / `totalRss` | `hidebug.getAppNativeMemInfo().rss` (KB → B) |
| `totalPss` | `hidebug.getAppNativeMemInfo().pss` (KB → B) |
| `nativePss` | `hidebug.getNativeHeapAllocatedSize()` |
| `dalvikPss` | ArkTS VM heap usage, `hidebug.getAppVMMemoryInfo().heapUsed` (reuses the Android Dalvik slot) |
| `totalPrivateDirty` / `nativePrivateDirty` | `hidebug.getAppNativeMemInfo().privateDirty` (KB → B) |
| `totalMem` / `availMem` | `hidebug.getSystemMemInfo().totalMem` / `.availableMem` (KB → B) |
| `lowMemory` | available < 10% of total |
| `physicalFootprint` / `internalCompressed` / `graphics` | Always 0 (iOS-only metrics, kept for Map parity) |

> Note: `hidebug` reads `/proc/{pid}/smaps_rollup`; the plugin samples every 3s and only while memory monitoring is enabled (debug-time cost only).

## 5. Dependencies: no `dependency_overrides`

### 5.1 Why no override in the plugin

- `dependency_overrides` apply **only to the root package** and are **never propagated** to downstream apps. Declaring them in `zero_inspector_kit/pubspec.yaml` only affects local development; after publishing they have **no effect** for consumers (OHOS included).
- Declaring them in the **app** would **replace** the official Android / iOS implementations — exactly what we avoid.

### 5.2 Option 1: federated platform packages (add, don't replace)

`path_provider_ohos@2.2.1` is a real example:

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

Such a package is registered for **ohos** only; Android / iOS keep using the official `path_provider_android` / `path_provider_foundation` with **zero behavior change**. It is an *addition*, not an override — therefore it is declared in this plugin's `pubspec.yaml` and consumers get it automatically via `flutter pub get`.

```yaml
dependencies:
  path_provider: ^2.1.3
  share_plus: ^13.2.0
  path_provider_ohos: ^2.2.1   # ohos only, inert elsewhere
  share_plus_ohos: ^1.0.0
```

### 5.3 sqflite: switching to sqflite_sqlcipher

The official `sqflite` has no ohos implementation, and its OHOS fork is a **same-named fork** (`name: sqflite`, 2.2.8+3) usable only via `dependency_overrides`, which would downgrade Android / iOS from 2.4.4 — so it is **not used**. This branch uses **`sqflite_sqlcipher`**:

```yaml
sqflite_sqlcipher:
  git:
    url: https://atomgit.com/flutter_ohos_plugin/sqflite_sqlcipher.git
    ref: d8835f7aaa9daecde2ab097fb374d025600aab93   # branch br_ohos
```

Why it is a drop-in replacement:

- It shares `sqflite_common` with `sqflite`, so `Database` and callback types are identical.
- **Without a `password` it is plain SQLite**: Dart omits the parameter when null and the native side uses `encrypt = password != null && length > 0` → existing unencrypted databases open fine.
- It is a separate package name, so it does not conflict with `sqflite` and needs no override.

Dispatch lives in `lib/src/services/sqlite_backend.dart`: ohos uses sqlcipher, other platforms keep the official `sqflite` (Android / iOS behavior unchanged).

> ⚠️ This is a **git dependency**; pub.dev rejects packages with git dependencies, so this branch is **not used for pub.dev publishing** (see AGENTS.md "OHOS branch policy").

| Dependency | Handling | Behavior on ohos |
|---|---|---|
| `sqflite` | Kept for Android / iOS / desktop; ohos uses `sqflite_sqlcipher` | ✅ Persistence and DB viewer both work |
| `device_info_plus` | **Not bundled**: `device_info_plus_ohos` requires `sdk ">=2.19.6 <3.0.0"` and lacks an `implements` declaration — incompatible and ineffective | Falls back to the OS name (built-in ohos branch) |

If your app does need SQLite on ohos, override it **in your app's own pubspec.yaml** (the app owns the risk; other consumers of this plugin are unaffected):

```yaml
dependency_overrides:
  sqflite:
    git:
      url: https://gitcode.com/openharmony-sig/flutter_sqflite.git
      path: sqflite
```

## 6. Feature availability

| Feature | OpenHarmony | Notes |
|---|---|---|
| Network inspection | ✅ | `HttpOverrides`, platform-agnostic |
| Logs | ✅ | Dart `print` / `debugPrint` / Flutter errors |
| Database | ✅ | Requires OHOS `sqflite` + `path_provider` |
| Memory | ✅ | RSS / PSS / private dirty + VM Service Dart heap |
| FPS | ✅ | `SchedulerBinding.addTimingsCallback` |
| Routes | ✅ | `NavigatorObserver` |
| Widget tree | ✅ | |
| Native log read-back | ❌ | Platform limitation, see §4 |

## 7. Run the example

```bash
cd example
flutter pub get
flutter run -d <ohos-device>
```

On first run, open `example/ohos` in DevEco Studio to apply **auto-signing**, then run `flutter run`.

## 8. Known differences

1. **hilog cannot be read back** from an app process (no `logcat -d` equivalent); `getNativeLogs` returns a hint line.
2. **`bigint` values** returned by `hidebug` are converted to `number` on the native side (`StandardMethodCodec` cannot encode `bigint`).
3. **Memory field semantics**: OpenHarmony has no Dalvik / Native PSS breakdown, so `dalvikPss` carries the ArkTS VM heap usage and `nativePss` the allocated native heap bytes.
4. **`Platform.isOhos` / `TargetPlatform.ohos` are not used** — they only exist in the Flutter OHOS SDK. The package uses `Platform.operatingSystem == 'ohos'` so it still compiles on the standard Flutter SDK.

## 9. Links

- Flutter OHOS SDK: <https://atomgit.com/openharmony-tpc/flutter_flutter>
- Adapted plugin list: <https://atomgit.com/CPF-Flutter/docs/blob/main/ThirdpartyLibrarites.md>
- Chinese adaptation notes: [README.OpenHarmony_CN.md](./README.OpenHarmony_CN.md)
