import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/subscription.dart';
import '../../providers/subscription_providers.dart';
import '../../widgets/service_icon.dart';
import '../edit/subscription_form_screen.dart';

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
              ServiceIcon(
                name: subscription.name,
                brandColor: Color(subscription.brandColorValue ?? 0xFF6B7079),
                serviceId: subscription.serviceId,
                searchTerm: subscription.name,
                imageUrl: subscription.iconUrl,
                size: 64,
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subscription.currentPrice.format(),
                      style: theme.textTheme.displaySmall,
                    ),
                    Text(
                      '${subscription.cycle.label}'
                      '${subscription.memo == null ? '' : ' · ${subscription.memo}'}',
                      style: theme.textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
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
                  Text(
                    subscription.totalSpent.format(),
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

          _InfoTile(label: '구독 시작', value: formatDate(subscription.startedAt)),
          _InfoTile(
            label: '다음 결제일',
            value: switch (subscription.nextBillingDate()) {
              final date? =>
                '${formatDate(date)}'
                    ' (${formatDaysAway(subscription.daysUntilNextBilling ?? 0)})',
              null => '해지함',
            },
          ),
          _InfoTile(
            label: '이용 가능 기한',
            value: switch (subscription.accessValidUntil) {
              final date? => formatDate(date),
              null => '-',
            },
          ),
          _InfoTile(label: '결제 수단', value: subscription.paymentMethod ?? '미등록'),
          if (subscription.canceledAt != null)
            _InfoTile(
              label: '해지일',
              value: formatDate(subscription.canceledAt!),
            ),

          if (subscription.priceChanges.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            Text('가격 변동', style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.md),
            _PriceHistory(subscription: subscription),
          ],

          const SizedBox(height: AppSpacing.xl),
          const _CredentialsPlaceholder(),
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
            if (subscription.isActive)
              ListTile(
                leading: const Icon(Icons.pause_circle_outline),
                title: const Text('해지 처리'),
                subtitle: const Text('기록은 남고 월 합계에서만 빠져요'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  ref
                      .read(subscriptionsProvider.notifier)
                      .cancel(subscription.id);
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

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _PriceHistory extends StatelessWidget {
  const _PriceHistory({required this.subscription});

  final Subscription subscription;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final history = subscription.priceHistory;

    return Column(
      children: [
        for (var i = history.length - 1; i >= 0; i--)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
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
                    delta: history[i].amount.minor - history[i - 1].amount.minor,
                  ),
                ],
              ],
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

/// 계정 정보(아이디/비밀번호)는 암호화 설계를 마친 뒤에 붙인다.
class _CredentialsPlaceholder extends StatelessWidget {
  const _CredentialsPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Icon(Icons.lock_outline, color: theme.textTheme.labelMedium?.color),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('계정 정보', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text('암호화 저장 기능 준비 중', style: theme.textTheme.labelMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
