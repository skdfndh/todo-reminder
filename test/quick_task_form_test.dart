import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_reminder/data/task_repository.dart';
import 'package:todo_reminder/models/task.dart';
import 'package:todo_reminder/screens/task_edit_screen.dart';

void main() {
  testWidgets('常用待办打开新建页时预填内容且可以修改', (tester) async {
    const quick = QuickTask(
      id: 7,
      title: '买车票',
      note: '返程',
      tags: {'出行'},
      remindHour: 18,
      remindMinute: 25,
      advanceMinutes: 15,
      priority: Priority.high,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: TaskEditScreen(
            quickTask: quick,
            initialDate: DateTime(2026, 10, 20),
          ),
        ),
      ),
    );

    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(find.text('新建待办'), findsOneWidget);
    expect(fields[0].controller!.text, '买车票');
    expect(fields[1].controller!.text, '返程');
    expect(fields[2].controller!.text, '出行');

    final formScroll = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('提醒时间'),
      160,
      scrollable: formScroll.first,
    );
    final timeTile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, '提醒时间'),
    );
    expect((timeTile.trailing! as Text).data, contains(':25'));

    await tester.scrollUntilVisible(
      find.text('提前提醒'),
      160,
      scrollable: formScroll.first,
    );
    final advanceTile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, '提前提醒'),
    );
    expect((advanceTile.trailing! as DropdownButton<int>).value, 15);

    await tester.enterText(find.byType(TextField).first, '买明天的车票');
    expect(fields[0].controller!.text, '买明天的车票');
  });
}
