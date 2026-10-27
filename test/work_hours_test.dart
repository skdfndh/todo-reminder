import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_reminder/data/database.dart';
import 'package:todo_reminder/data/task_repository.dart';
import 'package:todo_reminder/models/work_entry.dart';
import 'package:todo_reminder/providers/developer_mode_provider.dart';
import 'package:todo_reminder/providers/task_providers.dart';
import 'package:todo_reminder/providers/work_hours_provider.dart';
import 'package:todo_reminder/screens/work_hours_screen.dart';
import 'package:todo_reminder/widgets/work_entry_dialog.dart';

class _WorkRepository extends TaskRepository {
  _WorkRepository(this.entries) : super(AppDatabase.instance);
  final List<WorkEntry> entries;
  int _nextId = 100;

  @override
  Future<List<WorkEntry>> getWorkEntries() async => List.of(entries);

  @override
  Future<void> saveWorkEntry(WorkEntry entry) async {
    if (entry.id != null) entries.removeWhere((e) => e.id == entry.id);
    entries.add(
      WorkEntry(
        id: entry.id ?? _nextId++,
        date: entry.date,
        minutes: entry.minutes,
        status: entry.status,
        note: entry.note,
      ),
    );
  }

  @override
  Future<void> deleteWorkEntry(int id) async =>
      entries.removeWhere((e) => e.id == id);
}

Future<ProviderContainer> _container(_WorkRepository repository) async {
  SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer(
    overrides: [taskRepositoryProvider.overrideWithValue(repository)],
  );
  await container.read(developerModeProvider.future);
  await container
      .read(developerModeProvider.notifier)
      .setPasscode('test-passcode');
  return container;
}

