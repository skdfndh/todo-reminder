import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/task.dart' hide Priority;

/// 本地通知服务：初始化、权限、各类调度、取消与全量重排。
///
/// 通知 ID 规则：
/// - once / daily / monthly 直接使用任务 id；
/// - weekly 每个星期几拆成一条独立通知，ID 用 `id * 100 + weekday`（weekday 1-7）。
/// 取消时统一取消这 8 个候选 ID，避免类型切换后残留旧通知。
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  final ValueNotifier<int?> openedTaskId = ValueNotifier<int?>(null);

  static const _channelId = 'task_reminders';
  static const _channelName = '待办提醒';
  static const _channelDesc = '待办事项到点提醒';

  Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // 获取设备时区失败时保持默认时区，不阻断初始化。
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final id = int.tryParse(response.payload ?? '');
        if (response.actionId == 'snooze_10') {
          _snooze(id);
        } else {
          openedTaskId.value = id;
        }
      },
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      openedTaskId.value = int.tryParse(
        launch?.notificationResponse?.payload ?? '',
      );
    }
    _initialized = true;
  }

  /// 请求通知权限（Android 13+）与精确闹钟权限（Android 14+）。
  Future<void> requestPermissions() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.requestNotificationsPermission();
      await android?.requestExactAlarmsPermission();
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  Future<bool> _canScheduleExact() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.canScheduleExactNotifications() ?? false;
  }

  /// 调度一条任务的提醒。重复任务若被暂停（enabled=false）则跳过。
  Future<void> scheduleTask(Task task) async {
    final id = task.id;
    if (id == null || !task.enabled) return;
    // 一次性任务已完成则不提醒。
    if (task.repeatType == RepeatType.once && task.doneToday) return;
    await init();

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        actions: const [AndroidNotificationAction('snooze_10', '10分钟后提醒')],
      ),
      iOS: const DarwinNotificationDetails(),
    );

    final exact = await _canScheduleExact();
    final mode = exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    final now = tz.TZDateTime.now(tz.local);
    final body = task.title;
    final match = _matchFor(task.repeatType);

    final from = now.add(Duration(minutes: task.advanceMinutes));
    for (final occ in task.nextOccurrences(from)) {
      // 只调度未来时刻（一次性任务若已过期则跳过）。
      final scheduled = occ.time.subtract(
        Duration(minutes: task.advanceMinutes),
      );
      if (!scheduled.isAfter(now)) continue;
      final notifId = occ.weekday == 0 ? id : _weeklyId(id, occ.weekday);
      await _plugin.zonedSchedule(
        id: notifId,
        title: _channelName,
        body: task.advanceMinutes == 0 ? body : '$body（${task.timeLabel}）',
        scheduledDate: tz.TZDateTime.from(scheduled, tz.local),
        notificationDetails: details,
        androidScheduleMode: mode,
        matchDateTimeComponents: match,
        payload: '$id',
      );
    }
  }

  Future<void> _snooze(int? taskId) async {
    if (taskId == null) return;
    await init();
    final time = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 10));
    await _plugin.zonedSchedule(
      id: taskId * 1000 + 99,
      title: _channelName,
      body: '稍后提醒',
      scheduledDate: time,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(_channelId, _channelName),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: '$taskId',
    );
  }

  DateTimeComponents _matchFor(RepeatType type) {
    switch (type) {
      case RepeatType.once:
        return DateTimeComponents.dateAndTime;
      case RepeatType.daily:
        return DateTimeComponents.time;
      case RepeatType.weekly:
        return DateTimeComponents.dayOfWeekAndTime;
      case RepeatType.monthly:
        return DateTimeComponents.dayOfMonthAndTime;
    }
  }

  /// 取消某条任务的所有通知。
  Future<void> cancelTask(Task task) => cancelTaskById(task.id);

  /// 按任务 id 取消（含 weekly 拆分的所有子通知）。
  Future<void> cancelTaskById(int? id) async {
    if (id == null) return;
    await init();
    await _plugin.cancel(id: id);
    for (var d = 1; d <= 7; d++) {
      await _plugin.cancel(id: _weeklyId(id, d));
    }
  }

  /// 应用启动时全量重排：清空后按当前数据重建，保证杀进程/重启后提醒仍有效。
  Future<void> rescheduleAll(List<Task> tasks) async {
    await init();
    await _plugin.cancelAll();
    for (final t in tasks) {
      await scheduleTask(t);
    }
  }

  int _weeklyId(int id, int weekday) => id * 100 + weekday;
}
