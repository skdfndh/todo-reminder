import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/developer_mode_provider.dart';
import '../screens/work_hours_screen.dart';
import '../utils/motion.dart';

class DeveloperModeSection extends ConsumerStatefulWidget {
  const DeveloperModeSection({super.key});

  @override
  ConsumerState<DeveloperModeSection> createState() =>
      _DeveloperModeSectionState();
}

class _DeveloperModeSectionState extends ConsumerState<DeveloperModeSection> {
  bool _busy = false;

  Future<void> _toggle(bool enabled, DeveloperModeState mode) async {
    setState(() => _busy = true);
    try {
      if (enabled) {
        await showDialog<void>(
          context: context,
          animationStyle: AppMotion.sheetStyle,
          builder: (_) => _PasscodeDialog(create: !mode.configured),
        );
      } else {
        await ref.read(developerModeProvider.notifier).disable();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('保存失败，请重试')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(developerModeProvider);
    return mode.when(
      loading: () => const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.developer_mode),
        title: Text('开发者模式'),
        subtitle: Text('正在读取设置'),
      ),
      error: (_, _) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.developer_mode),
        title: const Text('开发者模式'),
        subtitle: const Text('读取失败，点击重试'),
        onTap: () => ref.invalidate(developerModeProvider),
      ),
      data: (value) => Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.developer_mode),
            title: const Text('开发者模式'),
            subtitle: Text(
              value.enabled
                  ? '已开启'
                  : value.configured
                  ? '已关闭'
                  : '设置本机口令后开启',
            ),
            value: value.enabled,
            onChanged: _busy ? null : (enabled) => _toggle(enabled, value),
          ),
          if (value.enabled)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.work_outline),
              title: const Text('勤工俭学工时'),
              subtitle: const Text('实际工时、每周汇总与每月额度'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const WorkHoursScreen(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PasscodeDialog extends ConsumerStatefulWidget {
  const _PasscodeDialog({required this.create});

  final bool create;

  @override
  ConsumerState<_PasscodeDialog> createState() => _PasscodeDialogState();
}

class _PasscodeDialogState extends ConsumerState<_PasscodeDialog> {
  final _passcode = TextEditingController();
  final _confirmation = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _passcode.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    final passcode = _passcode.text;
    if (passcode.length < 6 ||
        passcode.length > 64 ||
        passcode.trim().isEmpty) {
      setState(() => _error = '口令需为 6 至 64 位');
      return;
    }
    if (widget.create && passcode != _confirmation.text) {
      setState(() => _error = '两次输入的口令不一致');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final notifier = ref.read(developerModeProvider.notifier);
      if (widget.create) {
        await notifier.setPasscode(passcode);
      } else if (!await notifier.unlock(passcode)) {
        if (mounted) setState(() => _error = '口令错误，请重试');
        return;
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _error = '保存失败，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(widget.create ? '设置开发者口令' : '解锁开发者模式'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _passcode,
                autofocus: true,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                enabled: !_saving,
                maxLength: 64,
                textInputAction: widget.create
                    ? TextInputAction.next
                    : TextInputAction.done,
                onSubmitted: widget.create ? null : (_) => _submit(),
                decoration: InputDecoration(
                  labelText: '本机口令',
                  helperText: widget.create ? '6 至 64 位字符' : null,
                  errorText: _error,
                  errorMaxLines: 2,
                  counterText: '',
                ),
              ),
              if (widget.create) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmation,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  enabled: !_saving,
                  maxLength: 64,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: '再次输入口令',
                    counterText: '',
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: Text(_saving ? '正在保存' : '开启'),
          ),
        ],
      ),
    );
  }
}
