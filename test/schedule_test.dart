import 'package:flutter_test/flutter_test.dart';
import 'package:todo_reminder/models/task.dart';
import 'package:todo_reminder/utils/schedule.dart';

void main() {
  group('nextDaily', () {
    test('当天时间未到，返回今天', () {
      final from = DateTime(2026, 8, 25, 8, 0);
      expect(nextDaily(from, 9, 30), DateTime(2026, 8, 25, 9, 30));
    });

    test('当天时间已过，返回明天', () {
      final from = DateTime(2026, 8, 25, 10, 0);
      expect(nextDaily(from, 9, 30), DateTime(2026, 8, 26, 9, 30));
    });
  });

  group('nextWeekly', () {
    test('本周目标星期几尚未到，返回本周', () {
      // 2026-08-25 是周二（weekday=2），周五 = 5 → 8/28
      final from = DateTime(2026, 8, 25, 8, 0);
      expect(nextWeekly(from, 5, 9, 0), DateTime(2026, 8, 28, 9, 0));
    });

    test('当天是目标星期几但时间已过，返回下周', () {
      final from = DateTime(2026, 8, 25, 10, 0); // 周二
      expect(nextWeekly(from, 2, 9, 0), DateTime(2026, 9, 1, 9, 0));
    });
  });

  group('nextMonthly', () {
    test('本月目标号数未到，返回本月', () {
      final from = DateTime(2026, 8, 10);
      expect(nextMonthly(from, 20, 9, 0), DateTime(2026, 8, 20, 9, 0));
    });

    test('本月目标号数已过，返回下月', () {
      final from = DateTime(2026, 8, 25);
      expect(nextMonthly(from, 20, 9, 0), DateTime(2026, 9, 20, 9, 0));
    });

    test('2 月没有 31 号，取当月最后一天（2026 非闰年）', () {
      final from = DateTime(2026, 2, 1);
      expect(nextMonthly(from, 31, 9, 0), DateTime(2026, 2, 28, 9, 0));
    });
  });

  group('Task.nextOccurrence', () {
    test('每天任务返回明天同一时刻', () {
      final task = Task(
        title: '喝水',
        repeatType: RepeatType.daily,
        remindHour: 8,
        remindMinute: 30,
        createdAt: 0,
        updatedAt: 0,
      );
      final from = DateTime(2026, 8, 25, 10, 0);
      expect(task.nextOccurrence(from), DateTime(2026, 8, 26, 8, 30));
    });

    test('每周任务返回最近的一个星期几', () {
      final task = Task(
        title: '开会',
        repeatType: RepeatType.weekly,
        weekdays: {1, 4}, // 周一、周四
        remindHour: 9,
        remindMinute: 0,
        createdAt: 0,
        updatedAt: 0,
      );
      // 2026-08-25 周二，最近的周四(4)在 8/27
      final from = DateTime(2026, 8, 25, 8, 0);
      expect(task.nextOccurrence(from), DateTime(2026, 8, 27, 9, 0));
    });

    test('一次性任务返回其设定时间（即使已过期）', () {
      final task = Task(
        title: '交报告',
        repeatType: RepeatType.once,
        remindHour: 15,
        remindMinute: 0,
        date: '2026-08-20',
        createdAt: 0,
        updatedAt: 0,
      );
      final from = DateTime(2026, 8, 25, 10, 0);
      expect(task.nextOccurrence(from), DateTime(2026, 8, 20, 15, 0));
    });
  });
}
