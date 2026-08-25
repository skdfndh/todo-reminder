import 'package:flutter/material.dart';

import '../models/task.dart';
import '../theme.dart';

/// 单条待办卡片：按重要性涂色，支持打勾、置顶、删除。
class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.onTap,
    required this.onToggleDone,
    required this.onTogglePin,
    required this.onDelete,
  });

  final Task task;
  final VoidCallback onTap;
  final VoidCallback onToggleDone;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final next = task.nextOccurrence(now);
    final overdue = task.repeatType == RepeatType.once &&
        next != null &&
        next.isBefore(now);

    final color = priorityColor(task.priority);
    final tint = priorityTint(task.priority);
    final done = task.doneToday;

    final subtitleParts = <String>[
      task.timeLabel,
      if (overdue)
        '已过期'
      else if (task.repeatRuleLabel.isNotEmpty)
        task.repeatRuleLabel,
      if (task.statisticsEnabled && task.repeatType != RepeatType.once)
        '已完成 ${task.doneCount} 天',
    ];
    final subtitle = subtitleParts.join(' · ');

    final titleColor = done ? theme.colorScheme.onSurfaceVariant : AppColors.ink;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: done ? AppColors.paper : tint,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(color: color, width: 4),
          top: BorderSide(color: color.withValues(alpha: 0.18)),
          right: BorderSide(color: color.withValues(alpha: 0.18)),
          bottom: BorderSide(color: color.withValues(alpha: 0.18)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
        child: Row(
          children: [
            _CheckCircle(done: done, color: color, onTap: onToggleDone),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (task.pinned) ...[
                          Icon(Icons.push_pin, size: 14, color: color),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            task.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: titleColor,
                              fontWeight: FontWeight.w600,
                              decoration:
                                  done ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: task.pinned ? '取消置顶' : '置顶',
              icon: Icon(
                task.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                size: 20,
                color: task.pinned ? color : theme.colorScheme.onSurfaceVariant,
              ),
              onPressed: onTogglePin,
            ),
            IconButton(
              tooltip: '删除',
              icon: Icon(Icons.delete_outline,
                  size: 20, color: theme.colorScheme.onSurfaceVariant),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckCircle extends StatelessWidget {
  const _CheckCircle({
    required this.done,
    required this.color,
    required this.onTap,
  });

  final bool done;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? color : Colors.transparent,
          border: Border.all(
            color: done ? color : AppColors.muted,
            width: 2,
          ),
        ),
        child: done
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : null,
      ),
    );
  }
}
