import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../utils/abi.dart';
import '../utils/version.dart';

/// 一次成功的更新检查结果（远端确有可下载的新版本）。
class UpdateCheckResult {
  const UpdateCheckResult({
    required this.latestVersion,
    required this.assetName,
    required this.apkUrl,
    required this.releaseNotes,
  });

  /// 最新版本号，已去掉 v 前缀，如 '1.1.0'。
  final String latestVersion;

  /// 匹配本机 ABI 的 APK 资产名。
  final String assetName;

  /// 该 APK 的下载地址（GitHub release 资产 URL）。
  final String apkUrl;

  /// release 的更新说明（body），弹窗里展示。
  final String releaseNotes;
}

/// 从发布说明中提取少量摘要，供更新确认弹窗快速浏览。
List<String> releaseSummaryLines(String releaseNotes, {int maxLines = 2}) {
  return releaseNotes
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty && !line.startsWith('#'))
      .map(
        (line) =>
            line.replaceFirst(RegExp(r'^(#{1,6}\s+|[-*+]\s+|\d+[.)]\s+)'), ''),
      )
      .take(maxLines)
      .toList();
}

/// 检查 GitHub 最新 release 并下载对应 APK。
///
/// 所有异常都在服务内部捕获：无新版本、无对应 ABI 产物或网络失败一律返回
/// null / 抛错，由调用方静默处理，不打扰用户。
class UpdateService {
  UpdateService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              headers: {
                // GitHub API 对缺失 User-Agent 的请求直接 403。
                'User-Agent': 'todo-reminder-app',
                'Accept': 'application/vnd.github+json',
              },
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
            ),
          );

  final Dio _dio;

  /// 版本接口地址。用 `--dart-define=UPDATE_API_BASE=...` 可覆盖，便于本地测试。
  static const _apiBase = String.fromEnvironment(
    'UPDATE_API_BASE',
    defaultValue:
        'https://api.github.com/repos/skdfndh/todo-reminder/releases/latest',
  );

  /// 本地版本号（如 '1.0.0'）；非 Android 返回 null。
  Future<String?> currentVersion() async {
    if (!_isAndroid) return null;
    try {
      return (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      return null;
    }
  }

  /// 端到端检查更新：有可下载的新版本返回结果，否则返回 null。
  Future<UpdateCheckResult?> checkForUpdate() async {
    if (!_isAndroid) return null;
    try {
      final local = await currentVersion();
      final localVer = local == null ? null : AppVersion.tryParse(local);
      if (localVer == null) return null;

      final data = (await _dio.get<Map<String, dynamic>>(_apiBase)).data;
      if (data == null) return null;

      final remote = AppVersion.tryParse(data['tag_name'] as String? ?? '');
      if (remote == null || !remote.isNewerThan(localVer)) return null;

      final abis = await _deviceAbis();
      if (abis.isEmpty) return null;

      final assets = data['assets'] as List<dynamic>? ?? const [];
      // 资产名 → 下载地址映射（release 资产是 JSON 对象数组）。
      final assetUrl = <String, String>{
        for (final a in assets)
          if (a is Map &&
              a['name'] is String &&
              a['browser_download_url'] is String)
            a['name'] as String: a['browser_download_url'] as String,
      };
      final assetName = matchApkAsset(assetUrl.keys.toList(), abis);
      final apkUrl = assetName == null ? null : assetUrl[assetName];
      if (assetName == null || apkUrl == null) return null;

      return UpdateCheckResult(
        latestVersion: remote.toString(),
        assetName: assetName,
        apkUrl: apkUrl,
        releaseNotes: (data['body'] as String?) ?? '',
      );
    } catch (e) {
      debugPrint('检查更新失败：$e');
      return null;
    }
  }

  /// 下载 APK 到 [destPath]，[onProgress] 回调 (received, total)。
  Future<void> download(
    String url,
    String destPath, {
    required void Function(int received, int total) onProgress,
  }) async {
    await _dio.download(url, destPath, onReceiveProgress: onProgress);
  }

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// 设备支持的 ABI 列表；非 Android 返回空。
  Future<List<String>> _deviceAbis() async {
    try {
      return (await DeviceInfoPlugin().androidInfo).supportedAbis;
    } catch (_) {
      return const [];
    }
  }
}
