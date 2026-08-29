import '../models/task.dart';

import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import 'database.dart';

class QuickTask {
  const QuickTask({
    this.id,
    required this.title,
    this.note = '',
    this.remindHour = 9,
    this.remindMinute = 0,
    this.priority = Priority.medium,
    this.tags = const {},
    this.advanceMinutes = 0,
  });

  final int? id;
  final String title;
  final String note;
  final int remindHour;
  final int remindMinute;
  final Priority priority;
  final Set<String> tags;
  final int advanceMinutes;

  Map<String, Object?> toMap() => {
    'title': title,
    'note': note,
    'remind_hour': remindHour,
    'remind_minute': remindMinute,
    'priority': priority.value,
    'tags': tags.isEmpty ? null : (tags.toList()..sort()).join(','),
    'advance_minutes': advanceMinutes,
  };

  factory QuickTask.fromMap(Map<String, Object?> map) {
    final tags = map['tags'] as String?;
    return QuickTask(
      id: map['id'] as int?,
      title: map['title'] as String,
      note: map['note'] as String? ?? '',
      remindHour: map['remind_hour'] as int? ?? 9,
      remindMinute: map['remind_minute'] as int? ?? 0,
      priority: Priority.fromValue(map['priority'] as int? ?? 1),
      tags: tags == null || tags.isEmpty ? {} : tags.split(',').toSet(),
      advanceMinutes: map['advance_minutes'] as int? ?? 0,
    );
  }
}

/// 任务的增删改查。
class TaskRepository {
  TaskRepository(this._db);

  final AppDatabase _db;

  Future<Task> insert(Task task) async {
    final db = await _db.database;
    final id = await db.insert('tasks', task.toMap());
    return task.copyWith(id: id);
  }

  Future<Task> update(Task task) async {
    final db = await _db.database;
    await db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
    return task;
  }

  Future<void> delete(int id) async {
    final db = await _db.database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Task>> getAll() async {
    final db = await _db.database;
    final rows = await db.query('tasks');
    final completions = await db.query('task_completions');
    final datesByTask = <int, Set<String>>{};
    for (final completion in completions) {
      final id = completion['task_id'] as int;
      (datesByTask[id] ??= {}).add(completion['date'] as String);
    }
    return rows.map((row) {
      final task = Task.fromMap(row);
      return task.copyWith(completedDates: datesByTask[task.id] ?? {});
    }).toList();
  }

  Future<void> setCompleted(int taskId, String date, bool completed) async {
    final db = await _db.database;
    if (completed) {
      await db.insert('task_completions', {'task_id': taskId, 'date': date});
    } else {
      await db.delete(
        'task_completions',
        where: 'task_id = ? AND date = ?',
        whereArgs: [taskId, date],
      );
    }
  }

  Future<String?> setting(String key) async {
    final db = await _db.database;
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await _db.database;
    await db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<QuickTask>> getQuickTasks() async {
    final db = await _db.database;
    final rows = await db.query('quick_tasks', orderBy: 'id DESC');
    return rows.map(QuickTask.fromMap).toList();
  }

  Future<QuickTask> insertQuickTask(QuickTask task) async {
    final db = await _db.database;
    final id = await db.insert('quick_tasks', task.toMap());
    return QuickTask(
      id: id,
      title: task.title,
      note: task.note,
      remindHour: task.remindHour,
      remindMinute: task.remindMinute,
      priority: task.priority,
      tags: task.tags,
      advanceMinutes: task.advanceMinutes,
    );
  }

  Future<void> deleteQuickTask(int id) async {
    final db = await _db.database;
    await db.delete('quick_tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, Object?>> exportData() async {
    final db = await _db.database;
    return {
      'version': 1,
      'tasks': await db.query('tasks'),
      'completions': await db.query('task_completions'),
      'settings': await db.query('settings'),
      'quickTasks': await db.query('quick_tasks'),
    };
  }

  Future<void> importData(Map<String, dynamic> data) async {
    final db = await _db.database;
    final tasks = data['tasks'] as List<dynamic>?;
    if (tasks == null) throw const FormatException('备份文件缺少任务数据');
    await db.transaction((txn) async {
      await txn.delete('task_completions');
      await txn.delete('quick_tasks');
      await txn.delete('settings');
      await txn.delete('tasks');
      for (final row in tasks) {
        await txn.insert('tasks', Map<String, Object?>.from(row as Map));
      }
      for (final row in data['completions'] as List<dynamic>? ?? const []) {
        await txn.insert(
          'task_completions',
          Map<String, Object?>.from(row as Map),
        );
      }
      for (final row in data['settings'] as List<dynamic>? ?? const []) {
        await txn.insert('settings', Map<String, Object?>.from(row as Map));
      }
      for (final row in data['quickTasks'] as List<dynamic>? ?? const []) {
        await txn.insert('quick_tasks', Map<String, Object?>.from(row as Map));
      }
    });
  }
}
