import 'package:flutter_test/flutter_test.dart';
import 'package:todo_reminder/utils/abi.dart';

void main() {
  const assets = [
    'app-arm64-v8a-release.apk',
    'app-armeabi-v7a-release.apk',
    'app-x86_64-release.apk',
  ];

  group('matchApkAsset', () {
    test('按 supportedAbis 顺序精确匹配', () {
      expect(
        matchApkAsset(assets, ['arm64-v8a', 'armeabi-v7a']),
        'app-arm64-v8a-release.apk',
      );
      expect(matchApkAsset(assets, ['x86_64']), 'app-x86_64-release.apk');
    });

    test('主 ABI 无产物时回落次 ABI', () {
      expect(
        matchApkAsset(assets, ['armeabi', 'armeabi-v7a']),
        'app-armeabi-v7a-release.apk',
      );
    });

    test('无匹配返回 null', () {
      expect(matchApkAsset(assets, ['armeabi']), isNull);
      expect(matchApkAsset(const <String>[], ['arm64-v8a']), isNull);
    });
  });
}
