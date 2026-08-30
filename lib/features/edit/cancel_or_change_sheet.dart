import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/catalog/catalog_service.dart';
import '../../data/catalog/service_catalog.dart';
import '../../data/models/billing_cycle.dart';
import '../../data/models/money.dart';
import '../../data/models/subscription.dart';
import '../../providers/subscription_providers.dart';
import '../../widgets/app_date_picker.dart';
import 'quick_edits.dart';

/// 구독을 그만두는 건지 요금제만 바꾼 건지 먼저 묻는다.
///
/// 예전엔 '해지 처리' 버튼 하나가 누르는 즉시 **오늘 날짜로** 해지를 확정했다.
/// 두 가지가 문제였다.
/// - 해지한 날과 앱에 기록하는 날이 같으리란 법이 없다. 며칠 지나서 넣는 일이
///   흔한데 날짜를 고를 수도, 나중에 고칠 수도 없었다.
/// - 요금제만 바꾼 사람도 마땅한 자리가 없어 이 버튼을 눌렀다. 그러면 구독이
///   끊긴 것으로 기록돼 이후 결제가 통계에서 통째로 빠진다.
Future<void> showCancelOrChangeSheet(
  BuildContext context,
  WidgetRef ref,
  Subscription subscription,
) async {
  final choice = await showModalBottomSheet<_Choice>(
    context: context,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('해지 또는 변경', style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${subscription.name}에 무슨 일이 있었나요?',
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              SheetAction(
                icon: Icons.pause_circle_outline,
                title: '해지했어요',
                body: '언제 해지했는지 고를 수 있어요',
                onTap: () => Navigator.pop(sheetContext, _Choice.cancel),
              ),
              const SizedBox(height: AppSpacing.sm),
              SheetAction(
                icon: Icons.swap_horiz,
                title: '요금제를 바꿨어요',
                body: '구독은 그대로 두고 금액·주기만 바꿔요',
                onTap: () => Navigator.pop(sheetContext, _Choice.plan),
              ),
            ],
          ),
        ),
      );
    },
  );

  if (choice == null || !context.mounted) return;

  switch (choice) {
    case _Choice.cancel:
      await _cancelWithDate(context, ref, subscription);
    case _Choice.plan:
      await showPlanChangeSheet(context, ref, subscription);
  }
}

enum _Choice { cancel, plan }

Future<void> _cancelWithDate(
  BuildContext context,
  WidgetRef ref,
  Subscription subscription,
) async {
  final picked = await pickDate(
    context,
    initialDate: DateTime.now(),
    // 시작일보다 앞서 해지할 수는 없다.
    firstDate: subscription.startedAt,
    lastDate: DateTime.now(),
    helpText: '언제 해지했나요?',
  );
  if (picked == null) return;

  await ref
      .read(subscriptionsProvider.notifier)
      .cancel(subscription.id, canceledAt: picked);
}

/// 해지된 구독의 해지일만 고친다. 상세 화면의 '해지일' 줄에서 부른다.
Future<void> showCanceledAtEditor(
  BuildContext context,
  WidgetRef ref,
  Subscription subscription,
) async {
  final picked = await pickDate(
    context,
    initialDate: subscription.canceledAt ?? DateTime.now(),
    firstDate: subscription.startedAt,
    lastDate: DateTime.now(),
    helpText: '언제 해지했나요?',
  );
  if (picked == null) return;

  await ref
      .read(subscriptionsProvider.notifier)
      .setCanceledAt(subscription.id, picked);
}

