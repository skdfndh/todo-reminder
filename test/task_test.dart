import 'package:flutter_test/flutter_test.dart';
import 'package:todo_reminder/models/task.dart';
import 'package:todo_reminder/providers/task_providers.dart';

Task _task({
  RepeatType repeatType = RepeatType.once,
  String? date,
  Set<int> weekdays = const {},
  int? dayOfMonth,
  int hour = 9,
  int minute = 0,
  String? startDate,
  String? endDate,
  Priority priority = Priority.medium,
  bool pinned = false,
}) {
  return Task(
    title: 't',
    repeatType: repeatType,
    remindHour: hour,
    remindMinute: minute,
    date: date,
    weekdays: weekdays,
    dayOfMonth: dayOfMonth,
    startDate: startDate,
    endDate: endDate,
    priority: priority,
    pinned: pinned,
    createdAt: 0,
    updatedAt: 0,
  );
}

void main() {
  group('isActiveOn', () {
    test('一次性任务只在当天生效', () {
      final t = _task(date: '2026-08-30');
      expect(t.isActiveOn(DateTime(2026, 8, 30)), isTrue);
      expect(t.isActiveOn(DateTime(2026, 8, 25)), isFalse);
    });

    test('每天任务在窗口内生效，窗口外失效', () {
      final t = _task(
        repeatType: RepeatType.daily,
        startDate: '2026-08-20',
        endDate: '2026-08-28',
      );
      expect(t.isActiveOn(DateTime(2026, 8, 25)), isTrue);
      expect(t.isActiveOn(DateTime(2026, 8, 29)), isFalse);
      expect(t.isActiveOn(DateTime(2026, 8, 19)), isFalse);
    });

    test('每周任务只在勾选的星期几生效', () {
      final t = _task(repeatType: RepeatType.weekly, weekdays: {1, 4});
      // 2026-08-25 周二，2026-08-27 周四
      expect(t.isActiveOn(DateTime(2026, 8, 27)), isTrue);
      expect(t.isActiveOn(DateTime(2026, 8, 25)), isFalse);
    });

    test('每月任务只在指定号数生效', () {
      final t = _task(repeatType: RepeatType.monthly, dayOfMonth: 15);
      expect(t.isActiveOn(DateTime(2026, 8, 15)), isTrue);
      expect(t.isActiveOn(DateTime(2026, 8, 16)), isFalse);
    });
  });

  group('nextOccurrence 时间窗口', () {
    test('已过结束日期返回 null', () {
      final t = _task(
        repeatType: RepeatType.daily,
        endDate: '2026-08-24',
      );
      expect(t.nextOccurrence(DateTime(2026, 8, 25, 8, 0)), isNull);
    });

    test('开始日期在未来，则从开始日期起算', () {
      final t = _task(
        repeatType: RepeatType.daily,
        startDate: '2026-08-30',
        hour: 8,
        minute: 0,
      );
      // 8/25 设置，应从 8/30 08:00 开始
      expect(
        t.nextOccurrence(DateTime(2026, 8, 25, 9, 0)),
        DateTime(2026, 8, 30, 8, 0),
      );
    });
  });

  group('isDoneOn', () {
    test('一次性任务完成态与查看日期无关', () {
      final t = _task(date: '2026-08-30').copyWith(doneToday: true);
      expect(t.isDoneOn(DateTime(2026, 8, 30)), isTrue);
      expect(t.isDoneOn(DateTime(2026, 8, 31)), isTrue);
    });

    test('重复任务只在今天显示已完成，翻到其他日期为未完成', () {
      final done =
          _task(repeatType: RepeatType.daily).copyWith(doneToday: true);
      expect(done.isDoneOn(DateTime.now()), isTrue);
      expect(
        done.isDoneOn(DateTime.now().add(const Duration(days: 1))),
        isFalse,
      );
      final pending = _task(repeatType: RepeatType.daily);
      expect(pending.isDoneOn(DateTime.now()), isFalse);
    });
  });

  group('sortTasks', () {
    test('置顶优先；重要性模式高在前，时间模式按时间', () {
      final low = _task(date: '2027-01-01', priority: Priority.low);
      final high = _task(date: '2027-01-02', priority: Priority.high);
      final pinned = _task(date: '2027-01-03', priority: Priority.low, pinned: true);

      final byTime = sortTasks([low, high, pinned], SortMode.time);
      expect(byTime.map((e) => e.title).toList().length, 3);
      expect(byTime.first.pinned, isTrue);
      // 去掉置顶后按时间：low(01-01) 在 high(01-02) 前
      final timeRest = byTime.skip(1).toList();
      expect(timeRest[0].date, '2027-01-01');

      final byImp = sortTasks([low, high, pinned], SortMode.importance);
      expect(byImp.first.pinned, isTrue);
      // 重要性模式：high 在 low 前
      final impRest = byImp.skip(1).toList();
      expect(impRest[0].priority, Priority.high);
    });

    test('doneLast 开启时已完成的排在未完成下面', () {
      final done = _task(date: '2027-01-01').copyWith(doneToday: true);
      final pending = _task(date: '2027-01-02');

      // 开关关闭：按时间，已完成（01-01）在前
      final off = sortTasks([done, pending], SortMode.time);
      expect(off.map((e) => e.doneToday).toList(), [true, false]);

      // 开关开启：未完成排前
      final on = sortTasks([done, pending], SortMode.time, doneLast: true);
      expect(on.map((e) => e.doneToday).toList(), [false, true]);
    });

    test('doneLast 在非今天视图不把重复任务当已完成', () {
      final done = _task(repeatType: RepeatType.daily, hour: 9, minute: 0)
          .copyWith(doneToday: true);
      final pending = _task(repeatType: RepeatType.daily, hour: 10, minute: 0);
      final tomorrow = DateTime.now().add(const Duration(days: 1));

      // 明天视图：重复任务都不算已完成，按时间排（09:00 在前）。
      final byDay = sortTasks([pending, done], SortMode.time,
          doneLast: true, viewDay: tomorrow);
      expect(byDay.first.doneToday, isTrue);

      // 不传视图日（默认按 doneToday）：已完成的排后。
      final byDone = sortTasks([pending, done], SortMode.time, doneLast: true);
      expect(byDone.first.doneToday, isFalse);
    });
  });
}