void main() {
  test('周月统计只计实际工时，旧计划不会占用额度', () {
    final entries = [
      WorkEntry(
        date: DateTime(2026, 8, 30),
        minutes: 120,
        status: WorkStatus.completed,
      ),
      WorkEntry(
        date: DateTime(2026, 8, 31),
        minutes: 180,
        status: WorkStatus.completed,
      ),
      WorkEntry(
        date: DateTime(2026, 9, 1),
        minutes: 90,
        status: WorkStatus.completed,
      ),
      WorkEntry(
        date: DateTime(2026, 9, 6),
        minutes: 240,
        status: WorkStatus.planned,
      ),
      WorkEntry(
        date: DateTime(2026, 9, 7),
        minutes: 60,
        status: WorkStatus.planned,
      ),
      WorkEntry(
        date: DateTime(2026, 10, 1),
        minutes: 120,
        status: WorkStatus.completed,
      ),
    ];
    final weekStart = workWeekStart(DateTime(2026, 9, 6));
    expect(weekStart, DateTime(2026, 8, 31));
    final week = WorkHoursSummary(entries, weekStart, DateTime(2026, 9, 7));
    expect(week.completedMinutes, 270);
    final month = WorkHoursSummary(
      entries,
      DateTime(2026, 9),
      DateTime(2026, 10),
    );
    expect(month.completedMinutes, 90);
    expect(month.remainingMinutes, 2310);
    expect(workWeekStart(DateTime(2027, 1, 1)), DateTime(2026, 12, 28));
  });

  test('实际工时按分钟准确累计，超额保留负余量', () {
    final entries = [
      for (var i = 0; i < 3; i++)
        WorkEntry(
          date: DateTime(2026, 1, 1),
          minutes: 810,
          status: WorkStatus.completed,
        ),
    ];
    final month = WorkHoursSummary(
      entries,
      DateTime(2026, 1),
      DateTime(2026, 2),
    );
    expect(month.completedMinutes, 2430);
    expect(month.remainingMinutes, -30);
    expect(formatWorkMinutes(month.completedMinutes), '40 小时 30 分钟');
    expect(formatWorkMinutes(45), '45 分钟');
  });

  test('工时记录可往返备份格式，无效日期、状态和时长会被拒绝', () {
    final entry = WorkEntry(
      id: 7,
      date: DateTime(2026, 10, 23, 17),
      minutes: 185,
      status: WorkStatus.completed,
      note: '图书馆',
    );
    final saved = WorkEntry.fromMap(entry.toMap());
    expect(saved.id, 7);
    expect(saved.date, DateTime(2026, 10, 23));
    expect(saved.minutes, 185);
    expect(saved.note, '图书馆');
    final legacy = WorkEntry.fromMap({...entry.toMap(), 'status': 'planned'});
    expect(legacy.toMap()['status'], 'planned');
    expect(
      WorkHoursSummary(
        [legacy],
        DateTime(2026, 10),
        DateTime(2026, 11),
      ).completedMinutes,
      0,
    );
    expect(
      () => WorkEntry.fromMap({...entry.toMap(), 'date': '2026-02-30'}),
      throwsFormatException,
    );
    expect(
      () => WorkEntry.fromMap({...entry.toMap(), 'status': 'unknown'}),
      throwsFormatException,
    );
    expect(
      () => WorkEntry.fromMap({...entry.toMap(), 'minutes': 0}),
      throwsFormatException,
    );
    expect(
      () => WorkEntry.fromMap({...entry.toMap(), 'minutes': 1441}),
      throwsFormatException,
    );
  });

  test('旧计划不能作为新增工时写入', () async {
    final repository = TaskRepository(AppDatabase.instance);
    await expectLater(
      repository.saveWorkEntry(
        WorkEntry(
          date: DateTime.now(),
          minutes: 120,
          status: WorkStatus.planned,
        ),
      ),
      throwsFormatException,
    );
  });

  testWidgets('实际工时可调整且不重复计数，关闭开发者模式阻止修改', (tester) async {
    final repository = _WorkRepository([
      WorkEntry(
        id: 1,
        date: DateTime.now(),
        minutes: 240,
        status: WorkStatus.completed,
      ),
    ]);
    final container = await _container(repository);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: WorkEntryDialog(entry: repository.entries.single),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SegmentedButton<WorkStatus>), findsNothing);
    expect(find.text('计划'), findsNothing);
    await tester.tap(find.text('3 小时'));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(repository.entries.length, 1);
    expect(repository.entries.single.id, 1);
    expect(repository.entries.single.minutes, 180);
    expect(repository.entries.single.status, WorkStatus.completed);
    await container.read(developerModeProvider.notifier).disable();
    await expectLater(
      container.read(workHoursProvider.notifier).remove(1),
      throwsStateError,
    );
    expect(repository.entries.length, 1);
  });

  testWidgets('超额时可返回调整，恰好 40 小时可以保存', (tester) async {
    final repository = _WorkRepository([
      WorkEntry(
        id: 1,
        date: DateTime.now(),
        minutes: 1440,
        status: WorkStatus.completed,
      ),
      WorkEntry(
        id: 2,
        date: DateTime.now(),
        minutes: 840,
        status: WorkStatus.completed,
      ),
      WorkEntry(
        id: 3,
        date: DateTime.now(),
        minutes: 240,
        status: WorkStatus.planned,
      ),
    ]);
    final container = await _container(repository);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: WorkEntryDialog())),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('4 小时'));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('超出本月额度'), findsOneWidget);
    expect(repository.entries.length, 3);
    await tester.tap(find.text('返回调整'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 小时'));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(repository.entries.length, 4);
    expect(repository.entries.last.status, WorkStatus.completed);
    final now = DateTime.now();
    final summary = WorkHoursSummary(
      repository.entries,
      DateTime(now.year, now.month),
      DateTime(now.year, now.month + 1),
    );
    expect(summary.remainingMinutes, 0);
  });

  testWidgets('未来日期不能登记为已完成', (tester) async {
    final repository = _WorkRepository([]);
    final container = await _container(repository);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: WorkEntryDialog(
              entry: WorkEntry(
                date: DateTime.now().add(const Duration(days: 2)),
                minutes: 120,
                status: WorkStatus.completed,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('实际工时不能登记在未来日期'), findsOneWidget);
    expect(repository.entries, isEmpty);
  });

  testWidgets('页面登记后定位记录月份，删除需确认并刷新汇总', (tester) async {
    final repository = _WorkRepository([]);
    final container = await _container(repository);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: WorkHoursScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('下个月'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('登记工时'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3 小时'));
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(repository.entries.single.minutes, 180);
    final now = DateTime.now();
    expect(find.text('${now.year}年${now.month}月'), findsOneWidget);
    final record = find.text('${now.month}月${now.day}日 · 3 小时');
    await tester.scrollUntilVisible(
      record,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip('工时操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(repository.entries.length, 1);
    await tester.tap(find.byTooltip('工时操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();
    expect(repository.entries, isEmpty);
    expect(container.read(workHoursProvider).requireValue, isEmpty);
  });

  testWidgets('旧计划记录不展示且不会变成实际工时', (tester) async {
    final repository = _WorkRepository([
      WorkEntry(id: 1, date: DateTime.now(), minutes: 180),
      WorkEntry(
        id: 2,
        date: DateTime.now(),
        minutes: 240,
        status: WorkStatus.planned,
        note: '旧计划',
      ),
    ]);
    final container = await _container(repository);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: WorkHoursScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('已计划'), findsNothing);
    expect(find.text('还能安排'), findsNothing);
    final now = DateTime.now();
    await tester.scrollUntilVisible(
      find.text('${now.month}月记录 · 1 次'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('旧计划'), findsNothing);
    expect(repository.entries.length, 2);
    expect(repository.entries.last.status, WorkStatus.planned);
  });

  testWidgets('小屏工时页面可浏览并切换月份，关闭模式后隐藏页面', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _WorkRepository([]);
    final container = await _container(repository);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: WorkHoursScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('每月额度 40 小时'), findsOneWidget);
    final now = DateTime.now();
    await tester.tap(find.byTooltip('下个月'));
    await tester.pumpAndSettle();
    final next = DateTime(now.year, now.month + 1);
    expect(find.text('${next.year}年${next.month}月'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await container.read(developerModeProvider.notifier).disable();
    await tester.pumpAndSettle();
    expect(find.text('请先开启开发者模式'), findsOneWidget);
    expect(find.byTooltip('登记工时'), findsNothing);
  });
}
