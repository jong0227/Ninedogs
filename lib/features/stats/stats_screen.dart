import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formatters.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/category_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/money.dart';
import '../../data/models/subscription.dart';
import '../../providers/stats_providers.dart';
import '../../widgets/service_icon.dart';
import '../detail/subscription_detail_screen.dart';

/// 어느 분야에 얼마나 쓰는지 보여주는 화면.
///
/// 색은 빨강 하나의 투명도만 바꿔서 쓴다. 분야마다 다른 색을 쓰면
/// 화면이 알록달록해지고, 순서(많이 쓰는 순)도 색으로 읽히지 않는다.
class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  /// 펼쳐놓은 분야. 라벨로 구분한다.
  final _expanded = <String>{};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spends = ref.watch(categorySpendProvider);
    final total = ref.watch(categoryTotalProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('구독 분석')),
      body: spends.isEmpty
          ? const _EmptyStats()
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.sm,
                AppSpacing.screenH,
                AppSpacing.xxl,
              ),
              children: [
                _TotalHeader(total: total, count: _countAll(spends)),
                const SizedBox(height: AppSpacing.xl),
                _CompositionBar(spends: spends, total: total),
                const SizedBox(height: AppSpacing.xl),
                Text('분야별', style: theme.textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.md),
                for (final spend in spends)
                  _CategoryRow(
                    spend: spend,
                    total: total,
                    color: CategoryColors.of(spend.category),
                    expanded: _expanded.contains(spend.label),
                    onTap: () => setState(() {
                      if (!_expanded.remove(spend.label)) {
                        _expanded.add(spend.label);
                      }
                    }),
                  ),
              ],
            ),
    );
  }

  static int _countAll(List<CategorySpend> spends) =>
      spends.fold(0, (sum, spend) => sum + spend.count);
}

class _TotalHeader extends StatelessWidget {
  const _TotalHeader({required this.total, required this.count});

  final Money total;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('한 달에', style: theme.textTheme.labelMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(total.format(), style: theme.textTheme.displaySmall),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '1년이면 ${(total * 12).format()} · 구독 $count개',
          style: theme.textTheme.labelMedium?.merge(AppTheme.numeric),
        ),
      ],
    );
  }
}

/// 전체 지출을 한 줄로 나눠 보여주는 막대.
class _CompositionBar extends StatelessWidget {
  const _CompositionBar({required this.spends, required this.total});

  final List<CategorySpend> spends;
  final Money total;

  @override
  Widget build(BuildContext context) {
    if (total.minor == 0) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: SizedBox(
        height: 10,
        child: Row(
          children: [
            for (final spend in spends)
              Expanded(
                // flex 는 정수만 받으므로 최소 1을 보장한다.
                flex: spend.monthly.minor.clamp(1, 1 << 30),
                child: Container(color: CategoryColors.of(spend.category)),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.spend,
    required this.total,
    required this.color,
    required this.expanded,
    required this.onTap,
  });

  final CategorySpend spend;
  final Money total;
  final Color color;
  final bool expanded;
  final VoidCallback onTap;

  int get _percent => total.minor == 0
      ? 0
      : ((spend.monthly.minor / total.minor) * 100).round();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        spend.label,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      '$_percent%',
                      style: theme.textTheme.labelMedium?.merge(
                        AppTheme.numeric,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      spend.monthly.format(),
                      style: theme.textTheme.titleMedium?.merge(
                        AppTheme.numeric,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 160),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        size: 18,
                        color: theme.textTheme.labelMedium?.color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                // 분야가 차지하는 비중을 막대로도 보여준다
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: _percent / 100,
                    minHeight: 4,
                    backgroundColor: theme.dividerColor,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                if (expanded) ...[
                  const SizedBox(height: AppSpacing.lg),
                  for (final subscription in spend.subscriptions)
                    _SubscriptionLine(subscription: subscription),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubscriptionLine extends StatelessWidget {
  const _SubscriptionLine({required this.subscription});

  final Subscription subscription;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              SubscriptionDetailScreen(subscriptionId: subscription.id),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            ServiceIcon.forSubscription(subscription, size: 32),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subscription.name,
                    style: theme.textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${subscription.cycle.label} · ${formatDuration(subscription.startedAt)}',
                    style: theme.textTheme.labelMedium,
                  ),
                ],
              ),
            ),
            Text(
              subscription.monthlyCost.format(),
              style: theme.textTheme.bodyMedium?.merge(AppTheme.numeric),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyStats extends StatelessWidget {
  const _EmptyStats();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Text(
          '구독을 등록하면 분야별로 얼마나 쓰는지 보여드릴게요',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.labelMedium?.color,
          ),
        ),
      ),
    );
  }
}
