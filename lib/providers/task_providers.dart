import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/task_repository.dart';
import '../models/task.dart';
import '../services/notification_service.dart';
import '../services/backup_service.dart';
import '../services/update_service.dart';

/// 列表排序方式。
enum SortMode {
  time('按时间'),
  importance('重要性优先');

  const SortMode(this.label);

  final String label;
}

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(AppDatabase.instance);
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService();
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.read(taskRepositoryProvider));
});

final sortModeProvider = StateProvider<SortMode>((ref) => SortMode.time);

/// 是否把已完成的待办自动排在未完成下面。
final doneLastProvider = StateProvider<bool>((ref) => false);
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

final tasksProvider = AsyncNotifierProvider<TasksNotifier, List<Task>>(
  TasksNotifier.new,
);

final quickTasksProvider = FutureProvider<List<QuickTask>>((ref) {
  return ref.read(taskRepositoryProvider).getQuickTasks();
});

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 明日提示只保留非每日重复的高优先级事项，避免每天重复事项反复打扰。
List<Task> tomorrowImportantTasks(List<Task> tasks, DateTime tomorrow) {
  return tasks
      .where(
        (task) =>
            task.priority == Priority.high &&
            task.repeatType != RepeatType.daily &&
            task.isActiveOn(tomorrow),
      )
      .toList();
}

/// 按排序方式排序（置顶最前，其次已完成分组，再其次重要性/时间）。
///
/// [viewDay] 为按天视图当前查看的日期：已完成分组按该日期的完成态判断
/// （非今天查看重复任务时它们都未完成，不参与分组）。
List<Task> sortTasks(
  List<Task> tasks,
  SortMode mode, {
  bool doneLast = false,
  DateTime? viewDay,
}) {
  final now = DateTime.now();
  int cmp(Task a, Task b) {
    if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
    // 开关开启时，已完成的统一排到未完成下面（置顶仍最前）。
    if (doneLast) {
      final day = viewDay ?? now;
      final da = a.isDoneOn(day);
      final db = b.isDoneOn(day);
      if (da != db) return da ? 1 : -1;
    }
    if (mode == SortMode.importance && a.priority.value != b.priority.value) {
      return b.priority.value.compareTo(a.priority.value);
    }
    final na = a.nextOccurrence(now);
    final nb = b.nextOccurrence(now);
    if (na == null && nb == null) return 0;
    if (na == null) return 1;
    if (nb == null) return -1;
    return na.compareTo(nb);
  }

  return [...tasks]..sort(cmp);
}

/// 任务列表状态：负责数据库读写，并在每次变更后同步通知调度。
class TasksNotifier extends AsyncNotifier<List<Task>> {
  TaskRepository get _repo => ref.read(taskRepositoryProvider);
  NotificationService get _notif => ref.read(notificationServiceProvider);

  @override
  Future<List<Task>> build() async {
    final tasks = await _repo.getAll();
    final mode = await _repo.setting('sort_mode');
    final doneLast = await _repo.setting('done_last');
    final theme = await _repo.setting('theme_mode');
    if (mode != null) {
      ref
          .read(sortModeProvider.notifier)
          .state = mode == SortMode.importance.name
          ? SortMode.importance
          : SortMode.time;
    }
    if (doneLast != null) {
      ref.read(doneLastProvider.notifier).state = doneLast == 'true';
    }
    if (theme != null) {
      ref.read(themeModeProvider.notifier).state = ThemeMode.values.firstWhere(
        (item) => item.name == theme,
        orElse: () => ThemeMode.system,
      );
    }
    return tasks;
  }

  Future<void> _refresh() async {
    state = AsyncData(await _repo.getAll());
  }

  Future<void> add(Task task) async {
    final saved = await _repo.insert(task);
    if (saved.enabled) await _notif.scheduleTask(saved);
    await _refresh();
  }

  Future<void> updateTask(Task task) async {
    await _notif.cancelTaskById(task.id);
    final saved = await _repo.update(task);
    if (saved.enabled) await _notif.scheduleTask(saved);
    await _refresh();
  }

  Future<void> remove(Task task) async {
    await _notif.cancelTaskById(task.id);
    await _repo.delete(task.id!);
    await _refresh();
  }

  Future<void> setEnabled(Task task, bool enabled) async {
    if (!enabled) await _notif.cancelTaskById(task.id);
    final saved = await _repo.update(task.copyWith(enabled: enabled));
    if (enabled) await _notif.scheduleTask(saved);
    await _refresh();
  }

  Future<void> toggleDone(Task task, DateTime viewDay) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(viewDay.year, viewDay.month, viewDay.day);
    if (day.isAfter(today) || task.id == null) return;
    final done = !task.isDoneOn(day);
    var count = task.doneCount;
    if (task.statisticsEnabled) count += done ? 1 : -1;
    if (count < 0) count = 0;
    final doneToday = day == today ? done : task.isDoneOn(today);

    await _repo.setCompleted(task.id!, Task.dateKey(day), done);
    final saved = await _repo.update(
      task.copyWith(
        doneToday: doneToday,
        doneDate: doneToday ? Task.dateKey(today) : null,
        doneCount: count,
        updatedAt: now.millisecondsSinceEpoch,
      ),
    );

    // 一次性任务在任务当天完成/取消完成时同步提醒。
    if (task.repeatType == RepeatType.once && day == today) {
      if (done) {
        await _notif.cancelTaskById(task.id);
      } else if (saved.enabled) {
        await _notif.scheduleTask(saved);
      }
    }
    await _refresh();
  }

  Future<void> togglePin(Task task) async {
    await _repo.update(
      task.copyWith(
        pinned: !task.pinned,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await _refresh();
  }

  /// 午夜跨天：重排通知、刷新列表。
  Future<void> rollover() async {
    final fresh = await _repo.getAll();
    await _notif.rescheduleAll(fresh);
    state = AsyncData(fresh);
  }
}
