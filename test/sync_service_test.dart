import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:todo_reminder/data/database.dart';
import 'package:todo_reminder/data/task_repository.dart';
import 'package:todo_reminder/services/sync_service.dart';

class _LoopbackHttpOverrides extends HttpOverrides {}

class _LocalRepository extends TaskRepository {
  _LocalRepository() : super(AppDatabase.instance);

  bool imported = false;

  @override
  Future<Map<String, Object?>> exportData() async => {
    'tasks': [
      {'title': '断网时修改的待办'},
    ],
  };

  @override
  Future<void> importData(Map<String, dynamic> data) async => imported = true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('首次请求失败后仍会补传本机待办', () async {
    SharedPreferences.setMockInitialValues({});
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final client = HttpOverrides.runWithHttpOverrides(
      () => SupabaseClient('http://127.0.0.1:${server.port}', 'test-key'),
      _LoopbackHttpOverrides(),
    );
    addTearDown(() => server.close(force: true));
    addTearDown(client.dispose);

    await client.auth.recoverSession(
      jsonEncode({
        'access_token': 'test-access-token',
        'token_type': 'bearer',
        'user': {
          'id': 'test-user',
          'aud': 'authenticated',
          'app_metadata': <String, Object>{},
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );

    var firstRead = true;
    Object? uploaded;
    server.listen((request) async {
      final response = request.response;
      response.headers.contentType = ContentType.json;
      if (request.method == 'POST') {
        uploaded = jsonDecode(await utf8.decoder.bind(request).join());
        response.statusCode = HttpStatus.created;
      } else if (firstRead) {
        firstRead = false;
        response.statusCode = HttpStatus.badRequest;
        response.write('{"message":"模拟读取失败"}');
      } else {
        response.write(
          '[{"payload":{"tasks":[]},"updated_at":"2026-01-01T00:00:00Z"}]',
        );
      }
      await response.close();
    });

    final repo = _LocalRepository();
    final service = SyncService(repo, client);
    await expectLater(
      service.sync(localChanged: true),
      throwsA(isA<PostgrestException>()),
    );
    expect(await SyncService(repo, client).sync(), SyncOutcome.uploaded);
    expect(uploaded, containsPair('payload', await repo.exportData()));
    expect(repo.imported, isFalse);
  });
}
