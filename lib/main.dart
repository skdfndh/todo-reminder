import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/cloud_config.dart';
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
  // 本地模式也要恢复重启后的提醒计划。
  await notif.rescheduleAll(
    await container.read(taskRepositoryProvider).getAll(),
  );

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const TodoReminderApp(),
    ),
  );

  if (CloudConfig.isConfigured) {
    try {
      await Supabase.initialize(
        url: CloudConfig.url,
        publishableKey: CloudConfig.publishableKey,
      );
      container.read(cloudClientProvider.notifier).state =
          Supabase.instance.client;
    } catch (_) {
      // 云端初始化失败时，待办仍可在本机使用。
    }
  }
}

class TodoReminderApp extends ConsumerWidget {
  const TodoReminderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: '待办提醒',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      darkTheme: buildDarkAppTheme(),
      themeMode: ref.watch(themeModeProvider),
      home: const HomeScreen(),
    );
  }
}
