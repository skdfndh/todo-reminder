import 'package:flutter_test/flutter_test.dart';
import 'package:todo_reminder/models/task.dart';
import 'package:todo_reminder/utils/statistics.dart';

Task _task({
  required RepeatType repeatType,
  required Set<String> completedDates,
}) => Task(
  title: '统计',
  repeatType: repeatType,
  remindHour: 9,
  remindMinute: 0,
  date: repeatType == RepeatType.once ? '2026-08-03' : null,
  completedDates: completedDates,
  createdAt: DateTime(2026, 8, 1).millisecondsSinceEpoch,
  updatedAt: 0,
);

void main() {
  test('每日待办统计设立、应完成与完成次数', () {
    final result = taskStatistics(
      [
        _task(
          repeatType: RepeatType.daily,
          completedDates: {'2026-08-01', '2026-08-03'},
        ),
      ],
      StatisticsRange.month,
      now: DateTime(2026, 8, 3),
    );
    expect(result.setupCount, 1);
    expect(result.dueCount, 3);
    expect(result.completedCount, 2);
    expect(result.missedCount, 1);
  });
}
