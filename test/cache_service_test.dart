import 'package:flutter_test/flutter_test.dart';
import 'package:todo_reminder/services/cache_service.dart';

void main() {
  group('可清除更新缓存', () {
    test('仅识别应用下载的 APK', () {
      expect(
        isDisposableUpdatePackagePath('/cache/todo-reminder-1.5.2.apk'),
        isTrue,
      );
      expect(
        isDisposableUpdatePackagePath(r'C:\cache\todo-reminder-1.5.2.apk'),
        isTrue,
      );
      expect(isDisposableUpdatePackagePath('/cache/backup.json'), isFalse);
      expect(isDisposableUpdatePackagePath('/cache/other-app.apk'), isFalse);
    });

    test('以易读单位显示缓存大小', () {
      expect(formatCacheSize(512), '512 B');
      expect(formatCacheSize(2048), '2.0 KB');
      expect(formatCacheSize(3 * 1024 * 1024), '3.0 MB');
    });
  });
}
