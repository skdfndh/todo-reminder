enum WorkStatus {
  completed('已完成'),
  planned('计划');

  const WorkStatus(this.label);
  final String label;
}

class WorkEntry {
  WorkEntry({
    this.id,
    required DateTime date,
    required this.minutes,
    required this.status,
    this.note = '',
  }) : date = DateTime(date.year, date.month, date.day) {
    if (minutes <= 0 || minutes > 24 * 60) {
      throw const FormatException('每次工时需大于 0 且不超过 24 小时');
    }
    if (id != null && id! <= 0) throw const FormatException('工时记录编号无效');
  }

  final int? id;
  final DateTime date;
  final int minutes;
  final WorkStatus status;
  final String note;

  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'date': workDateKey(date),
    'minutes': minutes,
    'status': status.name,
    'note': note,
  };

  factory WorkEntry.fromMap(Map<String, Object?> map) {
    final date = DateTime.tryParse(map['date'] as String? ?? '');
    if (date == null || workDateKey(date) != map['date']) {
      throw const FormatException('工时日期无效');
    }
    final status = WorkStatus.values.where((s) => s.name == map['status']);
    if (status.isEmpty) throw const FormatException('工时状态无效');
    return WorkEntry(
      id: map['id'] as int?,
      date: date,
      minutes: map['minutes'] as int,
      status: status.single,
      note: map['note'] as String? ?? '',
    );
  }
}

String workDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

DateTime workWeekStart(DateTime date) =>
    DateTime(date.year, date.month, date.day - date.weekday + 1);

String formatWorkMinutes(int minutes) {
  final absolute = minutes.abs();
  final hours = absolute ~/ 60;
  final remainder = absolute % 60;
  final text = remainder == 0
      ? '$hours 小时'
      : hours == 0
      ? '$remainder 分钟'
      : '$hours 小时 $remainder 分钟';
  return minutes < 0 ? '-$text' : text;
}

class WorkHoursSummary {
  WorkHoursSummary(Iterable<WorkEntry> entries, DateTime start, DateTime end) {
    for (final entry in entries) {
      if (entry.date.isBefore(start) || !entry.date.isBefore(end)) continue;
      if (entry.status == WorkStatus.completed) {
        completedMinutes += entry.minutes;
      } else {
        plannedMinutes += entry.minutes;
      }
    }
  }

  static const monthlyLimitMinutes = 40 * 60;
  int completedMinutes = 0;
  int plannedMinutes = 0;
  int get totalMinutes => completedMinutes + plannedMinutes;
  int get remainingMinutes => monthlyLimitMinutes - completedMinutes;
  int get availableMinutes => monthlyLimitMinutes - totalMinutes;
}
