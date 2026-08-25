import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/task_providers.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 用同一个容器做初始化，保证后续界面复用相同的仓库/通知服务实例。
  final container = ProviderContainer();

  final notif = container.read(notificationServiceProvider);
  await notif.init();
  await notif.requestPermissions();

  // 启动时全量重排一次通知，保证杀进程/重启后提醒仍有效。
  final repo = container.read(taskRepositoryProvider);
  final tasks = await repo.getAll();
  await notif.rescheduleAll(tasks);

  runApp(UncontrolledProviderScope(
    container: container,
    child: const TodoReminderApp(),
  ));
}

class TodoReminderApp extends StatelessWidget {
  const TodoReminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '待办提醒',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const HomeScreen(),
    );
  }
}
