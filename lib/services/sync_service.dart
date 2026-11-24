import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/task_repository.dart';
import 'backup_service.dart';

enum SyncOutcome { uploaded, downloaded, unchanged }

class SyncService {
  SyncService(this._repository, this._client);

  final TaskRepository _repository;
  final SupabaseClient _client;
  Future<void> _previousSync = Future.value();

  User? get currentUser => _client.auth.currentUser;

  Future<SyncOutcome> sync({bool localChanged = false}) {
    final user = currentUser;
    if (user == null) return Future.value(SyncOutcome.unchanged);
    // 同一设备上的启动、保存和手动同步共用顺序，避免同时改写快照。
    final next = _previousSync.then((_) => _sync(user.id, localChanged));
    _previousSync = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  Future<SyncOutcome> _sync(String userId, bool localChanged) async {
    if (currentUser?.id != userId) return SyncOutcome.unchanged;

    final prefs = await SharedPreferences.getInstance();
    final key = 'last_cloud_sync_$userId';
    final dirtyKey = 'cloud_sync_dirty_$userId';
    // 网络请求失败也要保留待上传标记，避免下次同步覆盖本机修改。
    if (localChanged && !await prefs.setBool(dirtyKey, true)) {
      throw StateError('无法保存待同步状态');
    }
    localChanged = localChanged || (prefs.getBool(dirtyKey) ?? false);
    final lastSync = DateTime.tryParse(prefs.getString(key) ?? '');

    final rows = await _client
        .from('user_snapshots')
        .select('payload, updated_at')
        .eq('user_id', userId)
        .limit(1);
    if (currentUser?.id != userId) return SyncOutcome.unchanged;
    final remote = rows.isEmpty ? null : rows.first;
    Map<String, Object?>? local;

    if (remote != null && !localChanged) {
      final remoteTime = DateTime.parse(remote['updated_at'] as String).toUtc();
      if (lastSync != null && !remoteTime.isAfter(lastSync.toUtc())) {
        return SyncOutcome.unchanged;
      }
      final payload = Map<String, dynamic>.from(remote['payload'] as Map);
      local = await _repository.exportData();
      // 空云端快照可能来自刚登录的另一台空设备，首次连接时优先保留本机已有待办。
      if (lastSync != null || !_hasRecords(local) || _hasRecords(payload)) {
        if (_hasRecords(local)) {
          await BackupService(_repository).preserveBeforeSync(local);
        }
        if (currentUser?.id != userId) return SyncOutcome.unchanged;
        await _repository.importData(payload);
        await prefs.setString(key, remoteTime.toIso8601String());
        return SyncOutcome.downloaded;
      }
    }

    local ??= await _repository.exportData();
    if (currentUser?.id != userId) return SyncOutcome.unchanged;
    final now = DateTime.now().toUtc();
    await _client.from('user_snapshots').upsert({
      'user_id': userId,
      'payload': local,
      'updated_at': now.toIso8601String(),
    });
    await prefs.setString(key, now.toIso8601String());
    await prefs.setBool(dirtyKey, false);
    return SyncOutcome.uploaded;
  }

  bool _hasRecords(Map<String, Object?> data) => const [
    'tasks',
    'completions',
    'quickTasks',
    'workEntries',
  ].any((key) => (data[key] as List?)?.isNotEmpty ?? false);

  Future<void> signOut() => _client.auth.signOut();
}
