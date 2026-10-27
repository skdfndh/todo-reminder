import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/work_entry.dart';
import '../providers/work_hours_provider.dart';

class WorkEntryDialog extends ConsumerStatefulWidget {
  const WorkEntryDialog({super.key, this.entry});

  final WorkEntry? entry;

  @override
  ConsumerState<WorkEntryDialog> createState() => _WorkEntryDialogState();
}

class _WorkEntryDialogState extends ConsumerState<WorkEntryDialog> {
  final _hours = TextEditingController();
  final _minutes = TextEditingController();
  final _note = TextEditingController();
  late DateTime _date;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    final now = DateTime.now();
    _date = entry?.date ?? DateTime(now.year, now.month, now.day);
    _hours.text = ((entry?.minutes ?? 120) ~/ 60).toString();
    _minutes.text = ((entry?.minutes ?? 120) % 60).toString();
    _note.text = entry?.note ?? '';
  }

  @override
  void dispose() {
    _hours.dispose();
    _minutes.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final hours = int.tryParse(_hours.text);
    final minutes = int.tryParse(_minutes.text);
    if (hours == null ||
        minutes == null ||
        hours < 0 ||
        minutes < 0 ||
        minutes > 59 ||
        hours * 60 + minutes <= 0 ||
        hours * 60 + minutes > 1440) {
      setState(() => _error = '请输入有效时长，需大于 0 且不超过 24 小时');
      return;
    }
    final now = DateTime.now();
    if (_date.isAfter(DateTime(now.year, now.month, now.day))) {
      setState(() => _error = '实际工时不能登记在未来日期');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final entry = WorkEntry(
        id: widget.entry?.id,
        date: _date,
        minutes: hours * 60 + minutes,
        note: _note.text.trim(),
      );
      final all = await ref.read(workHoursProvider.future);
      // 编辑时替换原记录，避免同一班次重复计入额度。
      final other = all.where(
        (item) => entry.id == null || item.id != entry.id,
      );
      final summary = WorkHoursSummary(
        [...other, entry],
        DateTime(_date.year, _date.month),
        DateTime(_date.year, _date.month + 1),
      );
      if (!mounted) return;
      if (summary.remainingMinutes < 0) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('超出本月额度'),
            content: Text(
              '${_date.year}年${_date.month}月实际工时合计 '
              '${formatWorkMinutes(summary.completedMinutes)}，'
              '超过 40 小时上限 ${formatWorkMinutes(-summary.remainingMinutes)}。仍然保存吗？',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('返回调整'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('仍然保存'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
      }
      await ref.read(workHoursProvider.notifier).save(entry);
      if (mounted) Navigator.of(context).pop(entry);
    } catch (_) {
      if (mounted) setState(() => _error = '保存失败，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text(widget.entry == null ? '登记工时' : '编辑工时'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text('${_date.year}年${_date.month}月${_date.day}日'),
                trailing: const Icon(Icons.edit_calendar_outlined),
                enabled: !_saving,
                onTap: () async {
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _date.isAfter(today) ? today : _date,
                    firstDate: DateTime(2000),
                    lastDate: today,
                  );
                  if (date != null && mounted) setState(() => _date = date);
                },
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final hours in [2, 3, 4])
                    ChoiceChip(
                      label: Text('$hours 小时'),
                      showCheckmark: false,
                      selected: _hours.text == '$hours' && _minutes.text == '0',
                      onSelected: _saving
                          ? null
                          : (_) => setState(() {
                              _hours.text = '$hours';
                              _minutes.text = '0';
                            }),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _hours,
                      enabled: !_saving,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: '小时',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _minutes,
                      enabled: !_saving,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: '分钟',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _note,
                enabled: !_saving,
                maxLines: 2,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: '备注（可选）',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? '正在保存' : '保存'),
        ),
      ],
    ),
  );
}
