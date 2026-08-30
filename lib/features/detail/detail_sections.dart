import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/money.dart';
import '../../data/models/subscription.dart';
import '../../widgets/krw_amount_text.dart';
import '../edit/period_editor.dart';
import '../edit/price_history_editor.dart';
import '../../data/catalog/service_catalog.dart';

// 구독 상세 화면의 각 구획.
///
// 화면 본문은 무엇을 어떤 순서로 보여줄지만 정하고, 각 구획이
// 어떻게 생겼는지는 여기서 안다.

class TrialBanner extends StatelessWidget {
  const TrialBanner({super.key, required this.subscription});

  final Subscription subscription;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = subscription.daysUntilTrialEnds ?? 0;
    final end = subscription.trialEndsAt!;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.timer_outlined, size: 20, color: AppColors.accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  days == 0 ? '오늘 무료 체험이 끝나요' : '무료 체험 $days일 남음',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatDate(end)}부터 ${subscription.currentPrice.format()} 결제돼요',
                  style: theme.textTheme.labelMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 0원으로 등록된 구독에 "어디에 포함되는지" 알려주는 배지.
///
// 카탈로그에 상위 상품이 적혀 있으면 그 이름을 쓰고, 없으면 일반 문구로 둔다.
// (직접 추가한 서비스도 0원으로 넣을 수 있다)
class IncludedBadge extends StatelessWidget {
  const IncludedBadge({super.key, required this.subscription});

  final Subscription subscription;

  @override
  Widget build(BuildContext context) {
    final service = ServiceCatalog.byId(subscription.serviceId ?? '');
    final parent = service == null ? null : ServiceCatalog.parentOf(service);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 3,
        ),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.card_giftcard_outlined,
              size: 12,
              color: AppColors.accent,
            ),
            const SizedBox(width: 4),
            Text(
              parent == null ? '추가 결제 없음' : '${parent.name}에 포함',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 구독했다 끊은 구간들. 언제부터 언제까지, 그 사이 얼마를 냈는지.
/// 눌러서 고치거나 지울 수 있다.
class PeriodHistory extends ConsumerWidget {
  const PeriodHistory({super.key, required this.subscription});

  final Subscription subscription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periods = subscription.allPeriods;

    return Column(
      children: [
        // 최근 구간이 위로 오게 뒤집는다.
        for (var i = periods.length - 1; i >= 0; i--)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: PeriodRow(
              subscription: subscription,
              startedAt: periods[i].startedAt,
              endedAt: periods[i].endedAt,
              index: i + 1,
              onTap: () => showPeriodEditor(
                context,
                ref,
                subscription,
                existing: periods[i],
              ),
            ),
          ),
      ],
    );
  }
}

class PeriodRow extends StatelessWidget {
  const PeriodRow({
    super.key,
    required this.subscription,
    required this.startedAt,
    required this.endedAt,
    required this.index,
    required this.onTap,
  });

  final Subscription subscription;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ongoing = endedAt == null;

    // 이 구간에만 걸린 결제를 골라 합산한다. 구간마다 요금이 달랐어도
    // priceAt() 이 그때 값을 집어주므로 그대로 반영된다.
    final until = endedAt ?? DateTime.now();
    final dates = subscription
        .billingDatesUntil(until)
        .where((d) => !d.isBefore(startedAt) && !d.isAfter(until))
        .toList();

    var spent = Money.zero(subscription.currency);
    for (final date in dates) {
      spent += subscription.priceAt(date);
    }

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: ongoing
                ? Border.all(color: AppColors.accent.withValues(alpha: 0.5))
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: ongoing
                      ? AppColors.accent
                      : theme.textTheme.labelMedium?.color?.withValues(
                          alpha: 0.25,
                        ),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$index',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ongoing
                        ? AppColors.onAccent
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ongoing
                          ? '${formatDate(startedAt)} ~ 지금'
                          : '${formatDate(startedAt)} ~ ${formatDate(endedAt!)}',
                      style: theme.textTheme.bodyMedium?.merge(
                        AppTheme.numeric,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatDuration(startedAt, endedAt)} · ${dates.length}번 결제',
                      style: theme.textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              KrwAmountText(
                spent,
                style: theme.textTheme.bodyMedium
                    ?.merge(AppTheme.numeric)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: theme.textTheme.labelMedium?.color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PriceHistory extends ConsumerWidget {
  const PriceHistory({super.key, required this.subscription});

  final Subscription subscription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final history = subscription.priceHistory;

    return Column(
      children: [
        for (var i = history.length - 1; i >= 0; i--)
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            // 눌러서 그 시점의 금액·날짜를 고치거나 잘못 넣은 항목을 지운다.
            onTap: () => showPriceHistoryEditor(
              context,
              ref,
              subscription,
              existing: history[i],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Text(
                    formatDate(history[i].effectiveFrom),
                    style: theme.textTheme.labelMedium,
                  ),
                  const Spacer(),
                  Text(
                    history[i].amount.format(),
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (i > 0) ...[
                    const SizedBox(width: AppSpacing.sm),
                    ChangeBadge(
                      delta:
                          history[i].amount.minor - history[i - 1].amount.minor,
                    ),
                  ],
                  const SizedBox(width: AppSpacing.sm),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: theme.textTheme.labelMedium?.color,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class ChangeBadge extends StatelessWidget {
  const ChangeBadge({super.key, required this.delta});

  final int delta;

  @override
  Widget build(BuildContext context) {
    if (delta == 0) return const SizedBox.shrink();
    final increased = delta > 0;
    final color = increased ? AppColors.negative : AppColors.positive;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        increased ? '인상' : '인하',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
