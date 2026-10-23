import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_reminder/providers/developer_mode_provider.dart';
import 'package:todo_reminder/widgets/developer_mode_section.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('设置口令、关闭和重新开启后可恢复状态，错误口令不能解锁', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      (await container.read(developerModeProvider.future)).configured,
      false,
    );
    final notifier = container.read(developerModeProvider.notifier);
    await notifier.setPasscode('test-passcode');
    expect(container.read(developerModeProvider).requireValue.enabled, true);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('developer_mode'), isNot(contains('test-passcode')));
    final restarted = ProviderContainer();
    addTearDown(restarted.dispose);
    expect((await restarted.read(developerModeProvider.future)).enabled, true);

    await restarted.read(developerModeProvider.notifier).disable();
    final closed = ProviderContainer();
    addTearDown(closed.dispose);
    final mode = await closed.read(developerModeProvider.future);
    expect(mode.configured, true);
    expect(mode.enabled, false);
    final closedNotifier = closed.read(developerModeProvider.notifier);
    expect(await closedNotifier.unlock('wrong-passcode'), false);
    expect(closed.read(developerModeProvider).requireValue.enabled, false);
    expect(await closedNotifier.unlock('test-passcode'), true);
  });

  test('无效口令不保存，已配置口令不能直接覆盖', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(developerModeProvider.future);
    final notifier = container.read(developerModeProvider.notifier);
    await expectLater(notifier.setPasscode('123'), throwsFormatException);
    await expectLater(notifier.setPasscode('      '), throwsFormatException);
    expect(
      container.read(developerModeProvider).requireValue.configured,
      false,
    );
    await notifier.setPasscode('test-passcode');
    await expectLater(notifier.setPasscode('replacement'), throwsStateError);
  });

  test('损坏或缺少口令的配置不会开启开发者模式', () async {
    SharedPreferences.setMockInitialValues({
      'developer_mode': '{"enabled":true}',
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final mode = await container.read(developerModeProvider.future);
    expect(mode.enabled, false);
    expect(mode.configured, false);
  });

  testWidgets('设置页支持取消、确认口令、关闭及重新验证', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: DeveloperModeSection())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('勤工俭学工时'), findsNothing);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      false,
    );

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'test-passcode');
    await tester.enterText(find.byType(TextField).last, 'other-passcode');
    await tester.tap(find.text('开启'));
    await tester.pumpAndSettle();
    expect(find.text('两次输入的口令不一致'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'test-passcode');
    await tester.tap(find.text('开启'));
    await tester.pumpAndSettle();
    expect(find.text('已开启'), findsOneWidget);
    expect(find.text('勤工俭学工时'), findsOneWidget);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(find.text('已关闭'), findsOneWidget);
    expect(find.text('勤工俭学工时'), findsNothing);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(find.text('解锁开发者模式'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'wrong-passcode');
    await tester.tap(find.text('开启'));
    await tester.pumpAndSettle();
    expect(find.text('口令错误，请重试'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'test-passcode');
    await tester.tap(find.text('开启'));
    await tester.pumpAndSettle();
    expect(find.text('已开启'), findsOneWidget);
  });
}
