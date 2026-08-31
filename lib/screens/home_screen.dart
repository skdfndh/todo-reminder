import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task.dart';
import '../providers/task_providers.dart';
import '../services/notification_service.dart';
import '../theme.dart';
import '../utils/motion.dart';
import '../utils/routes.dart';
import '../widgets/pressable_scale.dart';
import '../widgets/task_tile.dart';
import '../widgets/update_dialog.dart';
import 'settings_screen.dart';
import 'task_edit_screen.dart';

const _weekdayNames = ['一', '二', '三', '四', '五', '六', '日'];

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const _initialPage = 10000;

  late DateTime _selected;
  late DateTime _pageAnchor;
  late String _todayKey;
  late final PageController _pageController;
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  bool _calendarVisible = false;
  late final NotificationService _notificationService;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selected = DateTime(now.year, now.month, now.day);
    _pageAnchor = _selected;
    _pageController = PageController(initialPage: _initialPage);
    _todayKey = dateKey(now);
    _notificationService = ref.read(notificationServiceProvider);
    _notificationService.openedTaskId.addListener(_openFromNotification);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _openFromNotification(),
    );
    // 每 30 秒检查一次是否跨天，午夜自动进入新日期并重排通知。
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      final n = DateTime.now();
      final k = dateKey(n);
      if (k != _todayKey) {
        _todayKey = k;
        if (mounted) {
          _selectDay(DateTime(n.year, n.month, n.day), animate: false);
        }
        ref.read(tasksProvider.notifier).rollover();
      }
    });
    // 首帧渲染后后台检查更新（fire-and-forget，异常内部静默，不阻塞启动）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(checkForUpdatesAndPrompt(context, ref));
    });
  }

  @override
  void dispose() {
    _notificationService.openedTaskId.removeListener(_openFromNotification);
    _timer?.cancel();
    _pageController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openFromNotification() {
    final id = _notificationService.openedTaskId.value;
    final tasks = ref.read(tasksProvider).valueOrNull;
    if (id == null) return;
    if (tasks == null) {
      Future<void>.delayed(
        const Duration(milliseconds: 300),
        _openFromNotification,
      );
      return;
    }
    Task? task;
    for (final item in tasks) {
      if (item.id == id) {
        task = item;
        break;
      }
    }
    if (task == null || !mounted) return;
    final day = task.repeatType == RepeatType.once && task.date != null
        ? DateTime.parse(task.date!)
        : DateTime.now();
    _selectDay(DateTime(day.year, day.month, day.day), animate: false);
    Navigator.of(context).push(fadeSlideRoute(TaskEditScreen(task: task)));
    _notificationService.openedTaskId.value = null;
  }

  DateTime _dayForPage(int page) =>
      _pageAnchor.add(Duration(days: page - _initialPage));

  int _pageForDay(DateTime day) =>
      _initialPage + day.difference(_pageAnchor).inDays;

  void _selectDay(DateTime day, {bool animate = true}) {
    final normalized = DateTime(day.year, day.month, day.day);
    final targetPage = _pageForDay(normalized);
    if (!_pageController.hasClients || !animate) {
      _pageController.jumpToPage(targetPage);
      setState(() => _selected = normalized);
      return;
    }
    _pageController.animateToPage(
      targetPage,
      duration: const Duration(milliseconds: 220),
      curve: AppMotion.easeOut,
    );
  }

  void _goToday() {
    final n = DateTime.now();
    _selectDay(DateTime(n.year, n.month, n.day));
  }

  Future<void> _showAddOptions() async {
    final quickTasks = await ref.read(taskRepositoryProvider).getQuickTasks();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      sheetAnimationStyle: AppMotion.sheetStyle,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('新建待办'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(
                  context,
                ).push(fadeSlideRoute(TaskEditScreen(initialDate: _selected)));
              },
            ),
            if (quickTasks.isNotEmpty) const ListTile(title: Text('常用一次性待办')),
            for (final quick in quickTasks)
              ListTile(
                leading: Icon(
                  Icons.bookmark,
                  color: priorityColor(quick.priority),
                ),
                title: Text(quick.title),
                onTap: () async {
                  Navigator.pop(ctx);
                  final now = DateTime.now().millisecondsSinceEpoch;
                  await ref
                      .read(tasksProvider.notifier)
                      .add(
                        Task(
                          title: quick.title,
                          note: quick.note,
                          tags: quick.tags,
                          repeatType: RepeatType.once,
                          remindHour: quick.remindHour,
                          remindMinute: quick.remindMinute,
                          advanceMinutes: quick.advanceMinutes,
                          date: dateKey(_selected),
                          priority: quick.priority,
                          sourceQuickTaskId: quick.id,
                          createdAt: now,
                          updatedAt: now,
                        ),
                      );
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _jump() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      _selectDay(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksProvider);
    final mode = ref.watch(sortModeProvider);
    final doneLast = ref.watch(doneLastProvider);
    final reduce = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('待办提醒'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        actions: [
          PressableScale(
            child: IconButton(
              tooltip: '设置',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () =>
                  Navigator.of(context)
                      .push(fadeSlideRoute(const SettingsScreen())),
            ),
          ),
        ],
      ),
      floatingActionButton: PressableScale(
        scale: 0.95,
        child: FloatingActionButton(
          tooltip: '添加待办',
          backgroundColor: AppColors.ink,
          foregroundColor: AppColors.surface,
          elevation: 4,
          onPressed: _showAddOptions,
          child: const Icon(Icons.add),
        ),
      ),
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (tasks) {
          Widget buildDayPage(DateTime day) {
            final isToday = dateKey(day) == _todayKey;
            final searching = _query.trim().isNotEmpty;
            final searchTasks = searching
                ? tasks.where(_matches).toList()
                : const <Task>[];
            final active = sortTasks(
              tasks.where((t) => t.isActiveOn(day) && _matches(t)).toList(),
              mode,
              doneLast: doneLast,
              viewDay: day,
            );
            final future = isToday ? _tomorrowImportant(tasks) : const <Task>[];
            return Column(
              children: [
                _DateHeader(
                  selected: day,
                  isToday: isToday,
                  onPrev: () =>
                      _selectDay(day.subtract(const Duration(days: 1))),
                  onNext: () => _selectDay(day.add(const Duration(days: 1))),
                  onJump: _jump,
                  onGoToday: _goToday,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 96),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (value) => setState(() => _query = value),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                            prefixIcon: Icon(Icons.search, size: 24),
                            prefixIconConstraints: BoxConstraints(
                              minWidth: 48,
                              minHeight: 40,
                            ),
                            hintText: '搜索事项、备注或标签',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => setState(
                              () => _calendarVisible = !_calendarVisible,
                            ),
                            icon: Icon(
                              _calendarVisible
                                  ? Icons.calendar_month
                                  : Icons.calendar_month_outlined,
                            ),
                            label: Text(_calendarVisible ? '收起日历' : '展开日历'),
                          ),
                        ),
                      ),
                      AnimatedSize(
                        duration: reduce
                            ? Duration.zero
                            : AppMotion.stateDuration,
                        curve: AppMotion.easeOut,
                        child: _calendarVisible || searching
                            ? _MonthCalendar(
                                selected: day,
                                tasks: tasks,
                                searchTasks: searchTasks,
                                onSelect: _selectDay,
                              )
                            : const SizedBox.shrink(),
                      ),
                      (active.isEmpty && future.isEmpty)
                          ? _EmptyState(isToday: isToday, selected: day)
                          : Column(
                              children: [
                                for (final t in active)
                                  TaskTile(
                                    task: t,
                                    done: t.isDoneOn(day),
                                    onTap: () => Navigator.of(context).push(
                                      fadeSlideRoute(TaskEditScreen(task: t)),
                                    ),
                                    onToggleDone: () => ref
                                        .read(tasksProvider.notifier)
                                        .toggleDone(t, day),
                                    canToggle: !day.isAfter(
                                      DateTime(
                                        DateTime.now().year,
                                        DateTime.now().month,
                                        DateTime.now().day,
                                      ),
                                    ),
                                    onTogglePin: () => ref
                                        .read(tasksProvider.notifier)
                                        .togglePin(t),
                                    onDelete: () => _confirmDelete(t),
                                  ),
                                if (future.isNotEmpty)
                                  _FutureSection(
                                    tasks: future,
                                    tomorrow: day.add(const Duration(days: 1)),
                                    onOpen: (_) => _selectDay(
                                      day.add(const Duration(days: 1)),
                                    ),
                                  ),
                              ],
                            ),
                    ],
                  ),
                ),
              ],
            );
          }

          if (reduce) return buildDayPage(_selected);
          return PageView.builder(
            controller: _pageController,
            onPageChanged: (page) =>
                setState(() => _selected = _dayForPage(page)),
            itemBuilder: (context, page) => buildDayPage(_dayForPage(page)),
          );
        },
      ),
    );
  }

  List<Task> _tomorrowImportant(List<Task> tasks) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final tomorrow = todayOnly.add(const Duration(days: 1));
    return sortTasks(
      tomorrowImportantTasks(tasks, tomorrow).where(_matches).toList(),
      ref.read(sortModeProvider),
      doneLast: ref.read(doneLastProvider),
      viewDay: tomorrow,
    );
  }

  bool _matches(Task task) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    return '${task.title} ${task.note} ${task.tags.join(' ')}'
        .toLowerCase()
        .contains(query);
  }

  Future<void> _confirmDelete(Task t) async {
    final ok = await showDialog<bool>(
      context: context,
      animationStyle: AppMotion.sheetStyle,
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

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.selected,
    required this.tasks,
    required this.searchTasks,
    required this.onSelect,
  });

  final DateTime selected;
  final List<Task> tasks;
  final List<Task> searchTasks;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaceColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.surfaceContainerHighest
        : AppColors.surface;
    final outlineColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.outline
        : AppColors.line;
    final first = DateTime(selected.year, selected.month);
    final days = DateTime(selected.year, selected.month + 1, 0).day;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final cells = <DateTime?>[
      ...List<DateTime?>.filled(first.weekday - 1, null),
      for (var day = 1; day <= days; day++)
        DateTime(selected.year, selected.month, day),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: outlineColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '${selected.year}年${selected.month}月',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                searchTasks.isEmpty ? '红色为重要事项' : '圆点为搜索结果',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final name in _weekdayNames)
                Expanded(child: Center(child: Text(name))),
            ],
          ),
          const SizedBox(height: 2),
          for (var index = 0; index < cells.length; index += 7)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final day in cells.sublist(index, index + 7))
                  Expanded(
                    child: _CalendarDay(
                      day: day,
                      selected: selected,
                      importantTasks: day != null && day.isAfter(todayOnly)
                          ? tasks
                                .where(
                                  (task) =>
                                      task.priority == Priority.high &&
                                      task.repeatType != RepeatType.daily &&
                                      task.isActiveOn(day),
                                )
                                .toList()
                          : const [],
                      hasSearchResult:
                          day != null &&
                          searchTasks.any((task) => task.isActiveOn(day)),
                      onSelect: onSelect,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.day,
    required this.selected,
    required this.importantTasks,
    required this.hasSearchResult,
    required this.onSelect,
  });

  final DateTime? day;
  final DateTime selected;
  final List<Task> importantTasks;
  final bool hasSearchResult;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    if (day == null) return const SizedBox(height: 52);
    final isSelected = dateKey(day!) == dateKey(selected);
    final hasImportant = importantTasks.isNotEmpty;
    return InkWell(
      onTap: () => onSelect(day!),
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
          child: Column(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? hasImportant
                            ? AppColors.high
                            : Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${day!.day}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimary
                        : hasImportant
                        ? AppColors.high
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: hasImportant
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
              ),
              if (hasSearchResult)
                Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              for (final task in importantTasks)
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.high,
                    fontSize: 9,
                    height: 1.1,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({
    required this.selected,
    required this.isToday,
    required this.onPrev,
    required this.onNext,
    required this.onJump,
    required this.onGoToday,
  });

  final DateTime selected;
  final bool isToday;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onJump;
  final VoidCallback onGoToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = isToday ? '今天' : '${selected.month}月${selected.day}日';
    final weekday = '周${_weekdayNames[selected.weekday - 1]}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Row(
        children: [
          PressableScale(
            child: IconButton(
              onPressed: onPrev,
              icon: const Icon(Icons.chevron_left),
            ),
          ),
          Expanded(
            child: PressableScale(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onJump,
                child: Column(
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
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
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (!isToday) ...[
                          const SizedBox(width: 8),
                          PressableScale(
                            child: GestureDetector(
                              onTap: onGoToday,
                              child: Text(
                                '回到今天',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
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
          ),
          PressableScale(
            child: IconButton(
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right),
            ),
          ),
        ],
      ),
    );
  }
}

class _FutureSection extends StatelessWidget {
  const _FutureSection({
    required this.tasks,
    required this.tomorrow,
    required this.onOpen,
  });

  final List<Task> tasks;
  final DateTime tomorrow;
  final ValueChanged<Task> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaceColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.surfaceContainerHighest
        : AppColors.surface;
    final outlineColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.outline
        : AppColors.line;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: outlineColor),
        ),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          title: Text(
            '明日重要待办 · ${tasks.length} 条',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
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
                  '${tomorrow.month}月${tomorrow.day}日 · ${t.timeLabel}',
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
          Icon(Icons.event_note, size: 64, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            isToday ? '今天没有待办' : '${selected.month}月${selected.day}日没有待办',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            '点击右下角 + 添加一条提醒',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
