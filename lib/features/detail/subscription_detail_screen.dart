import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'detail_sections.dart';
import '../../core/format/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/money.dart';
import '../../data/models/subscription.dart';
import '../../providers/subscription_providers.dart';
import '../../widgets/krw_amount_text.dart';
import '../../widgets/service_icon.dart';
import '../edit/cancel_or_change_sheet.dart';
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
                      onTap: () => showPriceEditor(context, ref, subscription),
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
                      IncludedBadge(subscription: subscription),
                    // 월 7,900원은 싸 보이지만 1년이면 9만원이 넘는다.
                    // 연 환산을 보여주면 유지할지 판단이 달라진다.
                    if (!subscription.currentPrice.isZero)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('1년이면 ', style: theme.textTheme.labelMedium),
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
            TrialBanner(subscription: subscription),
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
              // 예전엔 onTap 이 없어서, 다른 줄과 똑같이 생겼는데 눌러도
              // 아무 일이 없었다. 날짜를 잘못 넣으면 고칠 길이 없었다.
              onTap: () => showCanceledAtEditor(context, ref, subscription),
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
                      // 바로 해지하지 않고 먼저 묻는다. 요금제만 바꾼 사람이
                      // 여기를 눌러 구독이 끊긴 것으로 기록되면, 이후 결제가
                      // 통계에서 통째로 빠진다.
                      onPressed: () =>
                          showCancelOrChangeSheet(context, ref, subscription),
                      icon: const Icon(Icons.more_horiz, size: 18),
                      label: const Text('해지·변경'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.negative,
                      ),
                    )
                  else
                    TextButton.icon(
                      onPressed: () =>
                          showResubscribeSheet(context, ref, subscription),
                      icon: const Icon(Icons.play_circle_outline, size: 18),
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
          PeriodHistory(subscription: subscription),

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
            PriceHistory(subscription: subscription),

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
              leading: const Icon(
                Icons.delete_outline,
                color: AppColors.negative,
              ),
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
