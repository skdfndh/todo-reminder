import 'package:flutter/material.dart';

import '../utils/task_text_import.dart';

class TaskImportDialog extends StatefulWidget {
  const TaskImportDialog({super.key});

  @override
  State<TaskImportDialog> createState() => _TaskImportDialogState();
}

class _TaskImportDialogState extends State<TaskImportDialog> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('粘贴文字导入'),
      scrollable: true,
      content: SizedBox(
        width: 480,
        child: TextField(
          autofocus: true,
          controller: _text,
          minLines: 4,
          maxLines: 8,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
            labelText: '通知或任务原文',
            hintText: '例如：请在明天下午 5 点前提交实习报告，格式为 PDF。',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ValueListenableBuilder(
          valueListenable: _text,
          builder: (context, value, _) => FilledButton(
            onPressed: value.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context, parseTaskText(value.text)),
            child: const Text('生成待办'),
          ),
        ),
      ],
    );
  }
}
