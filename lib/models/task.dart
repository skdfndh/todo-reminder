import '../utils/schedule.dart';

/// 待办事项的重复类型。
enum RepeatType {
  once('一次性'),
  daily('每天'),
  weekly('每周'),
  monthly('每月');

  const RepeatType(this.label);

  /// 界面上显示的中文名。
  final String label;

  static RepeatType fromCode(String code) => RepeatType.values.firstWhere(
    (e) => e.name == code,
    orElse: () => RepeatType.once,
  );
}

/// 重要性，值越大越重要。
enum Priority {
  low('低', 0),
  medium('中', 1),
  high('高', 2);

  const Priority(this.label, this.value);

  final String label;
  final int value;

  static Priority fromValue(int v) => Priority.values.firstWhere(
    (e) => e.value == v,
    orElse: () => Priority.medium,
  );
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// 一条待办事项。
class Task {
  const Task({
    this.id,
    required this.title,
    this.note = '',
    this.tags = const {},
    required this.repeatType,
    required this.remindHour,
    required this.remindMinute,
    this.advanceMinutes = 0,
    this.date,
    this.weekdays = const {},
    this.dayOfMonth,
    this.enabled = true,
    this.priority = Priority.medium,
    this.pinned = false,
    this.statisticsEnabled = false,
    this.startDate,
    this.endDate,
    this.doneToday = false,
    this.doneDate,
    this.doneCount = 0,
    this.completedDates = const {},
    this.sourceQuickTaskId,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String title;
  final String note;
  final Set<String> tags;

  final RepeatType repeatType;

  /// 提醒时刻：小时（0-23）。
  final int remindHour;

  /// 提醒时刻：分钟（0-59）。
  final int remindMinute;

  final int advanceMinutes;

  /// 仅 [RepeatType.once] 使用，格式 YYYY-MM-DD。
  final String? date;

  /// 仅 [RepeatType.weekly] 使用，1=周一 … 7=周日。
  final Set<int> weekdays;

  /// 仅 [RepeatType.monthly] 使用，1-31。
  final int? dayOfMonth;

  /// 是否启用（重复任务可临时暂停）。
  final bool enabled;

  final Priority priority;

  /// 手动置顶。
  final bool pinned;

  /// 是否统计完成天数。
  final bool statisticsEnabled;

  /// 时间窗口起始（仅重复任务），格式 YYYY-MM-DD。
  final String? startDate;

  /// 时间窗口结束（仅重复任务），格式 YYYY-MM-DD。
  final String? endDate;

  /// 当前完成状态。
  final bool doneToday;

  /// 本次打勾对应的日期（用于跨天复位判断），格式 YYYY-MM-DD。
  final String? doneDate;

  /// 累计完成天数。
  final int doneCount;

  final Set<String> completedDates;

  /// 从常用一次性待办创建时记录其模板 ID，供使用统计关联。
  final int? sourceQuickTaskId;

  final int createdAt;
  final int updatedAt;

  /// 提醒时刻的显示文本，如 08:05。
  String get timeLabel =>
      '${remindHour.toString().padLeft(2, '0')}:${remindMinute.toString().padLeft(2, '0')}';

  /// 重复规则的中文描述（一次性任务返回日期字符串）。
  String get repeatRuleLabel {
    switch (repeatType) {
      case RepeatType.once:
        return date ?? '';
      case RepeatType.daily:
        return '每天';
      case RepeatType.weekly:
        const names = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
        final sorted = weekdays.toList()..sort();
        return sorted.map((d) => names[d]).join('、');
      case RepeatType.monthly:
        return '每月 ${dayOfMonth ?? 1} 号';
    }
  }

  DateTime get _effectiveStartDay {
    final created = _dateOnly(DateTime.fromMillisecondsSinceEpoch(createdAt));
    final configured = startDate != null
        ? _dateOnly(DateTime.parse(startDate!))
        : null;
    if (configured == null || !configured.isAfter(created)) return created;
    return configured;
  }

  /// 重复待办从设立当天或设置的更晚开始日期起生效。
  DateTime windowFrom(DateTime from) {
    final start = _effectiveStartDay;
    return start.isAfter(from) ? start : from;
  }

  /// [next] 是否已超出结束日期（窗口结束）。
  bool isPastEnd(DateTime next) {
    final e = endDate;
    if (e == null) return false;
    final ed = DateTime.parse(e);
    return _dateOnly(next).isAfter(_dateOnly(ed));
  }

  /// 该任务在 [day] 这一天是否生效（用于「按天」视图过滤）。
  bool isActiveOn(DateTime day) {
    final d = _dateOnly(day);
    if (repeatType != RepeatType.once) {
      final e = endDate != null ? DateTime.parse(endDate!) : null;
      if (d.isBefore(_effectiveStartDay)) return false;
      if (e != null && d.isAfter(_dateOnly(e))) return false;
    }
    switch (repeatType) {
      case RepeatType.once:
        final dd = date != null ? DateTime.parse(date!) : null;
        return dd != null && _dateOnly(dd) == d;
      case RepeatType.daily:
        return true;
      case RepeatType.weekly:
        return weekdays.contains(d.weekday);
      case RepeatType.monthly:
        return d.day ==
            (dayOfMonth ?? 1).clamp(1, daysInMonth(d.year, d.month));
    }
  }

  /// 在 [day] 这一天的视图下是否显示为「已完成」。
  ///
  /// 完成状态只属于打勾当天；跨天复位后，过去日期不会继续显示为已完成。
  bool isDoneOn(DateTime day) {
    return completedDates.contains(dateKey(day));
  }

  static String dateKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  /// 从 [from] 之后的下一次提醒发生时间（本地墙钟时间）。
  /// 已超出窗口返回 null；一次性任务若已过期仍返回其原始时间供界面标注。
  DateTime? nextOccurrence(DateTime from) {
    switch (repeatType) {
      case RepeatType.once:
        final d = date;
        if (d == null) return null;
        final parsed = DateTime.parse(d);
        return DateTime(
          parsed.year,
          parsed.month,
          parsed.day,
          remindHour,
          remindMinute,
        );
      case RepeatType.daily:
        final next = nextDaily(windowFrom(from), remindHour, remindMinute);
        return isPastEnd(next) ? null : next;
      case RepeatType.weekly:
        if (weekdays.isEmpty) return null;
        final f = windowFrom(from);
        DateTime? earliest;
        for (final wd in weekdays) {
          final c = nextWeekly(f, wd, remindHour, remindMinute);
          if (earliest == null || c.isBefore(earliest)) earliest = c;
        }
        return (earliest == null || isPastEnd(earliest)) ? null : earliest;
      case RepeatType.monthly:
        final next = nextMonthly(
          windowFrom(from),
          dayOfMonth ?? 1,
          remindHour,
          remindMinute,
        );
        return isPastEnd(next) ? null : next;
    }
  }

  /// 每个调度槽位的下一次发生时间（weekly 每个星期几各一个，其余一个）。
  /// 供通知服务调度使用。返回的 [record] 首位是该槽位对应的星期几（非 weekly 为 0）。
  List<({int weekday, DateTime time})> nextOccurrences(DateTime from) {
    switch (repeatType) {
      case RepeatType.once:
        final n = nextOccurrence(from);
        return n == null ? const [] : [(weekday: 0, time: n)];
      case RepeatType.daily:
        final n = nextOccurrence(from);
        return n == null ? const [] : [(weekday: 0, time: n)];
      case RepeatType.weekly:
        final f = windowFrom(from);
        return [
          for (final wd in weekdays)
            if (!isPastEnd(nextWeekly(f, wd, remindHour, remindMinute)))
              (weekday: wd, time: nextWeekly(f, wd, remindHour, remindMinute)),
        ];
      case RepeatType.monthly:
        final n = nextOccurrence(from);
        return n == null ? const [] : [(weekday: 0, time: n)];
    }
  }

  Task copyWith({
    int? id,
    String? title,
    String? note,
    Set<String>? tags,
    RepeatType? repeatType,
    int? remindHour,
    int? remindMinute,
    int? advanceMinutes,
    Object? date = _unset,
    Set<int>? weekdays,
    Object? dayOfMonth = _unset,
    bool? enabled,
    Priority? priority,
    bool? pinned,
    bool? statisticsEnabled,
    Object? startDate = _unset,
    Object? endDate = _unset,
    bool? doneToday,
    Object? doneDate = _unset,
    int? doneCount,
    Set<String>? completedDates,
    Object? sourceQuickTaskId = _unset,
    int? createdAt,
    int? updatedAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      note: note ?? this.note,
      tags: tags ?? this.tags,
      repeatType: repeatType ?? this.repeatType,
      remindHour: remindHour ?? this.remindHour,
      remindMinute: remindMinute ?? this.remindMinute,
      advanceMinutes: advanceMinutes ?? this.advanceMinutes,
      date: identical(date, _unset) ? this.date : date as String?,
      weekdays: weekdays ?? this.weekdays,
      dayOfMonth: identical(dayOfMonth, _unset)
          ? this.dayOfMonth
          : dayOfMonth as int?,
      enabled: enabled ?? this.enabled,
      priority: priority ?? this.priority,
      pinned: pinned ?? this.pinned,
      statisticsEnabled: statisticsEnabled ?? this.statisticsEnabled,
      startDate: identical(startDate, _unset)
          ? this.startDate
          : startDate as String?,
      endDate: identical(endDate, _unset) ? this.endDate : endDate as String?,
      doneToday: doneToday ?? this.doneToday,
      doneDate: identical(doneDate, _unset)
          ? this.doneDate
          : doneDate as String?,
      doneCount: doneCount ?? this.doneCount,
      completedDates: completedDates ?? this.completedDates,
      sourceQuickTaskId: identical(sourceQuickTaskId, _unset)
          ? this.sourceQuickTaskId
          : sourceQuickTaskId as int?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static const _unset = Object();

  Map<String, Object?> toMap() {
    final map = <String, Object?>{
      'title': title,
      'note': note,
      'tags': tags.isEmpty ? null : (tags.toList()..sort()).join(','),
      'repeat_type': repeatType.name,
      'remind_hour': remindHour,
      'remind_minute': remindMinute,
      'advance_minutes': advanceMinutes,
      'date': date,
      'weekdays': weekdays.isEmpty
          ? null
          : (weekdays.toList()..sort()).join(','),
      'day_of_month': dayOfMonth,
      'enabled': enabled ? 1 : 0,
      'priority': priority.value,
      'pinned': pinned ? 1 : 0,
      'statistics_enabled': statisticsEnabled ? 1 : 0,
      'start_date': startDate,
      'end_date': endDate,
      'done_today': doneToday ? 1 : 0,
      'done_date': doneDate,
      'done_count': doneCount,
      'source_quick_task_id': sourceQuickTaskId,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory Task.fromMap(Map<String, Object?> map) {
    final wdStr = map['weekdays'] as String?;
    final tagStr = map['tags'] as String?;
    return Task(
      id: map['id'] as int?,
      title: map['title'] as String,
      note: (map['note'] as String?) ?? '',
      tags: (tagStr == null || tagStr.isEmpty)
          ? <String>{}
          : tagStr.split(',').toSet(),
      repeatType: RepeatType.fromCode(map['repeat_type'] as String),
      remindHour: map['remind_hour'] as int,
      remindMinute: map['remind_minute'] as int,
      advanceMinutes: map['advance_minutes'] as int? ?? 0,
      date: map['date'] as String?,
      weekdays: (wdStr == null || wdStr.isEmpty)
          ? <int>{}
          : wdStr.split(',').map(int.parse).toSet(),
      dayOfMonth: map['day_of_month'] as int?,
      enabled: (map['enabled'] as int? ?? 1) == 1,
      priority: Priority.fromValue(map['priority'] as int? ?? 1),
      pinned: (map['pinned'] as int? ?? 0) == 1,
      statisticsEnabled: (map['statistics_enabled'] as int? ?? 0) == 1,
      startDate: map['start_date'] as String?,
      endDate: map['end_date'] as String?,
      doneToday: (map['done_today'] as int? ?? 0) == 1,
      doneDate: map['done_date'] as String?,
      doneCount: map['done_count'] as int? ?? 0,
      sourceQuickTaskId: map['source_quick_task_id'] as int?,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
    );
  }
}
