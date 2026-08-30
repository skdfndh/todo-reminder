import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task.dart';
import '../providers/task_providers.dart';
import '../utils/statistics.dart';

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  StatisticsRange _range = StatisticsRange.all;

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider);
    final quickTasks = ref.watch(quickTasksProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('统计')),
      body: tasks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('加载失败：$error')),
        data: (items) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<StatisticsRange>(
              segments: [
                for (final item in StatisticsRange.values)
                  ButtonSegment(value: item, label: Text(item.label)),
              ],
              selected: {_range},
              onSelectionChanged: (value) =>
                  setState(() => _range = value.first),
            ),
            const SizedBox(height: 20),
            Text('重复待办', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final type in const [
              RepeatType.daily,
              RepeatType.weekly,
              RepeatType.monthly,
            ])
              _StatisticsTile(
                title: type.label,
                icon: switch (type) {
                  RepeatType.daily => Icons.today_outlined,
                  RepeatType.weekly => Icons.date_range_outlined,
                  RepeatType.monthly => Icons.calendar_month_outlined,
                  RepeatType.once => Icons.event_outlined,
                },
                statistics: taskStatistics(
                  items.where((task) => task.repeatType == type),
                  _range,
                ),
              ),
            const SizedBox(height: 20),
            Text('常用一次性待办', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            quickTasks.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Text('模板加载失败：$error'),
              data: (templates) => templates.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('还没有常用一次性待办'),
                    )
                  : Column(
                      children: [
                        for (final template in templates)
                          _StatisticsTile(
                            title: template.title,
                            icon: Icons.bookmark_outline,
                            statistics: taskStatistics(
                              items.where(
                                (task) =>
                                    task.repeatType == RepeatType.once &&
                                    task.sourceQuickTaskId == template.id,
                              ),
                              _range,
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 20),
            Text(
              '应完成次数按当前重复规则和时间窗口计算；规则修改前的历史安排不会回溯。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatisticsTile extends StatelessWidget {
  const _StatisticsTile({
    required this.title,
    required this.icon,
    required this.statistics,
  });

  final String title;
  final IconData icon;
  final CompletionStatistics statistics;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(
        '设立 ${statistics.setupCount} 次 · 应完成 ${statistics.dueCount} 次\n'
        '完成 ${statistics.completedCount} 次 · 漏做 ${statistics.missedCount} 次',
      ),
      trailing: Text('${statistics.completionRate}%'),
    );
  }
}
