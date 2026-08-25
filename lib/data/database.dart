import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// SQLite 数据库单例，负责建库、建表与迁移。
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'todo_reminder.db');
    return openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(_createTable);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // v1 -> v2：为已有表新增列（保留旧数据）。
      await db.execute(
          'ALTER TABLE tasks ADD COLUMN priority INTEGER NOT NULL DEFAULT 1');
      await db.execute(
          'ALTER TABLE tasks ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          'ALTER TABLE tasks ADD COLUMN statistics_enabled INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE tasks ADD COLUMN start_date TEXT');
      await db.execute('ALTER TABLE tasks ADD COLUMN end_date TEXT');
      await db.execute(
          'ALTER TABLE tasks ADD COLUMN done_today INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE tasks ADD COLUMN done_date TEXT');
      await db.execute(
          'ALTER TABLE tasks ADD COLUMN done_count INTEGER NOT NULL DEFAULT 0');
    }
  }

  static const _createTable = '''
    CREATE TABLE tasks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      note TEXT NOT NULL DEFAULT '',
      repeat_type TEXT NOT NULL,
      remind_hour INTEGER NOT NULL,
      remind_minute INTEGER NOT NULL,
      date TEXT,
      weekdays TEXT,
      day_of_month INTEGER,
      enabled INTEGER NOT NULL DEFAULT 1,
      priority INTEGER NOT NULL DEFAULT 1,
      pinned INTEGER NOT NULL DEFAULT 0,
      statistics_enabled INTEGER NOT NULL DEFAULT 0,
      start_date TEXT,
      end_date TEXT,
      done_today INTEGER NOT NULL DEFAULT 0,
      done_date TEXT,
      done_count INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''';
}
