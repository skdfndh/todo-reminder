import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/task.dart';
import '../providers/task_providers.dart';
import '../theme.dart';

const _weekdayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

class TaskEditScreen extends ConsumerStatefulWidget {
  const TaskEditScreen({super.key, this.task});

  final Task? task;

  @override
  ConsumerState<TaskEditScreen> createState() => _TaskEditScreenState();
}

class _TaskEditScreenState extends ConsumerState<TaskEditScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _noteCtrl;

  late RepeatType _repeatType;
  late TimeOfDay _time;
  DateTime? _date;
  final Set<int> _weekdays = {};
  int _dayOfMonth = 1;
  late Priority _priority;
  bool _statisticsEnabled = false;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _enabled = true;

  bool get _isEditing => widget.task != null;
  bool get _isRecurring => _repeatType != RepeatType.once;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _titleCtrl = TextEditingController(text: t?.title ?? '');
    _noteCtrl = TextEditingController(text: t?.note ?? '');
    _repeatType = t?.repeatType ?? RepeatType.once;
    _time = TimeOfDay(hour: t?.remindHour ?? 9, minute: t?.remindMinute ?? 0);
    _date = t?.date != null ? DateTime.parse(t!.date!) : DateTime.now();
    _weekdays.addAll(t?.weekdays ?? const {1, 2, 3, 4, 5});
    _dayOfMonth = t?.dayOfMonth ?? 1;
    _priority = t?.priority ?? Priority.medium;
    _statisticsEnabled = t?.statisticsEnabled ?? false;
    _startDate = t?.startDate != null ? DateTime.parse(t!.startDate!) : null;
    _endDate = t?.endDate != null ? DateTime.parse(t!.endDate!) : null;
    _enabled = t?.enabled ?? true;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<DateTime?> _pickDay(DateTime initial) async {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _displayDate(DateTime d) =>
      '${d.month}月${d.day}日';

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      _toast('请输入事项标题');
      return;
    }
    if (_repeatType == RepeatType.weekly && _weekdays.isEmpty) {
      _toast('请至少选择一个星期几');
      return;
    }
    if (_repeatType == RepeatType.once && _date == null) {
      _toast('请选择提醒日期');
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final original = widget.task;

    final task = Task(
      id: original?.id,
      title: title,
      note: _noteCtrl.text.trim(),
      repeatType: _repeatType,
      remindHour: _time.hour,
      remindMinute: _time.minute,
      date: _repeatType == RepeatType.once ? _formatDate(_date!) : null,
      weekdays: _repeatType == RepeatType.weekly ? Set.of(_weekdays) : const {},
      dayOfMonth: _repeatType == RepeatType.monthly ? _dayOfMonth : null,
      enabled: _enabled,
      priority: _priority,
      pinned: original?.pinned ?? false,
      statisticsEnabled: _isRecurring ? _statisticsEnabled : false,
      startDate: _isRecurring && _startDate != null
          ? _formatDate(_startDate!)
          : null,
      endDate: _isRecurring && _endDate != null ? _formatDate(_endDate!) : null,
      doneToday: original?.doneToday ?? false,
      doneDate: original?.doneDate,
      doneCount: original?.doneCount ?? 0,
      createdAt: original?.createdAt ?? now,
      updatedAt: now,
    );

    final notifier = ref.read(tasksProvider.notifier);
    if (_isEditing) {
      await notifier.updateTask(task);
    } else {
      await notifier.add(task);
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑待办' : '新建待办'),
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.ink,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleCtrl,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '事项标题',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: '备注（可选）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Text('重复方式', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final rt in RepeatType.values)
                ChoiceChip(
                  label: Text(rt.label),
                  selected: _repeatType == rt,
                  onSelected: (_) => setState(() => _repeatType = rt),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: const Text('提醒时间'),
            trailing: Text(
              _time.format(context),
              style: theme.textTheme.titleMedium,
            ),
            onTap: _pickTime,
          ),
          if (_repeatType == RepeatType.once)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: const Text('提醒日期'),
              trailing: Text(
                _displayDate(_date ?? DateTime.now()),
                style: theme.textTheme.titleMedium,
              ),
              onTap: () async {
                final d = await _pickDay(_date ?? DateTime.now());
                if (d != null) setState(() => _date = d);
              },
            ),
          if (_repeatType == RepeatType.weekly) ...[
            const SizedBox(height: 8),
            Text('选择星期几', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (var d = 1; d <= 7; d++)
                  FilterChip(
                    label: Text(_weekdayNames[d - 1]),
                    selected: _weekdays.contains(d),
                    onSelected: (sel) => setState(() {
                      if (sel) {
                        _weekdays.add(d);
                      } else {
                        _weekdays.remove(d);
                      }
                    }),
                  ),
              ],
            ),
          ],
          if (_repeatType == RepeatType.monthly) ...[
            const SizedBox(height: 8),
            Text('每月 $_dayOfMonth 号', style: theme.textTheme.titleMedium),
            Slider(
              value: _dayOfMonth.toDouble(),
              min: 1,
              max: 31,
              divisions: 30,
              label: '$_dayOfMonth',
              onChanged: (v) => setState(() => _dayOfMonth = v.round()),
            ),
          ],
          if (_isRecurring) ...[
            const SizedBox(height: 8),
            Text('时间窗口（可选）', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            _WindowDateTile(
              icon: Icons.play_circle_outline,
              label: '开始日期',
              value: _startDate,
              display: _startDate != null ? _displayDate(_startDate!) : '未设置',
              onPick: () async {
                final d = await _pickDay(_startDate ?? DateTime.now());
                if (d != null) setState(() => _startDate = d);
              },
              onClear: () => setState(() => _startDate = null),
            ),
            _WindowDateTile(
              icon: Icons.stop_circle_outlined,
              label: '结束日期',
              value: _endDate,
              display: _endDate != null ? _displayDate(_endDate!) : '未设置',
              onPick: () async {
                final d = await _pickDay(_endDate ?? DateTime.now());
                if (d != null) setState(() => _endDate = d);
              },
              onClear: () => setState(() => _endDate = null),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('统计完成天数'),
              subtitle: const Text('打勾后累计显示「已完成 N 天」'),
              value: _statisticsEnabled,
              onChanged: (v) => setState(() => _statisticsEnabled = v),
            ),
          ],
          const SizedBox(height: 16),
          Text('重要性', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final p in Priority.values)
                ChoiceChip(
                  label: Text(p.label),
                  selected: _priority == p,
                  // 只靠圈内填色区分选中态，不要勾号。
                  showCheckmark: false,
                  avatar: CircleAvatar(
                    radius: 6,
                    backgroundColor: priorityColor(p),
                  ),
                  onSelected: (_) => setState(() => _priority = p),
                ),
            ],
          ),
          if (_isRecurring)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('启用提醒'),
              subtitle: const Text('关闭后暂停提醒，但保留这条待办'),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: AppColors.ink,
              foregroundColor: AppColors.surface,
            ),
            child: const Text('保存'),
          ),
        ),
      ),
    );
  }
}

class _WindowDateTile extends StatelessWidget {
  const _WindowDateTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.display,
    required this.onPick,
    required this.onClear,
  });

  final IconData icon;
  final String label;
  final DateTime? value;
  final String display;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(display, style: theme.textTheme.titleMedium),
          if (value != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onClear,
            ),
        ],
      ),
      onTap: onPick,
    );
  }
}
