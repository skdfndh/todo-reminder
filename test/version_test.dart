import 'package:flutter_test/flutter_test.dart';
import 'package:todo_reminder/services/update_service.dart';
import 'package:todo_reminder/utils/version.dart';

void main() {
  group('AppVersion.tryParse', () {
    test('解析 v 前缀、裸版本与 +buildNumber', () {
      expect(AppVersion.tryParse('v1.1.0')?.parts, [1, 1, 0]);
      expect(AppVersion.tryParse('1.0.0')?.parts, [1, 0, 0]);
      expect(AppVersion.tryParse('1.0.0+1')?.parts, [1, 0, 0]);
      expect(AppVersion.tryParse('1.0')?.parts, [1, 0]);
    });

    test('无法解析返回 null', () {
      expect(AppVersion.tryParse('abc'), isNull);
      expect(AppVersion.tryParse('1.x.0'), isNull);
      expect(AppVersion.tryParse(''), isNull);
    });
  });

  group('AppVersion 比较', () {
    test('逐段比较，短段补 0', () {
      expect(
        AppVersion.tryParse('1.1.0')!.compareTo(AppVersion.tryParse('1.0.9')!),
        greaterThan(0),
      );
      expect(
        AppVersion.tryParse('1.0.0')!.compareTo(AppVersion.tryParse('1.0.0')!),
        0,
      );
      expect(
        AppVersion.tryParse('1.0.0')!.compareTo(AppVersion.tryParse('1.0')!),
        0,
      );
      expect(
        AppVersion.tryParse('1.1.0')!.compareTo(AppVersion.tryParse('2.0.0')!),
        lessThan(0),
      );
    });

    test('isNewerThan', () {
      expect(
        AppVersion.tryParse('1.1.0')!
            .isNewerThan(AppVersion.tryParse('1.0.0')!),
        isTrue,
      );
      expect(
        AppVersion.tryParse('1.0.0')!
            .isNewerThan(AppVersion.tryParse('1.0.0')!),
        isFalse,
      );
      expect(
        AppVersion.tryParse('0.9.0')!
            .isNewerThan(AppVersion.tryParse('1.0.0')!),
        isFalse,
      );
    });
  });

  group('releaseSummaryLines', () {
    test('提取并清理前两条发布说明', () {
      expect(releaseSummaryLines('# v1.5.0\n- 优化深色模式\n* 改进翻页效果\n- 修复提醒'), [
        '优化深色模式',
        '改进翻页效果',
      ]);
    });

    test('跳过空行，最多保留两条', () {
      expect(releaseSummaryLines('\n\n1. 修复提醒\n2) 优化日历'), ['修复提醒', '优化日历']);
    });
  });
}
