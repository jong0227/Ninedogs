import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/money.dart';
import '../../data/models/subscription.dart';
import '../../providers/subscription_providers.dart';
import '../../widgets/service_icon.dart';
import '../detail/subscription_detail_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeSubscriptionsProvider);
    final canceled = ref.watch(canceledSubscriptionsProvider);
    final upcoming = ref.watch(upcomingBillingsProvider).take(3).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Ninedogs')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.sm,
          AppSpacing.screenH,
          AppSpacing.xxl,
        ),
        children: [
          const _SummaryCard(),
          if (upcoming.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            const _SectionTitle('다가오는 결제'),
            const SizedBox(height: AppSpacing.md),
            for (final subscription in upcoming)
              _UpcomingRow(subscription: subscription),
          ],
          const SizedBox(height: AppSpacing.xl),
          _SectionTitle('내 구독', trailing: '${active.length}개'),
          const SizedBox(height: AppSpacing.md),
          if (active.isEmpty)
            const _EmptyState()
          else
            for (final subscription in active)
              _SubscriptionRow(subscription: subscription),
          if (canceled.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            _SectionTitle('해지함', trailing: '${canceled.length}개'),
            const SizedBox(height: AppSpacing.md),
            for (final subscription in canceled)
              _SubscriptionRow(subscription: subscription, dimmed: true),
          ],
        ],
      ),
    );
  }
}

class _SummaryCard extends ConsumerWidget {
  const _SummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final monthly = ref.watch(monthlyTotalProvider);
    final lifetime = ref.watch(lifetimeTotalProvider);
    final count = ref.watch(activeSubscriptionsProvider).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('한 달에', style: theme.textTheme.labelMedium),
            const SizedBox(height: AppSpacing.xs),
            _TotalAmount(totals: monthly, large: true),
            const SizedBox(height: AppSpacing.lg),
            Divider(color: theme.dividerColor, height: 1),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('지금까지 쓴 돈', style: theme.textTheme.labelMedium),
                      const SizedBox(height: AppSpacing.xs),
                      _TotalAmount(totals: lifetime),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('구독 중', style: theme.textTheme.labelMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '$count개',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 통화가 섞여 있으면 금액이 큰 통화를 앞에 크게, 나머지는 작게 덧붙인다.
class _TotalAmount extends StatelessWidget {
  const _TotalAmount({required this.totals, this.large = false});

  final Map<String, Money> totals;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (totals.isEmpty) {
      return Text(
        Money.zero().format(),
        style: large
            ? theme.textTheme.displaySmall
            : theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      );
    }

    final entries = totals.values.toList();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: Text(
            entries.first.format(),
            overflow: TextOverflow.ellipsis,
            style: large
                ? theme.textTheme.displaySmall
                : theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
          ),
        ),
        if (entries.length > 1) ...[
          const SizedBox(width: AppSpacing.sm),
          Text(
            '+ ${entries.skip(1).map((m) => m.format()).join(', ')}',
            style: theme.textTheme.labelMedium,
          ),
        ],
      ],
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.subscription});

  final Subscription subscription;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = subscription.daysUntilNextBilling;
    final next = subscription.nextBillingDate();
    final soon = days != null && days <= 3;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          ServiceIcon(
            name: subscription.name,
            brandColor: Color(subscription.brandColorValue ?? 0xFF6B7079),
            serviceId: subscription.serviceId,
            searchTerm: subscription.name,
            imageUrl: subscription.iconUrl,
            size: 36,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(subscription.name, style: theme.textTheme.bodyMedium),
          ),
          if (next != null)
            Text(formatMonthDay(next), style: theme.textTheme.labelMedium),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: soon
                  ? AppColors.accent.withValues(alpha: 0.16)
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              days == null ? '-' : formatDaysAway(days),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: soon
                    ? AppColors.accent
                    : theme.textTheme.labelMedium?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionRow extends StatelessWidget {
  const _SubscriptionRow({required this.subscription, this.dimmed = false});

  final Subscription subscription;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Opacity(
        opacity: dimmed ? 0.5 : 1,
        child: Material(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    SubscriptionDetailScreen(subscriptionId: subscription.id),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  ServiceIcon(
                    name: subscription.name,
                    brandColor: Color(
                      subscription.brandColorValue ?? 0xFF6B7079,
                    ),
                    serviceId: subscription.serviceId,
                    searchTerm: subscription.name,
                    imageUrl: subscription.iconUrl,
                    size: 44,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subscription.name,
                          style: theme.textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${subscription.cycle.label} · ${formatDuration(subscription.startedAt, subscription.canceledAt)}',
                          style: theme.textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    subscription.currentPrice.format(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: theme.textTheme.headlineSmall),
        if (trailing != null)
          Text(trailing!, style: theme.textTheme.labelMedium),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Center(
        child: Text(
          '아직 등록한 구독이 없어요',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.labelMedium?.color,
          ),
        ),
      ),
    );
  }
}
