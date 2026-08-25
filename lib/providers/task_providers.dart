import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/task_repository.dart';
import '../models/task.dart';
import '../services/notification_service.dart';

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

final sortModeProvider = StateProvider<SortMode>((ref) => SortMode.time);

final tasksProvider =
    AsyncNotifierProvider<TasksNotifier, List<Task>>(TasksNotifier.new);

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 按排序方式排序（置顶最前，其次重要性/时间）。
List<Task> sortTasks(List<Task> tasks, SortMode mode) {
  final now = DateTime.now();
  int cmp(Task a, Task b) {
    if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
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
    // 跨天复位：重复任务昨天打勾的，今天自动复位（保留累计次数）。
    final today = dateKey(DateTime.now());
    var changed = false;
    final normalized = <Task>[];
    for (final t in tasks) {
      if (t.repeatType != RepeatType.once && t.doneToday && t.doneDate != today) {
        changed = true;
        normalized.add(t.copyWith(doneToday: false, doneDate: null));
      } else {
        normalized.add(t);
      }
    }
    if (changed) {
      for (final t in normalized) {
        await _repo.update(t);
      }
    }
    return normalized;
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

  Future<void> toggleDone(Task task) async {
    final now = DateTime.now();
    final today = dateKey(now);
    final done = !task.doneToday;
    var count = task.doneCount;
    if (done && !task.doneToday) count += 1;
    if (!done && task.doneToday) count = count > 0 ? count - 1 : 0;

    final saved = await _repo.update(task.copyWith(
      doneToday: done,
      doneDate: done ? today : null,
      doneCount: count,
      updatedAt: now.millisecondsSinceEpoch,
    ));

    // 一次性任务完成/取消完成时同步提醒。
    if (task.repeatType == RepeatType.once) {
      if (done) {
        await _notif.cancelTaskById(task.id);
      } else if (saved.enabled) {
        await _notif.scheduleTask(saved);
      }
    }
    await _refresh();
  }

  Future<void> togglePin(Task task) async {
    await _repo.update(task.copyWith(
      pinned: !task.pinned,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    ));
    await _refresh();
  }

  /// 午夜跨天：复位当天打勾、重排通知、刷新列表。
  Future<void> rollover() async {
    final tasks = await _repo.getAll();
    final today = dateKey(DateTime.now());
    for (final t in tasks) {
      if (t.repeatType != RepeatType.once &&
          t.doneToday &&
          t.doneDate != today) {
        await _repo.update(t.copyWith(doneToday: false, doneDate: null));
      }
    }
    final fresh = await _repo.getAll();
    await _notif.rescheduleAll(fresh);
    state = AsyncData(fresh);
  }
}
