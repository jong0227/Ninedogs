import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/money.dart';
import '../../data/models/subscription.dart';
import '../../providers/app_providers.dart';
import '../../providers/subscription_providers.dart';
import '../../widgets/krw_amount_text.dart';
import '../../widgets/ninedogs_app_bar.dart';
import '../../widgets/service_icon.dart';
import '../add/service_picker_screen.dart';
import '../detail/subscription_detail_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeSubscriptionsProvider);
    final canceled = ref.watch(canceledSubscriptionsProvider);
    final upcoming = ref.watch(upcomingBillingsProvider).take(3).toList();

    return Scaffold(
      appBar: const NinedogsAppBar(section: '내 구독'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ServicePickerScreen()),
        ),
        backgroundColor: AppColors.accent,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text('구독 추가'),
      ),
      body: ListView(
        // 하단 여백은 떠 있는 '구독 추가' 버튼에 가리지 않을 만큼 둔다.
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.sm,
          AppSpacing.screenH,
          96,
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
    final monthlyKrw = ref.watch(monthlyTotalKrwProvider);
    final lifetimeKrw = ref.watch(lifetimeTotalKrwProvider);
    final count = ref.watch(activeSubscriptionsProvider).length;

    // 카드를 누르면 통계 탭으로 넘어간다. 요약 숫자를 보고 자세히 보고
    // 싶어 누르는 게 자연스러운데, 예전엔 아무 반응이 없었다.
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => ref.read(selectedShellTabProvider.notifier).select(2),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('한 달에', style: theme.textTheme.labelMedium),
                  const Spacer(),
                  Icon(
                    Icons.bar_chart_rounded,
                    size: 18,
                    color: theme.textTheme.labelMedium?.color,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              _TotalAmount(totals: monthly, krwTotal: monthlyKrw, large: true),
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
                        _TotalAmount(totals: lifetime, krwTotal: lifetimeKrw),
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
      ),
    );
  }
}

/// 달러 구독이 섞여 있어도 환율로 환산한 원화 한 숫자로 보여준다.
/// 환율을 아직 못 받아왔으면(krwTotal 이 null) 통화별로 나눠 보여준다.
class _TotalAmount extends StatelessWidget {
  const _TotalAmount({required this.totals, this.krwTotal, this.large = false});

  final Map<String, Money> totals;
  final Money? krwTotal;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = large
        ? theme.textTheme.displaySmall
        : theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);

    final combined = krwTotal;
    if (combined != null) {
      return Text(combined.format(), style: style);
    }

    if (totals.isEmpty) {
      return Text(Money.zero().format(), style: style);
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

    // 목록의 다른 구독과 마찬가지로 눌러서 상세로 들어간다.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                SubscriptionDetailScreen(subscriptionId: subscription.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
            horizontal: AppSpacing.xs,
          ),
          child: Row(
            children: [
              ServiceIcon.forSubscription(subscription, size: 36),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  subscription.name,
                  style: theme.textTheme.bodyMedium,
                ),
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
        ),
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
                  ServiceIcon.forSubscription(subscription, size: 44),
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
                  KrwAmountText(
                    subscription.currentPrice,
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
