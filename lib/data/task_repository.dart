import '../models/task.dart';
import 'database.dart';

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
    return rows.map(Task.fromMap).toList();
  }
}
