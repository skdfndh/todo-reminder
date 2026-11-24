import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:todo_reminder/data/database.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('Windows 在用户应用数据目录建库，保留原库及已迁移的数据', () async {
    final root = await Directory.systemTemp.createTemp('todo-db-test-');
    addTearDown(() => root.delete(recursive: true));
    final legacy = Directory(p.join(root.path, 'launcher'));
    final appData = Directory(p.join(root.path, 'app-data', 'todo-reminder'));
    final factory = databaseFactoryFfiNoIsolate;
    final old = await factory.openDatabase(
      p.join(legacy.path, 'todo_reminder.db'),
    );
    addTearDown(old.close);
    await old.execute('CREATE TABLE tasks (title TEXT NOT NULL)');
    await old.insert('tasks', {'title': '旧待办'});

    final path = await resolveWindowsDatabasePath(factory, appData, [
      legacy.path,
    ]);
    expect(path, p.join(appData.path, 'todo_reminder.db'));
    final current = await factory.openDatabase(path);
    addTearDown(current.close);
    expect(await current.query('tasks'), [
      {'title': '旧待办'},
    ]);

    await current.insert('tasks', {'title': '新待办'});
    expect(
      await resolveWindowsDatabasePath(factory, appData, [legacy.path]),
      path,
    );
    expect(await current.query('tasks'), hasLength(2));
    expect(await old.query('tasks'), hasLength(1));
  });
}
