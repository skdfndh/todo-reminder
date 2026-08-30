import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 可安全清除的更新安装包缓存概况。
class CacheInfo {
  const CacheInfo({required this.fileCount, required this.bytes});

  final int fileCount;
  final int bytes;
}

/// 仅管理可重新下载的更新安装包，不触及用户数据和统计记录。
class CacheService {
  Future<CacheInfo> inspect() async {
    final files = await _cacheFiles();
    var bytes = 0;
    for (final file in files) {
      bytes += await file.length();
    }
    return CacheInfo(fileCount: files.length, bytes: bytes);
  }

  Future<CacheInfo> clear() async {
    final files = await _cacheFiles();
    var bytes = 0;
    for (final file in files) {
      bytes += await file.length();
      await file.delete();
    }
    return CacheInfo(fileCount: files.length, bytes: bytes);
  }

  Future<List<File>> _cacheFiles() async {
    final dir = await getTemporaryDirectory();
    final files = <File>[];
    await for (final item in dir.list(followLinks: false)) {
      if (item is File && isDisposableUpdatePackagePath(item.path)) {
        files.add(item);
      }
    }
    return files;
  }
}

bool isDisposableUpdatePackagePath(String path) {
  final name = path.replaceAll('\\', '/').split('/').last;
  return RegExp(r'^todo-reminder-.+\.apk$').hasMatch(name);
}

String formatCacheSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / 1048576).toStringAsFixed(1)} MB';
}