/// 요금제 변경. 카탈로그에 요금제가 여러 개면 골라서, 없으면 금액을 직접
/// 입력해서 바꾼다. 주기도 함께 기록해 과거 결제가 다시 계산되지 않게 한다.
Future<void> showPlanChangeSheet(
  BuildContext context,
  WidgetRef ref,
  Subscription subscription,
) async {
  final catalog = ServiceCatalog.byId(subscription.serviceId ?? '');
  // 지금 통화와 다른 요금제는 섞이면 누적 지출이 망가지므로 걸러낸다.
  final plans = subscription.currency == Money.krw
      ? (catalog?.plans ?? const <CatalogPlan>[])
      : const <CatalogPlan>[];

  final picked = await showModalBottomSheet<_PlanResult>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: _PlanChangeBody(subscription: subscription, plans: plans),
    ),
  );

  if (picked == null || !context.mounted) return;

  final from = await pickDate(
    context,
    initialDate: DateTime.now(),
    firstDate: subscription.startedAt,
    lastDate: DateTime.now(),
    helpText: '언제부터 바뀌었나요?',
  );
  if (from == null) return;

  await ref
      .read(subscriptionsProvider.notifier)
      .changePlan(
        subscription.id,
        price: picked.amount,
        cycle: picked.cycle,
        effectiveFrom: from,
        memo: picked.planName,
      );
}

class _PlanResult {
  const _PlanResult({
    required this.amount,
    required this.cycle,
    this.planName,
  });

  final Money amount;
  final BillingCycle cycle;

  /// 카탈로그 요금제를 골랐으면 그 이름. 메모에 남긴다.
  final String? planName;
}

class _PlanChangeBody extends StatefulWidget {
  const _PlanChangeBody({required this.subscription, required this.plans});

  final Subscription subscription;
  final List<CatalogPlan> plans;

  @override
  State<_PlanChangeBody> createState() => _PlanChangeBodyState();
}

class _PlanChangeBodyState extends State<_PlanChangeBody> {
  late final TextEditingController _amount = TextEditingController(
    text: _amountText(widget.subscription.currentPrice),
  );

  late BillingCycle _cycle = widget.subscription.cycle;
  CatalogPlan? _selected;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Money? get _entered =>
      Money.tryParse(_amount.text, currency: widget.subscription.currency);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amount = _entered;
    final cycleChanged = _cycle != widget.subscription.cycle;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.sm,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('요금제 변경', style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '지금은 ${widget.subscription.currentPrice.format()} · '
              '${widget.subscription.cycle.label}이에요.',
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: AppSpacing.xl),

            if (widget.plans.length > 1) ...[
              Text('요금제', style: theme.textTheme.labelMedium),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final plan in widget.plans)
                    _Chip(
                      label: plan.name,
                      active: plan == _selected,
                      onTap: () => setState(() {
                        _selected = plan;
                        _cycle = plan.cycle;
                        _amount.text = plan.price.isZero
                            ? '0'
                            : _amountText(plan.price);
                      }),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
            ],

            Text('금액', style: theme.textTheme.labelMedium),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: _amount,
              textAlign: TextAlign.right,
              style: theme.textTheme.displaySmall,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              onChanged: (_) => setState(() => _selected = null),
              decoration: InputDecoration(
                suffixText: widget.subscription.currency,
                suffixStyle: theme.textTheme.labelMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            Text('결제 주기', style: theme.textTheme.labelMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final cycle in BillingCycle.values)
                  _Chip(
                    label: cycle.label,
                    active: cycle == _cycle,
                    onTap: () => setState(() {
                      _cycle = cycle;
                      _selected = null;
                    }),
                  ),
              ],
            ),

            if (cycleChanged) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  '주기가 바뀌어도 그전 결제는 ${widget.subscription.cycle.label} '
                  '그대로 계산해요. 누적 지출이 흔들리지 않아요.',
                  style: theme.textTheme.labelMedium,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),

            FilledButton(
              onPressed: amount == null
                  ? null
                  : () => Navigator.pop(
                      context,
                      _PlanResult(
                        amount: amount,
                        cycle: _cycle,
                        planName: _selected?.name,
                      ),
                    ),
              child: const Text('다음'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
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

String _amountText(Money money) => money.decimalDigits == 0
    ? money.major.toStringAsFixed(0)
    : money.major.toStringAsFixed(2);
