import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/work_entry.dart';
import 'developer_mode_provider.dart';
import 'task_providers.dart';

final workHoursProvider =
    AsyncNotifierProvider<WorkHoursNotifier, List<WorkEntry>>(
      WorkHoursNotifier.new,
    );

class WorkHoursNotifier extends AsyncNotifier<List<WorkEntry>> {
  @override
  Future<List<WorkEntry>> build() =>
      ref.read(taskRepositoryProvider).getWorkEntries();

  Future<void> save(WorkEntry entry) async {
    await _checkAccess();
    await ref.read(taskRepositoryProvider).saveWorkEntry(entry);
    state = AsyncData(await ref.read(taskRepositoryProvider).getWorkEntries());
  }

  Future<void> remove(int id) async {
    await _checkAccess();
    await ref.read(taskRepositoryProvider).deleteWorkEntry(id);
    state = AsyncData(await ref.read(taskRepositoryProvider).getWorkEntries());
  }

  Future<void> _checkAccess() async {
    if (!(await ref.read(developerModeProvider.future)).enabled) {
      throw StateError('请先开启开发者模式');
    }
  }
}
