import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task.dart';
import '../providers/task_providers.dart';
import '../theme.dart';
import '../widgets/task_tile.dart';
import 'settings_screen.dart';
import 'task_edit_screen.dart';

const _weekdayNames = ['一', '二', '三', '四', '五', '六', '日'];

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late DateTime _selected;
  late String _todayKey;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selected = DateTime(now.year, now.month, now.day);
    _todayKey = dateKey(now);
    // 每 30 秒检查一次是否跨天，午夜 0 点自动翻页 + 复位打勾 + 重排通知。
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      final n = DateTime.now();
      final k = dateKey(n);
      if (k != _todayKey) {
        _todayKey = k;
        if (mounted) {
          setState(() => _selected = DateTime(n.year, n.month, n.day));
        }
        ref.read(tasksProvider.notifier).rollover();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _isToday => dateKey(_selected) == _todayKey;

  void _shift(int days) {
    setState(() => _selected = _selected.add(Duration(days: days)));
  }

  Future<void> _jump() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() => _selected = DateTime(picked.year, picked.month, picked.day));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksProvider);
    final mode = ref.watch(sortModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('待办提醒'),
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.ink,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: '设置',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.ink,
        foregroundColor: AppColors.surface,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TaskEditScreen()),
        ),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          _DateHeader(
            selected: _selected,
            isToday: _isToday,
            onPrev: () => _shift(-1),
            onNext: () => _shift(1),
            onJump: _jump,
          ),
          Expanded(
            child: tasksAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败：$e')),
              data: (tasks) {
                final active = sortTasks(
                  tasks.where((t) => t.isActiveOn(_selected)).toList(),
                  mode,
                );
                final future = _isToday ? _futureOnce(tasks) : const <Task>[];

                if (active.isEmpty && future.isEmpty) {
                  return _EmptyState(isToday: _isToday, selected: _selected);
                }

                return ListView(
                  padding: const EdgeInsets.only(bottom: 96),
                  children: [
                    if (active.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: Text(
                          _isToday ? '今天' : '${_selected.month}月${_selected.day}日',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(color: AppColors.muted),
                        ),
                      ),
                    for (final t in active)
                      TaskTile(
                        task: t,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TaskEditScreen(task: t),
                          ),
                        ),
                        onToggleDone: () =>
                            ref.read(tasksProvider.notifier).toggleDone(t),
                        onTogglePin: () =>
                            ref.read(tasksProvider.notifier).togglePin(t),
                        onDelete: () => _confirmDelete(t),
                      ),
                    if (future.isNotEmpty)
                      _FutureSection(
                        tasks: future,
                        onOpen: (t) {
                          final d = DateTime.parse(t.date!);
                          setState(() => _selected =
                              DateTime(d.year, d.month, d.day));
                        },
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Task> _futureOnce(List<Task> tasks) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    return sortTasks(
      tasks.where((t) {
        if (t.repeatType != RepeatType.once || t.date == null) return false;
        final d = DateTime.parse(t.date!);
        return DateTime(d.year, d.month, d.day).isAfter(todayOnly);
      }).toList(),
      ref.read(sortModeProvider),
    );
  }

  Future<void> _confirmDelete(Task t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除待办'),
        content: Text('确定删除「${t.title}」吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(tasksProvider.notifier).remove(t);
    }
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({
    required this.selected,
    required this.isToday,
    required this.onPrev,
    required this.onNext,
    required this.onJump,
  });

  final DateTime selected;
  final bool isToday;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onJump;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = isToday ? '今天' : '${selected.month}月${selected.day}日';
    final weekday = '周${_weekdayNames[selected.weekday - 1]}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Row(
        children: [
          IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onJump,
              child: Column(
                children: [
                  Text(
                    title,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        weekday,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                      if (!isToday) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: onJump,
                          child: Text(
                            '回到今天',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
        ],
      ),
    );
  }
}

class _FutureSection extends StatelessWidget {
  const _FutureSection({required this.tasks, required this.onOpen});

  final List<Task> tasks;
  final ValueChanged<Task> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          title: Text(
            '未来待办 · ${tasks.length} 条',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          children: [
            for (final t in tasks)
              ListTile(
                dense: true,
                leading: Icon(
                  Icons.event,
                  size: 18,
                  color: priorityColor(t.priority),
                ),
                title: Text(t.title),
                subtitle: Text(
                  '${t.date?.substring(5).replaceAll('-', '月')}日 · ${t.timeLabel}',
                ),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => onOpen(t),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isToday, required this.selected});

  final bool isToday;
  final DateTime selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_note, size: 64, color: AppColors.line),
          const SizedBox(height: 12),
          Text(
            isToday ? '今天没有待办' : '${selected.month}月${selected.day}日没有待办',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            '点击右下角 + 添加一条提醒',
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
