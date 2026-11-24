import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_reminder/data/database.dart';
import 'package:todo_reminder/data/task_repository.dart';
import 'package:todo_reminder/models/task.dart';
import 'package:todo_reminder/providers/task_providers.dart';
import 'package:todo_reminder/screens/home_screen.dart';
import 'package:todo_reminder/utils/task_text_import.dart';

void main() {
  final now = DateTime(2026, 11, 24, 9);

  test('从自然语言提取提交事项、文件要求和截止时间', () {
    const text = '通知：请大家在明天下午 ５ 点半前提交实习报告，文件格式为 PDF。';
    final draft = parseTaskText(text, now: now);
    expect(draft.title, '提交实习报告');
    expect(draft.deadline, DateTime(2026, 11, 25, 17, 30));
    expect(draft.timeWasInferred, isFalse);
    expect(draft.note, contains('要求：文件格式为 PDF'));
    expect(draft.note, contains('需提交：实习报告'));
    expect(draft.note, endsWith(text));
  });

  test('优先使用带有明确标记的截止日期和通知中的字段', () {
    const text =
        '任务：课程项目验收\n11月25日开会。\n'
        '要求：统一用 PDF 格式\n提交材料：报告和附件\n截止时间：2026-11-30 18:00';
    final draft = parseTaskText(text, now: now);
    expect(draft.title, '课程项目验收');
    expect(draft.deadline, DateTime(2026, 11, 30, 18));
    expect(draft.note, contains('要求：统一用 PDF 格式'));
    expect(draft.note, contains('需提交：报告和附件'));
  });

  test('支持相对星期、括号内的星期和仅有日期的截止要求', () {
    expect(
      parseTaskText('下周五中午12点前提交报名表', now: now).deadline,
      DateTime(2026, 12, 4, 12),
    );
    expect(
      parseTaskText('请在11月27日（周五）17:00前提交', now: now).deadline,
      DateTime(2026, 11, 27, 17),
    );
    final draft = parseTaskText('截止日期：12月1日', now: now);
    expect(draft.deadline, DateTime(2026, 12, 1, 23, 59));
    expect(draft.timeWasInferred, isTrue);
  });

  test('没有日期、日期冲突或无效日期时留空', () {
    for (final text in [
      '提交实验报告',
      '请在11月26日参加会议，11月27日交报告',
      '截止日期：11月27日或11月28日',
      '11月25日开会，截止日期：11月31日',
      '截止时间：明天下午5点83分',
    ]) {
      expect(parseTaskText(text, now: now).deadline, isNull, reason: text);
    }
  });

  testWidgets('在添加菜单粘贴通知，核对并修改待办后保存', (tester) async {
    Task? saved;
    final notifier = _ImportTasksNotifier((task) => saved = task);
    await tester.binding.setSurfaceSize(const Size(900, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(_ImportTaskRepository()),
          tasksProvider.overrideWith(() => notifier),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('添加待办'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('粘贴文字导入'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '生成待办'))
          .onPressed,
      isNull,
    );

    final today = DateTime.now();
    final deadline = DateTime(today.year, today.month, today.day + 1);
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '请在明天下午5点半前提交实习报告，文件格式为 PDF。',
    );
    await tester.pump();
    await tester.tap(find.text('生成待办'));
    await tester.pumpAndSettle();

    expect(find.text('新建待办'), findsOneWidget);
    expect(find.text('提交实习报告'), findsOneWidget);
    expect(find.textContaining('需提交：实习报告'), findsOneWidget);
    expect(find.text('${deadline.month}月${deadline.day}日'), findsOneWidget);
    final timeTile = find.widgetWithText(ListTile, '提醒时间');
    final time = tester.widget<ListTile>(timeTile).trailing as Text;
    expect(time.data, contains(':30'));
    expect(saved, isNull);

    await tester.enterText(find.byType(TextField).first, '提交已校对的实习报告');
    tester.testTextInput.hide();
    await tester.tap(timeTile);
    await tester.pumpAndSettle();
    final picker = find.byType(TimePickerDialog);
    expect(
      tester.widget<TimePickerDialog>(picker).initialTime,
      const TimeOfDay(hour: 17, minute: 30),
    );
    Navigator.of(tester.element(picker))
        .pop(const TimeOfDay(hour: 16, minute: 45));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(saved?.title, '提交已校对的实习报告');
    expect(saved?.date, dateKey(deadline));
    expect(saved?.remindHour, 16);
    expect(saved?.remindMinute, 45);
    expect(saved?.note, contains('文件格式为 PDF'));
    expect(find.byTooltip('添加待办'), findsOneWidget);
  });
}

class _ImportTaskRepository extends TaskRepository {
  _ImportTaskRepository() : super(AppDatabase.instance);

  @override
  Future<List<QuickTask>> getQuickTasks() async => [];
}

class _ImportTasksNotifier extends TasksNotifier {
  _ImportTasksNotifier(this.onSave);

  final void Function(Task) onSave;

  @override
  Future<List<Task>> build() async => [];

  @override
  Future<void> add(Task task) async => onSave(task);
}
