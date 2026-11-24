import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:todo_reminder/main.dart';
import 'package:todo_reminder/models/task.dart';
import 'package:todo_reminder/providers/task_providers.dart';
import 'package:todo_reminder/services/cache_service.dart';

void main() {
  testWidgets('未连接云端时直接打开待办主页', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [tasksProvider.overrideWith(_OfflineTasksNotifier.new)],
        child: const TodoReminderApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('添加待办'), findsOneWidget);
    expect(find.text('登录云端账号'), findsNothing);
  });

  testWidgets('公开版无需登录即可使用，设置仍可进入已授权账号登录', (tester) async {
    final client = (await tester.runAsync(
      () async => SupabaseClient(
        'https://example.com',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
    ))!;
    addTearDown(client.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tasksProvider.overrideWith(_OfflineTasksNotifier.new),
          cloudClientProvider.overrideWith((ref) => client),
          cacheServiceProvider.overrideWithValue(_EmptyCacheService()),
        ],
        child: const TodoReminderApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('添加待办'), findsOneWidget);
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('登录云端账号'), 150);
    await tester.tap(find.text('登录云端账号'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '邮箱'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
    expect(find.textContaining('注册'), findsNothing);
  });
}

class _OfflineTasksNotifier extends TasksNotifier {
  @override
  Future<List<Task>> build() async => [];
}

class _EmptyCacheService extends CacheService {
  @override
  Future<CacheInfo> inspect() async => const CacheInfo(fileCount: 0, bytes: 0);
}
