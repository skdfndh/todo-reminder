// 计算下一次提醒发生时间的纯函数集合。
//
// 这里的所有 `from` 参数与返回值都是「本地墙钟时间」的 [DateTime]，
// 不含时区信息；通知服务层会再包装成 `tz.TZDateTime` 用于调度。
// 统一放这里，保证界面排序与通知调度的下一次时间计算完全一致。

/// 某年某月的天数。
int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// 每天 [hour]:[minute]，返回严格晚于 [from] 的下一次。
DateTime nextDaily(DateTime from, int hour, int minute) {
  var c = DateTime(from.year, from.month, from.day, hour, minute);
  if (!c.isAfter(from)) c = c.add(const Duration(days: 1));
  return c;
}

/// 每周 [weekday]（1=周一 … 7=周日）的 [hour]:[minute]，返回严格晚于 [from] 的下一次。
DateTime nextWeekly(DateTime from, int weekday, int hour, int minute) {
  var c = DateTime(from.year, from.month, from.day, hour, minute);
  final diff = (weekday - c.weekday) % 7;
  c = c.add(Duration(days: diff));
  if (!c.isAfter(from)) c = c.add(const Duration(days: 7));
  return c;
}

/// 每月 [dayOfMonth] 号的 [hour]:[minute]，返回严格晚于 [from] 的下一次。
/// 当月天数不足时（如 2 月没有 30/31 号）自动取当月最后一天。
DateTime nextMonthly(DateTime from, int dayOfMonth, int hour, int minute) {
  var year = from.year;
  var month = from.month;
  var day = dayOfMonth.clamp(1, daysInMonth(year, month));
  var c = DateTime(year, month, day, hour, minute);
  if (!c.isAfter(from)) {
    month += 1;
    if (month > 12) {
      month = 1;
      year += 1;
    }
    day = dayOfMonth.clamp(1, daysInMonth(year, month));
    c = DateTime(year, month, day, hour, minute);
  }
  return c;
}
