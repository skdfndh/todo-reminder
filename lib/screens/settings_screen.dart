import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/task_providers.dart';
import '../theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(sortModeProvider);
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
              onSelectionChanged: (s) =>
                  ref.read(sortModeProvider.notifier).state = s.first,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            mode == SortMode.time ? '只看提醒时间，重要项仅用颜色区分' : '先按重要性，再按时间',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
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
