import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/category_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/money.dart';
import '../../data/models/subscription.dart';
import '../../providers/insight_providers.dart';
import '../../providers/stats_providers.dart';
import '../../providers/usage_providers.dart';
import '../../widgets/krw_amount_text.dart';
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

/// 통계를 어느 기준으로 볼지.
enum _StatsMode {
  /// 지금 매달 나가는 돈.
  monthly('한 달에'),

  /// 시작일부터 지금까지 실제로 낸 돈. 해지한 구독도 포함한다.
  lifetime('지금까지');

  const _StatsMode(this.label);
  final String label;
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  /// 펼쳐놓은 분야. 라벨로 구분한다.
  final _expanded = <String>{};

  _StatsMode _mode = _StatsMode.monthly;

  bool get _isLifetime => _mode == _StatsMode.lifetime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spends = _isLifetime
        ? ref.watch(categoryLifetimeProvider)
        : ref.watch(categorySpendProvider);
    final total = _isLifetime
        ? ref.watch(categoryLifetimeTotalProvider)
        : ref.watch(categoryTotalProvider);

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
                // 지금 뭔가 해볼 수 있는 것부터 보여준다. 숫자를 늘어놓는 것보다
                // "합치면 얼마 아껴요" 한 줄이 실제로 행동을 바꾼다.
                const _InsightSection(),
                _ModeToggle(
                  mode: _mode,
                  onChanged: (mode) => setState(() => _mode = mode),
                ),
                const SizedBox(height: AppSpacing.xl),
                _TotalHeader(
                  total: total,
                  count: _countAll(spends),
                  mode: _mode,
                ),
                const SizedBox(height: AppSpacing.xl),
                _CompositionBar(
                  spends: spends,
                  total: total,
                  lifetime: _isLifetime,
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('분야별', style: theme.textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.md),
                for (final spend in spends)
                  _CategoryRow(
                    spend: spend,
                    total: total,
                    color: CategoryColors.of(spend.category),
                    lifetime: _isLifetime,
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

/// 눈여겨볼 것들. 없으면 자리를 차지하지 않는다.
class _InsightSection extends ConsumerWidget {
  const _InsightSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final insights = ref.watch(insightsProvider);
    final unused = ref.watch(unusedSubscriptionsProvider);
    if (insights.isEmpty && unused.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('눈여겨볼 것', style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.md),
        for (final insight in insights)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _InsightCard(insight: insight),
          ),
        if (unused.isNotEmpty) _UnusedCard(unused: unused),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

/// 폰에서 한동안 안 연 구독들.
///
/// 문구에 주의한다. TV·PC 사용은 잡히지 않으므로 "해지하세요"라고 하면 안 되고
/// **"폰에서 안 열었다"는 사실만** 전한다. 판단은 사용자가 한다.
class _UnusedCard extends StatelessWidget {
  const _UnusedCard({required this.unused});

  final List<({Subscription subscription, int days})> unused;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(
                    Icons.hourglass_empty,
                    size: 18,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    '폰에서 한동안 안 열었어요',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            for (final item in unused)
              InkWell(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SubscriptionDetailScreen(
                      subscriptionId: item.subscription.id,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Row(
                    children: [
                      ServiceIcon.forSubscription(item.subscription, size: 28),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          item.subscription.name,
                          style: theme.textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${item.days}일째',
                        style: theme.textTheme.labelMedium?.merge(
                          AppTheme.numeric,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'TV나 PC로 보는 건 알 수 없어요. 참고만 해주세요.',
              style: theme.textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});

  final Insight insight;

  ({IconData icon, Color color}) get _style => switch (insight.kind) {
    InsightKind.trialEnding => (
      icon: Icons.timer_outlined,
      color: AppColors.accent,
    ),
    InsightKind.duplicate => (
      icon: Icons.copy_all_outlined,
      color: AppColors.negative,
    ),
    InsightKind.priceIncrease => (
      icon: Icons.trending_up,
      color: AppColors.negative,
    ),
    InsightKind.billingCrowded => (
      icon: Icons.event_busy_outlined,
      color: AppColors.accent,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = _style;
    final id = insight.subscriptionId;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: id == null
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SubscriptionDetailScreen(subscriptionId: id),
                ),
              ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: style.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(style.icon, size: 18, color: style.color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      insight.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      insight.body,
                      style: theme.textTheme.labelMedium?.copyWith(height: 1.4),
                    ),
                  ],
                ),
              ),
              if (id != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: theme.textTheme.labelMedium?.color,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 월 지출 / 누적 지출을 오가는 토글.
class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onChanged});

  final _StatsMode mode;
  final ValueChanged<_StatsMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        children: [
          for (final option in _StatsMode.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(option),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: option == mode
                        ? AppColors.accent
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    option == _StatsMode.monthly ? '매달 나가는 돈' : '지금까지 쓴 돈',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: option == mode
                          ? AppColors.onAccent
                          : theme.textTheme.labelMedium?.color,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TotalHeader extends StatelessWidget {
  const _TotalHeader({
    required this.total,
    required this.count,
    required this.mode,
  });

  final Money total;
  final int count;
  final _StatsMode mode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(mode.label, style: theme.textTheme.labelMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(total.format(), style: theme.textTheme.displaySmall),
        const SizedBox(height: AppSpacing.sm),
        Text(
          mode == _StatsMode.monthly
              ? '1년이면 ${(total * 12).format()} · 구독 $count개'
              : '해지한 것까지 $count개에 쓴 돈',
          style: theme.textTheme.labelMedium?.merge(AppTheme.numeric),
        ),
      ],
    );
  }
}

/// 전체 지출을 한 줄로 나눠 보여주는 막대.
class _CompositionBar extends StatelessWidget {
  const _CompositionBar({
    required this.spends,
    required this.total,
    required this.lifetime,
  });

  final List<CategorySpend> spends;
  final Money total;
  final bool lifetime;

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
                flex: (lifetime ? spend.lifetime.minor : spend.monthly.minor)
                    .clamp(1, 1 << 30),
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
    required this.lifetime,
    required this.expanded,
    required this.onTap,
  });

  final CategorySpend spend;
  final Money total;
  final Color color;
  final bool lifetime;
  final bool expanded;
  final VoidCallback onTap;

  Money get _amount => lifetime ? spend.lifetime : spend.monthly;

  int get _percent =>
      total.minor == 0 ? 0 : ((_amount.minor / total.minor) * 100).round();

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
                      _amount.format(),
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
                // 접혀 있어도 어떤 서비스를 쓰는지는 보여준다. 분야 이름과
                // 금액만으로는 "이 안에 뭐가 들었더라"가 안 떠오른다.
                if (!expanded) ...[
                  const SizedBox(height: AppSpacing.md),
                  _IconStrip(subscriptions: spend.subscriptions),
                ],
                if (expanded) ...[
                  const SizedBox(height: AppSpacing.lg),
                  for (final subscription in spend.subscriptions)
                    _SubscriptionLine(
                      subscription: subscription,
                      lifetime: lifetime,
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 분야 카드가 접혀 있을 때 그 안의 서비스를 아이콘으로 늘어놓는 띠.
///
/// 카드를 펼치지 않아도 전체 구독 현황이 한눈에 들어오게 한다.
/// 아이콘이 많으면 넘치지 않게 자르고 "+n" 으로 남은 개수를 알린다.
class _IconStrip extends StatelessWidget {
  const _IconStrip({required this.subscriptions});

  final List<Subscription> subscriptions;

  static const _size = 26.0;
  static const _gap = AppSpacing.sm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // 넘치는 개수를 "+n" 으로 알리려면 그 자리도 남겨둬야 한다.
        final perIcon = _size + _gap;
        final fits = ((constraints.maxWidth + _gap) / perIcon).floor();
        final showAll = subscriptions.length <= fits;
        final visible = showAll ? subscriptions.length : (fits - 1).clamp(0, subscriptions.length);
        final hidden = subscriptions.length - visible;

        return Row(
          children: [
            for (final subscription in subscriptions.take(visible))
              Padding(
                padding: const EdgeInsets.only(right: _gap),
                child: ServiceIcon.forSubscription(subscription, size: _size),
              ),
            if (hidden > 0)
              Text(
                '+$hidden',
                style: theme.textTheme.labelMedium?.merge(AppTheme.numeric),
              ),
          ],
        );
      },
    );
  }
}

class _SubscriptionLine extends StatelessWidget {
  const _SubscriptionLine({
    required this.subscription,
    required this.lifetime,
  });

  final Subscription subscription;
  final bool lifetime;

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
                    subscription.isActive
                        ? '${subscription.cycle.label} · ${formatDuration(subscription.startedAt)}'
                        : '해지함 · ${formatDuration(subscription.startedAt, subscription.canceledAt)}',
                    style: theme.textTheme.labelMedium,
                  ),
                ],
              ),
            ),
            KrwAmountText(
              lifetime ? subscription.totalSpent : subscription.monthlyCost,
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
