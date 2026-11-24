import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' show databaseFactorySqflitePlugin;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _databaseName = 'todo_reminder.db';

/// SQLite 数据库单例，负责建库、建表与迁移。
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Future<Database>? _opening;

  Future<Database> get database async {
    final opening = _opening ??= _init();
    try {
      return await opening;
    } catch (_) {
      if (identical(_opening, opening)) _opening = null;
      rethrow;
    }
  }

  Future<Database> _init() async {
    final useFfi = Platform.isWindows || Platform.isLinux;
    if (useFfi) sqfliteFfiInit();
    final factory = useFfi ? databaseFactoryFfi : databaseFactorySqflitePlugin;
    final path = Platform.isWindows
        ? await resolveWindowsDatabasePath(
            factory,
            await getApplicationSupportDirectory(),
            [
              await factory.getDatabasesPath(),
              p.join(
                p.dirname(Platform.resolvedExecutable),
                '.dart_tool',
                'sqflite_common_ffi',
                'databases',
              ),
            ],
          )
        : p.join(await factory.getDatabasesPath(), _databaseName);
    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 5,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(_createTable);
    await _createAuxiliaryTables(db);
    await _createWorkEntries(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // v1 -> v2：为已有表新增列（保留旧数据）。
      await db.execute(
        'ALTER TABLE tasks ADD COLUMN priority INTEGER NOT NULL DEFAULT 1',
      );
      await db.execute(
        'ALTER TABLE tasks ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE tasks ADD COLUMN statistics_enabled INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute('ALTER TABLE tasks ADD COLUMN start_date TEXT');
      await db.execute('ALTER TABLE tasks ADD COLUMN end_date TEXT');
      await db.execute(
        'ALTER TABLE tasks ADD COLUMN done_today INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute('ALTER TABLE tasks ADD COLUMN done_date TEXT');
      await db.execute(
        'ALTER TABLE tasks ADD COLUMN done_count INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE tasks ADD COLUMN tags TEXT');
      await db.execute(
        'ALTER TABLE tasks ADD COLUMN advance_minutes INTEGER NOT NULL DEFAULT 0',
      );
      await _createAuxiliaryTables(db);
    }
    if (oldVersion < 4) {
      // 记录一次性待办的常用模板来源，供模板使用统计准确关联。
      await db.execute(
        'ALTER TABLE tasks ADD COLUMN source_quick_task_id INTEGER',
      );
    }
    if (oldVersion < 5) await _createWorkEntries(db);
  }

  Future<void> _createWorkEntries(Database db) => db.execute('''
    CREATE TABLE IF NOT EXISTS work_entries (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL,
      minutes INTEGER NOT NULL CHECK (minutes > 0 AND minutes <= 1440),
      status TEXT NOT NULL CHECK (status IN ('completed', 'planned')),
      note TEXT NOT NULL DEFAULT ''
    )
  ''');

  Future<void> _createAuxiliaryTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS task_completions (
        task_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        PRIMARY KEY (task_id, date),
        FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS quick_tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        remind_hour INTEGER NOT NULL DEFAULT 9,
        remind_minute INTEGER NOT NULL DEFAULT 0,
        priority INTEGER NOT NULL DEFAULT 1,
        tags TEXT,
        advance_minutes INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  static const _createTable = '''
    CREATE TABLE tasks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      note TEXT NOT NULL DEFAULT '',
      tags TEXT,
      repeat_type TEXT NOT NULL,
      remind_hour INTEGER NOT NULL,
      remind_minute INTEGER NOT NULL,
      advance_minutes INTEGER NOT NULL DEFAULT 0,
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
      source_quick_task_id INTEGER,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''';
}

@visibleForTesting
Future<String> resolveWindowsDatabasePath(
  DatabaseFactory factory,
  Directory appData,
  Iterable<String> legacyDirectories,
) async {
  await appData.create(recursive: true);
  final path = p.join(appData.path, _databaseName);
  if (await File(path).exists()) return path;

  for (final legacyDirectory in legacyDirectories) {
    final legacyPath = p.join(legacyDirectory, _databaseName);
    if (!await File(legacyPath).exists()) continue;

    // 用 SQLite 生成完整快照，保留旧库和其中已提交的写入。
    final staging = await appData.createTemp('db-migration-');
    try {
      final candidate = p.join(staging.path, _databaseName);
      final source = await factory.openDatabase(
        legacyPath,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
      try {
        await source.execute('VACUUM INTO ?', [candidate]);
      } finally {
        await source.close();
      }
      if (!await File(path).exists()) await File(candidate).rename(path);
    } finally {
      await staging.delete(recursive: true);
    }
    break;
  }
  return path;
}
