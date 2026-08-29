import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:todo_reminder/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('可打开主页并进入新建待办页', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    expect(find.text('待办提醒'), findsOneWidget);
    await tester.tap(find.byTooltip('添加待办'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建待办'));
    await tester.pumpAndSettle();
    expect(find.text('新建待办'), findsOneWidget);
  });
}
