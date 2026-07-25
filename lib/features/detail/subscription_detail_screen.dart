import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../data/catalog/service_catalog.dart';
import '../../data/models/money.dart';
import '../../data/models/subscription.dart';
import '../../providers/subscription_providers.dart';
import '../../widgets/krw_amount_text.dart';
import '../../widgets/service_icon.dart';
import '../edit/period_editor.dart';
import '../edit/price_history_editor.dart';
import '../edit/quick_edits.dart';
import '../edit/resubscribe_sheet.dart';
import '../edit/subscription_form_screen.dart';
import '../notifications/reminder_picker.dart';
import '../vault/credential_section.dart';
import 'billing_lookup_sheet.dart';

class SubscriptionDetailScreen extends ConsumerWidget {
  const SubscriptionDetailScreen({super.key, required this.subscriptionId});

  final String subscriptionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(subscriptionByIdProvider(subscriptionId));

    // 삭제 직후엔 잠깐 null 이 된다. 빈 화면을 잠시 보여주고 pop 한다.
    if (subscription == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final theme = Theme.of(context);
    final charges = subscription.billingDatesUntil(DateTime.now()).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(subscription.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () => _showActions(context, ref, subscription),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.sm,
          AppSpacing.screenH,
          AppSpacing.xxl,
        ),
        children: [
          Row(
            children: [
              ServiceIcon.forSubscription(subscription, size: 68),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 금액을 눌러 바로 고친다. 편집 화면까지 가지 않아도 된다.
                    InkWell(
                      onTap: () =>
                          showPriceEditor(context, ref, subscription),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            // 달러로 결제해도 원화로 얼마인지가 크게 보인다.
                            // 실제 청구 통화는 아래에 작게 따로 남긴다.
                            child: KrwAmountText(
                              subscription.currentPrice,
                              style: theme.textTheme.displaySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          const EditAffordance(size: 18),
                        ],
                      ),
                    ),
                    Text(
                      '${subscription.cycle.label}'
                      '${subscription.memo == null ? '' : ' · ${subscription.memo}'}',
                      style: theme.textTheme.labelMedium,
                    ),
                    if (subscription.currency != Money.krw)
                      Text(
                        '실제 결제 ${subscription.currentPrice.format()}',
                        style: theme.textTheme.labelMedium?.merge(
                          AppTheme.numeric,
                        ),
                      ),
                    // 0원이면 왜 0원인지 알려준다. 그냥 ₩0 만 떠 있으면
                    // 잘못 입력된 줄 안다.
                    if (subscription.currentPrice.isZero)
                      _IncludedBadge(subscription: subscription),
                    // 월 7,900원은 싸 보이지만 1년이면 9만원이 넘는다.
                    // 연 환산을 보여주면 유지할지 판단이 달라진다.
                    if (!subscription.currentPrice.isZero)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '1년이면 ',
                              style: theme.textTheme.labelMedium,
                            ),
                            KrwAmountText(
                              subscription.monthlyCost * 12,
                              style: theme.textTheme.labelMedium?.merge(
                                AppTheme.numeric,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          // 무료 체험은 놓치면 바로 돈이 나간다. 가장 먼저 눈에 띄어야 한다.
          if (subscription.isInTrial) ...[
            const SizedBox(height: AppSpacing.lg),
            _TrialBanner(subscription: subscription),
          ],
          const SizedBox(height: AppSpacing.xl),

          // 누적 지출 — 이 앱의 핵심 숫자
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('이 서비스에 쓴 돈', style: theme.textTheme.labelMedium),
                  const SizedBox(height: AppSpacing.xs),
                  KrwAmountText(
                    subscription.totalSpent,
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '$charges번 결제 · ${formatDuration(subscription.startedAt, subscription.canceledAt)}',
                    style: theme.textTheme.labelMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // 값을 눌러 그 자리에서 고친다
          EditableInfoTile(
            label: '구독 시작',
            value: formatDate(subscription.startedAt),
            onTap: () => showStartDateEditor(context, ref, subscription),
          ),
          // 가입일을 기억하는 사람은 거의 없다. 알아내는 방법을 알려준다.
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => showBillingLookupSheet(context, subscription),
              icon: const Icon(Icons.help_outline, size: 16),
              label: const Text('가입일이 기억나지 않나요?'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
          EditableInfoTile(
            label: '카드 결제일 기준',
            value: subscription.billingAnchor == null
                ? '매달 ${subscription.startedAt.day}일 (시작일과 같음)'
                : '매달 ${subscription.billingAnchor!.day}일',
            onTap: () => showBillingAnchorEditor(context, ref, subscription),
          ),
          EditableInfoTile(
            label: '다음 결제일',
            value: switch (subscription.nextBillingDate()) {
              final date? =>
                '${formatDate(date)}'
                    ' (${formatDaysAway(subscription.daysUntilNextBilling ?? 0)})',
              null => '해지함',
            },
          ),
          EditableInfoTile(
            label: '이용 가능 기한',
            value: switch (subscription.accessValidUntil) {
              final date? => formatDate(date),
              null => '-',
            },
          ),
          EditableInfoTile(
            label: '결제 수단',
            value: subscription.paymentMethod ?? '미등록',
            onTap: () => showPaymentMethodEditor(context, ref, subscription),
          ),
          if (subscription.canceledAt != null)
            EditableInfoTile(
              label: '해지일',
              value: formatDate(subscription.canceledAt!),
            ),

          // 끊었다 다시 구독한 기록. 직접 넣고 고치고 지울 수 있어야 해서
          // 구간이 하나뿐일 때도 띄운다.
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('구독 이력', style: theme.textTheme.headlineSmall),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (subscription.isActive)
                    TextButton.icon(
                      onPressed: () => ref
                          .read(subscriptionsProvider.notifier)
                          .cancel(subscription.id),
                      icon: const Icon(
                        Icons.pause_circle_outline,
                        size: 18,
                      ),
                      label: const Text('해지 처리'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.negative,
                      ),
                    )
                  else
                    TextButton.icon(
                      onPressed: () =>
                          showResubscribeSheet(context, ref, subscription),
                      icon: const Icon(
                        Icons.play_circle_outline,
                        size: 18,
                      ),
                      label: const Text('다시 구독'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.accent,
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    tooltip: '이력 추가',
                    color: AppColors.accent,
                    onPressed: () =>
                        showPeriodEditor(context, ref, subscription),
                  ),
                ],
              ),
            ],
          ),
          _PeriodHistory(subscription: subscription),

          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('가격 변동', style: theme.textTheme.headlineSmall),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 20),
                tooltip: '이전 가격 추가',
                color: AppColors.accent,
                onPressed: () =>
                    showPriceHistoryEditor(context, ref, subscription),
              ),
            ],
          ),
          if (subscription.priceChanges.isEmpty)
            Text(
              '아직 바뀐 적 없어요. 예전엔 다른 금액이었다면 위 + 로 추가하세요.',
              style: theme.textTheme.labelMedium,
            )
          else
            _PriceHistory(subscription: subscription),

          const SizedBox(height: AppSpacing.xl),
          SubscriptionReminderCard(subscription: subscription),

          const SizedBox(height: AppSpacing.md),
          CredentialSection(subscriptionId: subscription.id),
        ],
      ),
    );
  }

  void _showActions(
    BuildContext context,
    WidgetRef ref,
    Subscription subscription,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('편집'),
              subtitle: const Text('금액, 주기, 결제일, 결제 수단'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        SubscriptionFormScreen(existing: subscription),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.negative),
              title: const Text(
                '완전히 삭제',
                style: TextStyle(color: AppColors.negative),
              ),
              subtitle: const Text('누적 지출 기록까지 사라져요'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final confirmed = await _confirmDelete(context, subscription);
                if (!confirmed || !context.mounted) return;
                await ref
                    .read(subscriptionsProvider.notifier)
                    .remove(subscription.id);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(
    BuildContext context,
    Subscription subscription,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${subscription.name}을(를) 삭제할까요?'),
        content: const Text('지금까지 쌓인 결제 기록과 누적 지출도 함께 사라집니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              '삭제',
              style: TextStyle(color: AppColors.negative),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

/// 무료 체험이 언제 끝나고 그때 얼마가 빠져나가는지 알리는 띠.
class _TrialBanner extends StatelessWidget {
  const _TrialBanner({required this.subscription});

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

/// 0원으로 등록된 구독에 "어디에 포함되는지" 알려주는 배지.
///
/// 카탈로그에 상위 상품이 적혀 있으면 그 이름을 쓰고, 없으면 일반 문구로 둔다.
/// (직접 추가한 서비스도 0원으로 넣을 수 있다)
class _IncludedBadge extends StatelessWidget {
  const _IncludedBadge({required this.subscription});

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
class _PeriodHistory extends ConsumerWidget {
  const _PeriodHistory({required this.subscription});

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
            child: _PeriodRow(
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

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({
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

class _PriceHistory extends ConsumerWidget {
  const _PriceHistory({required this.subscription});

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
                    _ChangeBadge(
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

class _ChangeBadge extends StatelessWidget {
  const _ChangeBadge({required this.delta});

  final int delta;

  @override
  Widget build(BuildContext context) {
    if (delta == 0) return const SizedBox.shrink();
    final increased = delta > 0;
    final color = increased ? AppColors.negative : AppColors.positive;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
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
