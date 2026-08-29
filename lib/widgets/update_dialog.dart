import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../providers/task_providers.dart';
import '../services/update_service.dart';
import '../theme.dart';
import '../utils/motion.dart';

/// 同会话只检查一次，避免反复打扰。
bool _checking = false;

/// 启动后检查更新并弹窗引导。无新版本 / 网络异常一律静默。
Future<void> checkForUpdatesAndPrompt(
  BuildContext context,
  WidgetRef ref,
) async {
  if (_checking) return;
  _checking = true;

  final service = ref.read(updateServiceProvider);
  final result = await service.checkForUpdate();
  if (result == null || !context.mounted) return;

  final current = await service.currentVersion();
  if (!context.mounted) return;
  final update = await _confirmVersionDialog(context, result, current);
  if (update != true || !context.mounted) return;
  await _downloadAndInstall(context, service, result);
}

/// 「发现新版本」确认弹窗：新旧版本号、更新内容，并提醒先打开网络代理。
Future<bool?> _confirmVersionDialog(
  BuildContext context,
  UpdateCheckResult result,
  String? currentVersion,
) {
  return showDialog<bool>(
    context: context,
    animationStyle: AppMotion.sheetStyle,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final notes = result.releaseNotes.trim();
      return AlertDialog(
        title: Text('发现新版本 v${result.latestVersion}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('是否立即更新？'),
            const SizedBox(height: 12),
            // 新旧版本号对比。
            Text(
              '当前版本 v${currentVersion ?? '?'}  →  新版本 v${result.latestVersion}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '本次更新：',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: SingleChildScrollView(
                  child: Text(
                    notes,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            // 下载来源提示：GitHub 需要网络代理。
            Text(
              '提示：更新包托管在 GitHub，请先打开网络代理（梯子）再点击「立即更新」，以免下载失败。',
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.high),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('暂不'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('立即更新'),
          ),
        ],
      );
    },
  );
}

/// 下载 APK 到缓存目录，展示进度，完成后唤起系统安装器。
Future<void> _downloadAndInstall(
  BuildContext context,
  UpdateService service,
  UpdateCheckResult result,
) async {
  final dir = await getTemporaryDirectory();
  if (!context.mounted) return;
  final dest = '${dir.path}/todo-reminder-${result.latestVersion}.apk';

  var received = 0;
  var total = 0;
  var failed = false;
  void Function(void Function())? refresh;

  final dialogFuture = showDialog<void>(
    context: context,
    animationStyle: AppMotion.sheetStyle,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        refresh = setState;
        return AlertDialog(
          title: const Text('正在下载更新'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(
                value: total > 0
                    ? (received / total).clamp(0.0, 1.0).toDouble()
                    : null,
              ),
              const SizedBox(height: 12),
              Text(
                total > 0
                    ? '已下载 ${_mb(received)} / ${_mb(total)}'
                    : '已下载 ${_mb(received)}',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              if (failed) ...[
                const SizedBox(height: 8),
                Text(
                  '下载失败，请稍后重试',
                  style: const TextStyle(color: AppColors.high),
                ),
              ],
            ],
          ),
        );
      },
    ),
  );

  try {
    await service.download(
      result.apkUrl,
      dest,
      onProgress: (r, t) {
        received = r;
        total = t;
        refresh?.call(() {});
      },
    );
  } catch (e) {
    debugPrint('下载更新失败：$e');
    failed = true;
    refresh?.call(() {});
    // 让用户看到失败提示后再关闭。
    await Future<void>.delayed(const Duration(milliseconds: 800));
  }

  if (context.mounted) {
    Navigator.of(context, rootNavigator: true).pop();
  }
  await dialogFuture;

  if (failed || !context.mounted) return;

  final opened = await OpenFilex.open(
    dest,
    type: 'application/vnd.android.package-archive',
  );
  if (opened.type != ResultType.done) {
    debugPrint('唤起安装器失败：${opened.type} / ${opened.message}');
    if (context.mounted) _showInstallGuide(context);
  }
}

/// 安装器未能唤起时的引导提示。
void _showInstallGuide(BuildContext context) {
  showDialog<void>(
    context: context,
    animationStyle: AppMotion.sheetStyle,
    builder: (ctx) => AlertDialog(
      title: const Text('安装未完成'),
      content: const Text('请到系统设置里给本应用开启「允许安装未知应用」，再重新打开 App 完成更新。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('知道了'),
        ),
      ],
    ),
  );
}

String _mb(int bytes) => '${(bytes / 1048576).toStringAsFixed(1)} MB';
