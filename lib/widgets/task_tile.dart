import 'package:flutter/material.dart';

import '../models/task.dart';
import '../theme.dart';
import '../utils/motion.dart';
import 'pressable_scale.dart';

/// 单条待办卡片：按重要性涂色，支持打勾、置顶、删除。
class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.onTap,
    required this.onToggleDone,
    required this.onTogglePin,
    required this.onDelete,
    this.done,
    this.canToggle = true,
  });

  final Task task;
  final VoidCallback onTap;
  final VoidCallback onToggleDone;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;

  /// 打勾显示状态；不传则用 task.doneToday（按天视图下由调用方传入视图日的完成态）。
  final bool? done;
  final bool canToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final next = task.nextOccurrence(now);
    final overdue =
        task.repeatType == RepeatType.once &&
        next != null &&
        next.isBefore(now);

    final color = priorityColor(task.priority);
    final tint = priorityTint(task.priority);
    final done = this.done ?? task.doneToday;

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

    final titleColor = done
        ? theme.colorScheme.onSurfaceVariant
        : AppColors.ink;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: done ? AppColors.paper : tint,
        borderRadius: BorderRadius.circular(14),
        // 极轻的暖阴影提层次，保留手账纸卡感。
        boxShadow: [
          BoxShadow(
            color: const Color(0x1426241F),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
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
            _CheckCircle(
              done: done,
              color: color,
              onTap: canToggle ? onToggleDone : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PressableScale(
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
                                decoration: done
                                    ? TextDecoration.lineThrough
                                    : null,
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
                      if (task.tags.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          task.tags.map((tag) => '#$tag').join('  '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: color,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            PressableScale(
              child: IconButton(
                tooltip: task.pinned ? '取消置顶' : '置顶',
                icon: Icon(
                  task.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                  size: 20,
                  color: task.pinned
                      ? color
                      : theme.colorScheme.onSurfaceVariant,
                ),
                onPressed: onTogglePin,
              ),
            ),
            PressableScale(
              child: IconButton(
                tooltip: '删除',
                icon: Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                onPressed: onDelete,
              ),
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return PressableScale(
      scale: 0.92,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: reduce ? Duration.zero : AppMotion.stateDuration,
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? color : Colors.transparent,
            border: Border.all(color: done ? color : AppColors.muted, width: 2),
          ),
          // 勾号从轻微缩小 + 淡入，状态切换不突兀（打勾是高频，保持快速）。
          child: AnimatedScale(
            scale: done ? 1.0 : 0.7,
            duration: reduce ? Duration.zero : AppMotion.stateDuration,
            curve: AppMotion.easeOut,
            child: AnimatedOpacity(
              opacity: done ? 1.0 : 0.0,
              duration: reduce ? Duration.zero : AppMotion.stateDuration,
              curve: AppMotion.easeOut,
              child: const Icon(Icons.check, size: 16, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
