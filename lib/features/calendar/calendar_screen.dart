import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/category_colors.dart';
import '../../data/models/money.dart';
import '../../data/models/subscription.dart';
import '../../providers/app_providers.dart';
import '../../providers/stats_providers.dart';
import '../../providers/subscription_providers.dart';
import '../../widgets/krw_amount_text.dart';
import '../../widgets/service_icon.dart';
import '../detail/subscription_detail_screen.dart';

/// 결제일을 달력으로 보는 화면.
///
/// 목록으로는 "이번 달 언제 얼마씩 빠지는지"가 안 보인다. 달력에 찍어두면
/// 결제가 몰린 주가 한눈에 들어온다.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _month = _firstDayOf(DateTime.now());
  DateTime? _selected;

  static DateTime _firstDayOf(DateTime date) => DateTime(date.year, date.month);

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _selected = null;
    });
  }

  /// 이 달에 결제가 걸린 날짜별 구독 목록.
  Map<int, List<Subscription>> _billingByDay(List<Subscription> subscriptions) {
    final lastDay = DateTime(_month.year, _month.month + 1, 0);
    final result = <int, List<Subscription>>{};

    for (final subscription in subscriptions) {
      final dates = subscription.billingDatesBetween(_month, lastDay);
      for (final date in dates) {
        result.putIfAbsent(date.day, () => []).add(subscription);
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final subscriptions = ref.watch(activeSubscriptionsProvider);
    final byDay = _billingByDay(subscriptions);

    final rate = ref.watch(exchangeRateProvider).value;
    final monthTotal = _sumOf(byDay.values.expand((list) => list), rate);
    final selectedDay = _selected?.day;

    return Scaffold(
      appBar: AppBar(title: const Text('결제 캘린더')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.sm,
          AppSpacing.screenH,
          AppSpacing.xxl,
        ),
        children: [
          _MonthHeader(
            month: _month,
            total: monthTotal,
            onPrevious: () => _shiftMonth(-1),
            onNext: () => _shiftMonth(1),
          ),
          const SizedBox(height: AppSpacing.md),
          _MonthGrid(
            month: _month,
            byDay: byDay,
            selectedDay: selectedDay,
            onSelectDay: (day) => setState(() {
              final tapped = DateTime(_month.year, _month.month, day);
              _selected = _selected?.day == day ? null : tapped;
            }),
          ),
          const SizedBox(height: AppSpacing.lg),

          if (selectedDay != null)
            _DayDetail(
              date: _selected!,
              subscriptions: byDay[selectedDay] ?? const [],
            )
          else
            _MonthList(byDay: byDay, month: _month),
        ],
      ),
    );
  }

  /// 예전엔 통화가 섞이면 원화만 더해서, 달러 구독 하나가 있으면 이 달
  /// 합계에서 그 결제 금액이 통째로 빠졌다. 환율로 환산해서 전부 더한다.
  static Money _sumOf(Iterable<Subscription> subscriptions, double? rate) {
    var total = Money.zero();
    for (final subscription in subscriptions) {
      final converted = subscription.currency == Money.krw
          ? subscription.currentPrice
          : (rate == null ? null : subscription.currentPrice.toKrw(rate));
      if (converted != null) total += converted;
    }
    return total;
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.total,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final Money total;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('yyyy년 M월', 'ko_KR').format(month),
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 2),
              Text(
                total.isZero ? '결제 예정 없음' : '이 달 ${total.format()}',
                style: theme.textTheme.labelMedium?.merge(AppTheme.numeric),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
          tooltip: '이전 달',
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
          tooltip: '다음 달',
        ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.byDay,
    required this.selectedDay,
    required this.onSelectDay,
  });

  final DateTime month;
  final Map<int, List<Subscription>> byDay;
  final int? selectedDay;
  final ValueChanged<int> onSelectDay;

  static const _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // DateTime 의 weekday 는 월=1..일=7. 일요일 시작 달력이라 7을 0으로 옮긴다.
    final leading = month.weekday % 7;
    final today = DateTime.now();
    final isThisMonth = today.year == month.year && today.month == month.month;

    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Center(
                  child: Text(
                    _weekdays[i],
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: i == 0
                          ? AppColors.negative.withValues(alpha: 0.8)
                          : theme.textTheme.labelMedium?.color,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            // 예전엔 세로로 길쭉해서(0.82) 그리드 하나가 화면 절반을 먹었다.
            // 요일 한 줄 + 결제일 점만 찍으면 되니 정사각형에 가깝게 줄인다.
            childAspectRatio: 1.15,
          ),
          itemCount: leading + daysInMonth,
          itemBuilder: (context, index) {
            if (index < leading) return const SizedBox.shrink();

            final day = index - leading + 1;
            final entries = byDay[day] ?? const <Subscription>[];

            return _DayCell(
              day: day,
              subscriptions: entries,
              selected: selectedDay == day,
              isToday: isThisMonth && today.day == day,
              onTap: () => onSelectDay(day),
            );
          },
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.subscriptions,
    required this.selected,
    required this.isToday,
    required this.onTap,
  });

  final int day;
  final List<Subscription> subscriptions;
  final bool selected;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: subscriptions.isEmpty ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? AppColors.accent : Colors.transparent,
              border: isToday && !selected
                  ? Border.all(color: theme.dividerColor)
                  : null,
            ),
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 13,
                fontWeight: subscriptions.isEmpty
                    ? FontWeight.w400
                    : FontWeight.w700,
                color: selected
                    ? AppColors.onAccent
                    : subscriptions.isEmpty
                    ? theme.textTheme.labelMedium?.color
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 2),
          // 결제가 있는 날만 분야 색 점을 찍는다. 세 개까지만 보여주고
          // 더 있으면 마지막 점을 회색으로 둬서 더 있다는 걸 알린다.
          SizedBox(
            height: 4,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final subscription in subscriptions.take(3))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: CategoryColors.of(categoryOf(subscription)),
                      ),
                    ),
                  ),
                if (subscriptions.length > 3)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.textTheme.labelMedium?.color,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 날짜를 골랐을 때 그날 결제되는 구독들.
