class ImportedTaskDraft {
  const ImportedTaskDraft({
    required this.title,
    required this.note,
    required this.deadline,
    required this.timeWasInferred,
  });

  final String title;
  final String note;
  final DateTime? deadline;
  final bool timeWasInferred;
}

final _datePattern = RegExp(
  r'(?<![\d/-])(?:(?:(?<year>\d{4})年\s*)?(?<month>\d{1,2})月\s*(?<day>\d{1,2})[日号]'
  r'|(?:(?<numericYear>\d{4})[-/])?(?<numericMonth>\d{1,2})[-/](?<numericDay>\d{1,2})(?![/-])'
  r'|(?<relative>今天|今日|明天|明日|后天)'
  r'|(?<week>本|这|下)?(?:周|星期|礼拜)(?<weekday>[一二三四五六日天1-7]))(?!\d)'
  r'(?:\s*[（(](?:周|星期|礼拜)[一二三四五六日天1-7][）)])?',
);
final _timePattern = RegExp(
  r'^\s*(?:的|T)?\s*(?<period>凌晨|早上|上午|中午|下午|傍晚|晚上)?\s*'
  r'(?:(?<clockHour>\d{1,2})\s*:\s*(?<clockMinute>\d{1,2})(?!\d)'
  r'|(?<spokenHour>\d{1,2})\s*[点时](?:\s*(?:(?<spokenMinute>\d{1,2})\s*分?|(?<half>半)))?(?!\d))',
);
final _deadlinePrefix = RegExp(
  r'(?:截止(?:日期|时间)?|截至)\s*[:为至到是]?\s*$|最晚\s*[:于在]?\s*$',
);
final _deadlineSuffix = RegExp(r'^\s*(?:之前|以前|前|截止|为止)');
final _sectionPattern = RegExp(
  r'(?:^|[\n。；;，,])\s*(事项标题|标题|事项|任务|具体要求|任务要求|要求|'
  r'需要提交(?:的内容)?|需提交|提交内容|提交材料|提交物|'
  r'截止日期|截止时间|截止)\s*[:：]',
);
final _sentenceBreak = RegExp(r'[\n。；;，,！？!?]');
final _requestPrefix = RegExp(
  r'^(?:(?:请(?:大家|各位|同学们|各组)?|务必|记得|需要|须|在|于)\s*)+',
);
final _actionStart = RegExp(
  r'^(?:提交|上交|交齐|发送|发给|上传|填写|完成|交付|报送|递交|报名|参加|领取|准备)',
);
final _submissionStart = RegExp(r'^(?:提交|上交|交齐|发送|上传|报送|递交)\s*');
final _requirementStart = RegExp(
  r'^(?:格式|文件名|文件格式|文件大小|字数|命名|需附|须附|必须|不得|不超过|至少)',
);
final _alternative = RegExp(r'或|二选一');

