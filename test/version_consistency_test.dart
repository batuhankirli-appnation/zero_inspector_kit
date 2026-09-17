import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zero_inspector_kit/zero_inspector_kit.dart';

/// 版本一致性回归测试 / Version consistency regression tests
///
/// 发版时版本号散落在多处，漏改一处就会让 pub.dev 上的包与文档自相矛盾
/// （HAR 导出的 `creator.version` 曾长期停在旧版本）。这里以 `pubspec.yaml`
/// 的 `version` 为真值，断言其它各处同步。
/// At release time the version lives in several places; missing one leaves the
/// published package contradicting its own docs (the HAR export's
/// `creator.version` used to sit on an old release). `pubspec.yaml`'s
/// `version` is the source of truth and every other place is asserted here.
///
/// 更完整的校验（含逐行定位与修复提示）由 `tool/check_release.dart` 提供，
/// 由 CI 单独一步执行；这里保证 `flutter test` 也能拦住漂移。
/// The fuller check (per-line locations and fix hints) lives in
/// `tool/check_release.dart`, run as its own CI step; this keeps `flutter test`
/// able to catch drift too.
void main() {
  late String pubspecVersion;

  setUpAll(() {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(match, isNotNull, reason: 'pubspec.yaml must declare a version');
    pubspecVersion = match!.group(1)!;
  });

  test('InspectorVersion.value matches pubspec.yaml', () {
    expect(InspectorVersion.value, pubspecVersion);
  });

  test('iOS podspec version matches pubspec.yaml', () {
    final podspec = File('ios/zero_inspector_kit.podspec').readAsStringSync();
    final match = RegExp(r"s\.version\s*=\s*'([^']+)'").firstMatch(podspec);
    expect(match, isNotNull);
    expect(match!.group(1), pubspecVersion);
  });

  for (final readme in ['README.md', 'README_zh.md']) {
    test('$readme install snippets reference the current version', () {
      final content = File(readme).readAsStringSync();
      expect(content, contains('zero_inspector_kit: ^$pubspecVersion'));
      expect(content, contains('release/v$pubspecVersion'));
    });
  }

  test('CHANGELOG.md has a section for the current version', () {
    final changelog = File('CHANGELOG.md').readAsStringSync();
    final match = RegExp(
      r'^##\s*([0-9]+\.[0-9]+\.[0-9]+)\s*$',
      multiLine: true,
    ).firstMatch(changelog);
    expect(match, isNotNull);
    expect(match!.group(1), pubspecVersion);
  });
}
