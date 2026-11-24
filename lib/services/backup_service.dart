import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../data/task_repository.dart';

/// 以 JSON 文件导入导出本地数据，便于换机迁移和人工备份。
class BackupService {
  BackupService(this._repository);

  final TaskRepository _repository;

  Future<String> exportToFile() async {
    final now = DateTime.now();
    final date =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    return _writeBackup(await _repository.exportData(), 'todo-reminder-$date');
  }

  Future<String> preserveBeforeSync(Map<String, Object?> data) {
    return _writeBackup(
      data,
      'todo-reminder-before-sync-${DateTime.now().microsecondsSinceEpoch}',
    );
  }

  Future<String> _writeBackup(Map<String, Object?> data, String name) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$name.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
      flush: true,
    );
    return file.path;
  }

  Future<bool> importFromPicker() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (picked.isEmpty) return false;
    final path = picked.single.path;
    if (path == null) return false;
    final text = await File(path).readAsString();
    final data = jsonDecode(text);
    if (data is! Map<String, dynamic>) throw const FormatException('不是有效的备份文件');
    await _repository.importData(data);
    return true;
  }
}
