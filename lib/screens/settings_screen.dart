import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';

import '../providers/task_providers.dart';
import '../services/cache_service.dart';
import '../theme.dart';
import '../utils/motion.dart';
import '../widgets/update_dialog.dart';
import 'statistics_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _checkingUpdate = false;
  late Future<CacheInfo> _cacheInfo;

  @override
  void initState() {
    super.initState();
    _cacheInfo = ref.read(cacheServiceProvider).inspect();
  }

  Future<void> _clearCache(CacheInfo info) async {
    if (info.fileCount == 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      animationStyle: AppMotion.sheetStyle,
      builder: (ctx) => AlertDialog(
        title: const Text('清除缓存'),
        content: Text(
          '将删除 ${formatCacheSize(info.bytes)} 的已下载更新安装包。待办、统计、备份和设置会保留。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final cleared = await ref.read(cacheServiceProvider).clear();
    if (!mounted) return;
    setState(() => _cacheInfo = ref.read(cacheServiceProvider).inspect());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已清除 ${formatCacheSize(cleared.bytes)} 缓存')),
    );
  }

  Future<void> _checkForUpdate() async {
    setState(() => _checkingUpdate = true);
    final outcome = await checkForUpdatesAndPrompt(context, ref);
    if (!mounted) return;
    setState(() => _checkingUpdate = false);
    if (outcome == UpdateCheckOutcome.noUpdate) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已为最新版本')));
    } else if (outcome == UpdateCheckOutcome.checking) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('正在检查更新，请稍候')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(sortModeProvider);
    final doneLast = ref.watch(doneLastProvider);
    final themeMode = ref.watch(themeModeProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.ink,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('列表排序', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '决定待办在列表里的排列顺序，置顶项始终排最前。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<SortMode>(
              expandedInsets: EdgeInsets.zero,
              segments: [
                for (final m in SortMode.values)
                  ButtonSegment(value: m, label: Text(m.label)),
              ],
              selected: {mode},
              onSelectionChanged: (s) async {
                ref.read(sortModeProvider.notifier).state = s.first;
                await ref
                    .read(taskRepositoryProvider)
                    .setSetting('sort_mode', s.first.name);
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            mode == SortMode.time ? '只看提醒时间，重要项仅用颜色区分' : '先按重要性，再按时间',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('已完成排后面'),
            subtitle: const Text('已完成的待办自动排在未完成下面'),
            value: doneLast,
            onChanged: (v) async {
              ref.read(doneLastProvider.notifier).state = v;
              await ref
                  .read(taskRepositoryProvider)
                  .setSetting('done_last', v.toString());
            },
          ),
          const SizedBox(height: 16),
          Text('外观', style: Theme.of(context).textTheme.titleMedium),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('跟随系统')),
              ButtonSegment(value: ThemeMode.light, label: Text('浅色')),
              ButtonSegment(value: ThemeMode.dark, label: Text('深色')),
            ],
            selected: {themeMode},
            onSelectionChanged: (value) async {
              ref.read(themeModeProvider.notifier).state = value.first;
              await ref
                  .read(taskRepositoryProvider)
                  .setSetting('theme_mode', value.first.name);
            },
          ),
          const SizedBox(height: 24),
          Text('统计', style: Theme.of(context).textTheme.titleMedium),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.insights_outlined),
            title: const Text('查看统计'),
            subtitle: const Text('查看重复待办和常用模板的完成情况'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const StatisticsScreen()),
            ),
          ),
          const SizedBox(height: 24),
          Text('应用更新', style: Theme.of(context).textTheme.titleMedium),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: _checkingUpdate
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.system_update_outlined),
            title: const Text('检查更新'),
            subtitle: const Text('检查是否有可下载安装的新版本'),
            trailing: const Icon(Icons.chevron_right),
            enabled: !_checkingUpdate,
            onTap: _checkingUpdate ? null : _checkForUpdate,
          ),
          const SizedBox(height: 24),
          Text('存储空间', style: Theme.of(context).textTheme.titleMedium),
          FutureBuilder<CacheInfo>(
            future: _cacheInfo,
            builder: (context, snapshot) {
              final info = snapshot.data;
              final loading = snapshot.connectionState != ConnectionState.done;
              final subtitle = loading
                  ? '正在计算可清除的数据量'
                  : info == null || info.fileCount == 0
                  ? '没有可清除的更新缓存'
                  : '可清除 ${formatCacheSize(info.bytes)} · ${info.fileCount} 个已下载更新包';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.delete_sweep_outlined),
                title: const Text('清除缓存'),
                subtitle: Text(subtitle),
                trailing: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
                enabled: info != null && info.fileCount > 0,
              onTap: info != null && info.fileCount > 0
                  ? () => _clearCache(info)
                  : null,
              );
            },
          ),
          const SizedBox(height: 24),
          Text('数据备份', style: Theme.of(context).textTheme.titleMedium),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.upload_file_outlined),
            title: const Text('导出备份'),
            subtitle: const Text('生成 JSON 文件，可复制或分享保存'),
            onTap: () async {
              final path = await ref.read(backupServiceProvider).exportToFile();
              if (!context.mounted) return;
              await OpenFilex.open(path);
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.download_outlined),
            title: const Text('导入备份'),
            subtitle: const Text('导入会覆盖当前所有待办、模板和设置'),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                animationStyle: AppMotion.sheetStyle,
                builder: (ctx) => AlertDialog(
                  title: const Text('导入备份'),
                  content: const Text('确认用备份内容覆盖当前数据吗？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('覆盖导入'),
                    ),
                  ],
                ),
              );
              if (ok != true) return;
              final imported = await ref
                  .read(backupServiceProvider)
                  .importFromPicker();
              if (imported) await ref.read(tasksProvider.notifier).rollover();
            },
          ),
          const SizedBox(height: 24),
          Text('关于跨天', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '每天午夜 0 点自动切换到新的一天，重复任务的打勾会复位，累计完成天数会保留。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
