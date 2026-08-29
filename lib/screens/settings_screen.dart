import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';

import '../providers/task_providers.dart';
import '../theme.dart';
import '../utils/motion.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
