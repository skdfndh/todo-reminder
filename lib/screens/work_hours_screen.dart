import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/work_entry.dart';
import '../providers/developer_mode_provider.dart';
import '../providers/work_hours_provider.dart';
import '../widgets/work_entry_dialog.dart';

class WorkHoursScreen extends ConsumerStatefulWidget {
  const WorkHoursScreen({super.key});

  @override
  ConsumerState<WorkHoursScreen> createState() => _WorkHoursScreenState();
}

class _WorkHoursScreenState extends ConsumerState<WorkHoursScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _week = workWeekStart(DateTime.now());

  Future<void> _edit({WorkEntry? entry, bool completePlan = false}) async {
    final saved = await showDialog<WorkEntry>(
      context: context,
      barrierDismissible: false,
      builder: (_) => WorkEntryDialog(entry: entry, completePlan: completePlan),
    );
    if (saved != null && mounted) {
      setState(() {
        _month = DateTime(saved.date.year, saved.date.month);
        _week = workWeekStart(saved.date);
      });
    }
  }

  Future<void> _delete(WorkEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除工时记录'),
        content: Text(
          '删除 ${entry.date.month}月${entry.date.day}日的 '
          '${formatWorkMinutes(entry.minutes)}${entry.status.label}记录吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(workHoursProvider.notifier).remove(entry.id!);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('删除失败，请重试')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled =
        ref.watch(developerModeProvider).asData?.value.enabled == true;
    return Scaffold(
      appBar: AppBar(
        title: const Text('勤工俭学工时'),
        actions: [
          if (enabled)
            IconButton(
              tooltip: '回到本周和本月',
              icon: const Icon(Icons.today_outlined),
              onPressed: () => setState(() {
                final now = DateTime.now();
                _month = DateTime(now.year, now.month);
                _week = workWeekStart(now);
              }),
            ),
        ],
      ),
      floatingActionButton: enabled
          ? FloatingActionButton(
              tooltip: '登记工时',
              onPressed: () => _edit(),
              child: const Icon(Icons.add),
            )
          : null,
      body: !enabled
          ? const Center(child: Text('请先开启开发者模式'))
          : ref
                .watch(workHoursProvider)
                .when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => Center(
                    child: TextButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('加载失败，重试'),
                      onPressed: () => ref.invalidate(workHoursProvider),
                    ),
                  ),
                  data: _content,
                ),
    );
  }

  Widget _content(List<WorkEntry> entries) {
    final monthEnd = DateTime(_month.year, _month.month + 1);
    final weekEnd = DateTime(_week.year, _week.month, _week.day + 7);
    final month = WorkHoursSummary(entries, _month, monthEnd);
    final week = WorkHoursSummary(entries, _week, weekEnd);
    final lastDay = DateTime(_week.year, _week.month, _week.day + 6);
    final records = entries
        .where((e) => !e.date.isBefore(_month) && e.date.isBefore(monthEnd))
        .toList();
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      children: [
        _PeriodNav(
          title: '${_month.year}年${_month.month}月',
          previousLabel: '上个月',
          nextLabel: '下个月',
          previous: () =>
              setState(() => _month = DateTime(_month.year, _month.month - 1)),
          next: () =>
              setState(() => _month = DateTime(_month.year, _month.month + 1)),
        ),
        Text('每月额度 40 小时', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: (month.completedMinutes / WorkHoursSummary.monthlyLimitMinutes)
              .clamp(0.0, 1.0),
          minHeight: 6,
          color: month.remainingMinutes < 0 ? scheme.error : scheme.primary,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 24,
          runSpacing: 16,
          children: [
            _Total(label: '已完成', minutes: month.completedMinutes),
            _Total(label: '已计划', minutes: month.plannedMinutes),
            _Total(
              label: month.remainingMinutes < 0 ? '已超出额度' : '剩余额度',
              minutes: month.remainingMinutes.abs(),
            ),
            _Total(
              label: month.availableMinutes < 0 ? '安排超出' : '还能安排',
              minutes: month.availableMinutes.abs(),
            ),
          ],
        ),
        if (month.availableMinutes < 0)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              '已完成与计划合计超出 40 小时，请调整后续安排。',
              style: TextStyle(color: scheme.error),
            ),
          ),
        const SizedBox(height: 20),
        const Divider(),
        _PeriodNav(
          title:
              '${_week.year}年 ${_week.month}/${_week.day} — ${lastDay.month}/${lastDay.day}',
          previousLabel: '上一周',
          nextLabel: '下一周',
          previous: () => setState(
            () => _week = DateTime(_week.year, _week.month, _week.day - 7),
          ),
          next: () => setState(
            () => _week = DateTime(_week.year, _week.month, _week.day + 7),
          ),
        ),
        Text('周工时合计', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 24,
          runSpacing: 12,
          children: [
            _Total(label: '已完成', minutes: week.completedMinutes),
            _Total(label: '已计划', minutes: week.plannedMinutes),
          ],
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < 7; index++)
          _DayRow(
            date: DateTime(_week.year, _week.month, _week.day + index),
            entries: entries,
          ),
        const Divider(),
        const SizedBox(height: 12),
        Text(
          '${_month.month}月记录 · ${records.length} 次',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (records.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('本月暂无工时记录'),
          ),
        for (final entry in records)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              entry.status == WorkStatus.completed
                  ? Icons.check_circle_outline
                  : Icons.event_outlined,
            ),
            title: Text(
              '${entry.date.month}月${entry.date.day}日 · ${formatWorkMinutes(entry.minutes)}',
            ),
            subtitle: Text(
              '${entry.status.label}${entry.note.isEmpty ? '' : ' · ${entry.note}'}',
            ),
            onTap: () => _edit(entry: entry),
            trailing: PopupMenuButton<String>(
              tooltip: '工时操作',
              onSelected: (action) {
                if (action == 'delete') {
                  _delete(entry);
                } else {
                  _edit(entry: entry, completePlan: action == 'complete');
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('编辑')),
                if (entry.status == WorkStatus.planned)
                  const PopupMenuItem(value: 'complete', child: Text('登记实际工时')),
                const PopupMenuItem(value: 'delete', child: Text('删除')),
              ],
            ),
          ),
      ],
    );
  }
}

class _PeriodNav extends StatelessWidget {
  const _PeriodNav({
    required this.title,
    required this.previousLabel,
    required this.nextLabel,
    required this.previous,
    required this.next,
  });
  final String title, previousLabel, nextLabel;
  final VoidCallback previous, next;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        tooltip: previousLabel,
        onPressed: previous,
        icon: const Icon(Icons.chevron_left),
      ),
      Expanded(
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      IconButton(
        tooltip: nextLabel,
        onPressed: next,
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
}

class _Total extends StatelessWidget {
  const _Total({required this.label, required this.minutes});
  final String label;
  final int minutes;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      Text(
        formatWorkMinutes(minutes),
        style: Theme.of(context).textTheme.titleMedium,
      ),
    ],
  );
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.date, required this.entries});
  final DateTime date;
  final List<WorkEntry> entries;
  @override
  Widget build(BuildContext context) {
    final summary = WorkHoursSummary(
      entries,
      date,
      DateTime(date.year, date.month, date.day + 1),
    );
    const days = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text('${days[date.weekday - 1]} ${date.month}/${date.day}'),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '完成 ${formatWorkMinutes(summary.completedMinutes)}'
              ' · 计划 ${formatWorkMinutes(summary.plannedMinutes)}',
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
