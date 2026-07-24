import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/subscription.dart';
import '../../data/notifications/notification_service.dart';
import '../../providers/notification_providers.dart';
import '../../providers/subscription_providers.dart';

/// 결제 며칠 전에 알림을 받을지 고르는 칩들.
///
/// 여러 개를 동시에 고를 수 있다. 일주일 전에 미리 알고, 하루 전에 한 번 더
/// 받고 싶은 경우가 흔하다. 하나도 안 고르면 알림을 받지 않는다.
class ReminderDayPicker extends StatelessWidget {
  const ReminderDayPicker({
    super.key,
    required this.selected,
    required this.onToggle,
    this.enabled = true,
  });

  final List<int> selected;
  final ValueChanged<int> onToggle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final days in ReminderOptions.choices)
            GestureDetector(
              onTap: enabled ? () => onToggle(days) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: selected.contains(days)
                      ? AppColors.accent
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: selected.contains(days)
                        ? AppColors.accent
                        : theme.dividerColor,
                  ),
                ),
                child: Text(
                  ReminderOptions.label(days),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected.contains(days)
                        ? AppColors.onAccent
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 고른 시점을 사람이 읽는 문장으로. 예: "7일 전, 하루 전에 알려드려요"
String describeReminders(List<int> days) {
  if (days.isEmpty) return '알림을 받지 않아요';
  return '${days.map(ReminderOptions.label).join(', ')}에 알려드려요';
}

/// 구독 하나의 알림 설정. 전체 설정을 따르거나, 이 구독만 따로 정한다.
class SubscriptionReminderCard extends ConsumerWidget {
  const SubscriptionReminderCard({super.key, required this.subscription});

  final Subscription subscription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final global = ref.watch(reminderDaysProvider);

    final custom = subscription.reminderDaysBefore;
    final followsGlobal = custom == null;
    final effective = custom ?? global;

    final notifier = ref.read(subscriptionsProvider.notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  effective.isEmpty
                      ? Icons.notifications_off_outlined
                      : Icons.notifications_active_outlined,
                  size: 18,
                  color: theme.textTheme.labelMedium?.color,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text('결제 알림', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            Wrap(
              spacing: AppSpacing.sm,
              children: [
                _ModeChip(
                  label: '전체 설정 따름',
                  active: followsGlobal,
                  onTap: () => notifier.setReminderDays(subscription.id, null),
                ),
                _ModeChip(
                  label: '이 구독만 따로',
                  active: !followsGlobal,
                  // 따로 정하기로 바꿀 때는 지금 적용 중인 값에서 시작한다.
                  // 빈 상태로 시작하면 알림이 갑자기 꺼진 것처럼 보인다.
                  onTap: () =>
                      notifier.setReminderDays(subscription.id, [...global]),
                ),
              ],
            ),

            if (!followsGlobal) ...[
              const SizedBox(height: AppSpacing.lg),
              ReminderDayPicker(
                selected: custom,
                onToggle: (day) {
                  final next = custom.contains(day)
                      ? custom.where((d) => d != day).toList()
                      : [...custom, day];
                  notifier.setReminderDays(subscription.id, next);
                },
              ),
            ],

            const SizedBox(height: AppSpacing.md),
            Text(
              subscription.isActive
                  ? describeReminders(effective)
                  : '해지한 구독이라 알림을 보내지 않아요',
              style: theme.textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: active
              ? AppColors.accent.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: active ? AppColors.accent : theme.dividerColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? AppColors.accent : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