class _DayDetail extends StatelessWidget {
  const _DayDetail({required this.date, required this.subscriptions});

  final DateTime date;
  final List<Subscription> subscriptions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat('M월 d일 (E)', 'ko_KR').format(date),
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.md),
        for (final subscription in subscriptions)
          _BillingRow(subscription: subscription),
      ],
    );
  }
}

/// 아무 날짜도 고르지 않았을 때, 이 달 결제를 날짜순으로 쭉 보여준다.
///
/// 예전엔 날짜마다 "N일" 제목 줄을 따로 두고 그 아래 결제를 늘어놓아서,
/// 구독이 많으면 줄 수가 배로 늘어 스크롤이 길어졌다. 날짜를 각 행 안에
/// 작은 배지로 넣어 한 줄씩만 차지하게 했다.
class _MonthList extends StatelessWidget {
  const _MonthList({required this.byDay, required this.month});

  final Map<int, List<Subscription>> byDay;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = byDay.keys.toList()..sort();

    if (days.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: Center(
          child: Text(
            '이 달에는 결제 예정이 없어요',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.labelMedium?.color,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('이 달 결제', style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        for (final day in days)
          for (final subscription in byDay[day]!)
            _BillingRow(subscription: subscription, day: day),
      ],
    );
  }
}

class _BillingRow extends StatelessWidget {
  const _BillingRow({required this.subscription, this.day});

  final Subscription subscription;

  /// 날짜 배지로 보여줄 일(day). 이미 날짜 헤더가 있는 [_DayDetail] 에서는
  /// 안 준다.
  final int? day;

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
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  SubscriptionDetailScreen(subscriptionId: subscription.id),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                if (day != null) ...[
                  SizedBox(
                    width: 26,
                    child: Text(
                      '$day일',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                ServiceIcon.forSubscription(subscription, size: 32),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    subscription.name,
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                KrwAmountText(
                  subscription.currentPrice,
                  style: theme.textTheme.titleMedium?.merge(AppTheme.numeric),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