ImportedTaskDraft parseTaskText(String text, {DateTime? now}) {
  final original = text.trim();
  final normalized = String.fromCharCodes(
    original.runes.map(
      (rune) => rune >= 0xFF01 && rune <= 0xFF5E ? rune - 0xFEE0 : rune,
    ),
  );
  final base = now ?? DateTime.now();
  final sections = _sectionPattern.allMatches(original).toList();
  final requirements = <String>[];
  final submissions = <String>[];
  String? title;
  for (var i = 0; i < sections.length; i++) {
    final section = sections[i];
    final end = i + 1 < sections.length
        ? sections[i + 1].start
        : original.length;
    final value = original.substring(section.end, end).trim();
    if (value.isEmpty) continue;
    final label = section.group(1)!;
    if (label.contains('要求')) {
      requirements.add(value);
    } else if (label.contains('提交')) {
      submissions.add(value);
    } else if (!label.startsWith('截止')) {
      title ??= value.split(_sentenceBreak).first.trim();
    }
  }

  final deadlines = <DateTime, bool>{};
  var bestScore = 0;
  var hasInvalidDeadline = false;
  var hasAlternative = false;
  final titleCandidates = <String>[];
  for (final clause in normalized.split(_sentenceBreak)) {
    final dates = _datePattern.allMatches(clause).toList();
    for (var i = 0; i < dates.length; i++) {
      final date = dates[i];
      final time = _timePattern.firstMatch(clause.substring(date.end));
      final end = date.end + (time?.end ?? 0);
      final before = clause.substring(0, date.start);
      final after = clause.substring(end);
      final isDeadline =
          _deadlinePrefix.hasMatch(before) || _deadlineSuffix.hasMatch(after);
      final score = isDeadline ? 2 : 1;
      if (score < bestScore) continue;
      if (score > bestScore) {
        deadlines.clear();
        hasInvalidDeadline = false;
        hasAlternative = false;
        bestScore = score;
      }
      if (i + 1 < dates.length &&
          _alternative.hasMatch(clause.substring(end, dates[i + 1].start))) {
        hasAlternative = true;
      }
      final deadline = _readDeadline(date, time, base);
      // 更明确但无法解析的截止时间不能被另一个普通日期替代。
      if (deadline == null) {
        hasInvalidDeadline = true;
      } else {
        deadlines[deadline] = (deadlines[deadline] ?? true) && time == null;
      }
    }

    var candidate = clause
        .replaceFirst(RegExp(r'^\s*(?:通知|提醒|各位同学|同学们)\s*:?\s*'), '')
        .trim()
        .replaceFirst(_requestPrefix, '');
    final leadingDate = _datePattern.matchAsPrefix(candidate);
    if (leadingDate != null) {
      candidate = candidate
          .substring(leadingDate.end)
          .replaceFirst(_timePattern, '')
          .replaceFirst(_deadlineSuffix, '')
          .trim()
          .replaceFirst(_requestPrefix, '');
    }
    candidate = candidate.trim();
    if (candidate.isNotEmpty &&
        !_sectionPattern.hasMatch(candidate) &&
        !_requirementStart.hasMatch(candidate)) {
      titleCandidates.add(candidate);
    }
  }
  final deadline =
      !hasInvalidDeadline && !hasAlternative && deadlines.length == 1
      ? deadlines.keys.single
      : null;
  final action = titleCandidates.where(_actionStart.hasMatch).firstOrNull;
  if (submissions.isEmpty &&
      action != null &&
      _submissionStart.hasMatch(action)) {
    final submission = action.replaceFirst(_submissionStart, '').trim();
    if (submission.isNotEmpty) submissions.add(submission);
  }
  if (requirements.isEmpty) {
    requirements.addAll(
      original
          .split(_sentenceBreak)
          .map((part) => part.trim())
          .where(_requirementStart.hasMatch),
    );
  }
  title ??=
      action ??
      (submissions.isEmpty
          ? null
          : '提交${submissions.first.split(_sentenceBreak).first}') ??
      titleCandidates.firstOrNull ??
      '';
  final summary = title.runes.take(61).toList();
  return ImportedTaskDraft(
    title: summary.length == 61
        ? '${String.fromCharCodes(summary.take(60))}…'
        : title,
    note: [
      if (requirements.isNotEmpty) '要求：${requirements.join('\n')}',
      if (submissions.isNotEmpty) '需提交：${submissions.join('\n')}',
      if (original.isNotEmpty) '原文：\n$original',
    ].join('\n\n'),
    deadline: deadline,
    timeWasInferred: deadline != null && deadlines[deadline]!,
  );
}

DateTime? _readDeadline(RegExpMatch date, RegExpMatch? time, DateTime now) {
  final relative = date.namedGroup('relative');
  final weekday = date.namedGroup('weekday');
  late DateTime day;
  if (relative != null) {
    final offset = switch (relative) {
      '明天' || '明日' => 1,
      '后天' => 2,
      _ => 0,
    };
    day = DateTime(now.year, now.month, now.day + offset);
  } else if (weekday != null) {
    final requested =
        int.tryParse(weekday) ?? '一二三四五六日天'.indexOf(weekday).clamp(0, 6) + 1;
    final offset = requested - now.weekday;
    final days = switch (date.namedGroup('week')) {
      '下' => offset + 7,
      '本' || '这' => offset,
      _ => offset % 7,
    };
    day = DateTime(now.year, now.month, now.day + days);
  } else {
    final explicitYear =
        date.namedGroup('year') ?? date.namedGroup('numericYear');
    final year = explicitYear == null ? now.year : int.parse(explicitYear);
    final month = int.parse(
      date.namedGroup('month') ?? date.namedGroup('numericMonth')!,
    );
    final number = int.parse(
      date.namedGroup('day') ?? date.namedGroup('numericDay')!,
    );
    day = DateTime(year, month, number);
    if (day.year != year ||
        day.month != month ||
        day.day != number ||
        year == 0) {
      return null;
    }
  }
  if (time == null) return DateTime(day.year, day.month, day.day, 23, 59);

  var hour = int.parse(
    time.namedGroup('clockHour') ?? time.namedGroup('spokenHour')!,
  );
  final minute = int.parse(
    time.namedGroup('clockMinute') ??
        time.namedGroup('spokenMinute') ??
        (time.namedGroup('half') == null ? '0' : '30'),
  );
  final period = time.namedGroup('period');
  if (hour < 12 && const {'下午', '傍晚', '晚上'}.contains(period)) {
    hour += 12;
  } else if (period == '中午' && hour < 6) {
    hour += 12;
  } else if (period == '凌晨' && hour == 12) {
    hour = 0;
  }
  if (hour > 23 || minute > 59) return null;
  return DateTime(day.year, day.month, day.day, hour, minute);
}
