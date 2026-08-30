import '../models/task.dart';

enum StatisticsRange {
  all('全部时间'),
  month('本月'),
  last30Days('近 30 天');

  const StatisticsRange(this.label);

  final String label;

  DateTime start(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (this) {
      StatisticsRange.all => DateTime(2000),
      StatisticsRange.month => DateTime(now.year, now.month),
      StatisticsRange.last30Days => today.subtract(const Duration(days: 29)),
    };
  }
}

class CompletionStatistics {
  const CompletionStatistics({
    required this.setupCount,
    required this.dueCount,
    required this.completedCount,
  });

  final int setupCount;
  final int dueCount;
  final int completedCount;

  int get missedCount => (dueCount - completedCount).clamp(0, dueCount);
  int get completionRate =>
      dueCount == 0 ? 0 : (completedCount * 100 ~/ dueCount);
}

CompletionStatistics taskStatistics(
  Iterable<Task> tasks,
  StatisticsRange range, {
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final end = DateTime(current.year, current.month, current.day);
  final start = range.start(end);
  var setupCount = 0;
  var dueCount = 0;
  var completedCount = 0;

  for (final task in tasks) {
    final created = DateTime.fromMillisecondsSinceEpoch(task.createdAt);
    final createdDay = DateTime(created.year, created.month, created.day);
    if (!createdDay.isBefore(start) && !createdDay.isAfter(end)) setupCount++;

    var firstDay = createdDay.isAfter(start) ? createdDay : start;
    if (task.startDate != null) {
      final configured = DateTime.parse(task.startDate!);
      if (configured.isAfter(firstDay)) firstDay = configured;
    }
    var lastDay = end;
    if (task.endDate != null) {
      final configured = DateTime.parse(task.endDate!);
      if (configured.isBefore(lastDay)) lastDay = configured;
    }
    for (
      var day = firstDay;
      !day.isAfter(lastDay);
      day = day.add(const Duration(days: 1))
    ) {
      if (task.isActiveOn(day)) dueCount++;
    }
    completedCount += task.completedDates
        .map(DateTime.parse)
        .where((day) => !day.isBefore(start) && !day.isAfter(end))
        .length;
  }
  return CompletionStatistics(
    setupCount: setupCount,
    dueCount: dueCount,
    completedCount: completedCount,
  );
}
