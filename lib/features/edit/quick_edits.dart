import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/money.dart';
import '../../data/models/subscription.dart';
import '../../providers/subscription_providers.dart';

/// 상세 화면에서 값 하나만 바로 고치는 창들.
///
/// 편집 화면을 통째로 여는 대신, 고치려는 항목을 눌러 그 자리에서 끝낸다.
/// 날짜 하나 바꾸려고 점 세 개 -> 편집 -> 저장을 거치는 건 번거롭다.

/// 금액 고치기. 바꾸면 요금 인상인지 오타 정정인지 물어본다.
Future<void> showPriceEditor(
  BuildContext context,
  WidgetRef ref,
  Subscription subscription,
) async {
  final controller = TextEditingController(
    text: _amountText(subscription.currentPrice),
  );

  final entered = await showDialog<Money>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('금액'),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        decoration: InputDecoration(suffixText: subscription.currency),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(
            dialogContext,
            Money.tryParse(controller.text, currency: subscription.currency),
          ),
          child: const Text('확인'),
        ),
      ],
    ),
  );

  controller.dispose();

  if (entered == null || entered.isZero) return;
  if (entered == subscription.currentPrice) return;
  if (!context.mounted) return;

  await applyPriceChange(context, ref, subscription, entered);
}

/// 바뀐 금액을 어떤 뜻으로 반영할지 묻고 적용한다.
///
/// 이 구분이 없으면 누적 지출이 틀어진다. 요금이 오른 거라면 그 전 결제는
/// 옛 금액으로 남아야 하고, 잘못 적은 거라면 처음부터 새 금액이어야 한다.
Future<void> applyPriceChange(
  BuildContext context,
  WidgetRef ref,
  Subscription subscription,
  Money next,
) async {
  final before = subscription.currentPrice;
  final increased = next.minor > before.minor;

  final kind = await showDialog<_PriceEditKind>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('${before.format()} → ${next.format()}'),
      content: const Text('지금까지의 누적 지출을 어떻게 계산할까요?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.pop(dialogContext, _PriceEditKind.correction),
          child: const Text('처음부터 잘못 적었어요'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, _PriceEditKind.changed),
          child: Text(increased ? '요금이 올랐어요' : '요금이 내렸어요'),
        ),
      ],
    ),
  );

  if (kind == null || !context.mounted) return;

  final notifier = ref.read(subscriptionsProvider.notifier);

  if (kind == _PriceEditKind.correction) {
    await notifier.correctLatestPrice(subscription.id, next);
    return;
  }

  final effectiveFrom = await showDatePicker(
    context: context,
    initialDate: DateTime.now(),
    firstDate: subscription.startedAt,
    lastDate: DateTime.now(),
    helpText: '언제부터 바뀐 금액인가요?',
  );
  if (effectiveFrom == null) return;

  await notifier.recordPriceChange(
    subscription.id,
    next,
    effectiveFrom: effectiveFrom,
  );
}

enum _PriceEditKind { changed, correction }

/// 구독 시작일 고치기. 누적 지출과 결제일이 여기서 계산되므로
/// 바꾸면 화면의 숫자들이 함께 달라진다.
Future<void> showStartDateEditor(
  BuildContext context,
  WidgetRef ref,
  Subscription subscription,
) async {
  final picked = await showDatePicker(
    context: context,
    initialDate: subscription.startedAt,
    firstDate: DateTime(2010),
    lastDate: DateTime.now(),
    helpText: '구독을 시작한 날',
  );
  if (picked == null) return;

  await ref
      .read(subscriptionsProvider.notifier)
      .setStartedAt(subscription.id, picked);
}

/// 카드 결제일 기준 고치기. 시작일과 결제일이 다를 때 쓴다.
Future<void> showBillingAnchorEditor(
  BuildContext context,
  WidgetRef ref,
  Subscription subscription,
) async {
  final notifier = ref.read(subscriptionsProvider.notifier);

  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.event_outlined),
            title: const Text('결제일 직접 지정'),
            subtitle: const Text('가장 최근 결제일을 골라주세요'),
            onTap: () => Navigator.pop(sheetContext, 'pick'),
          ),
          if (subscription.billingAnchor != null)
            ListTile(
              leading: const Icon(Icons.restart_alt),
              title: const Text('시작일과 같게'),
              onTap: () => Navigator.pop(sheetContext, 'clear'),
            ),
        ],
      ),
    ),
  );

  if (choice == null || !context.mounted) return;

  if (choice == 'clear') {
    await notifier.setBillingAnchor(subscription.id, null);
    return;
  }

  final picked = await showDatePicker(
    context: context,
    initialDate: subscription.billingAnchor ?? DateTime.now(),
    firstDate: DateTime(2010),
    lastDate: DateTime.now().add(const Duration(days: 365)),
    helpText: '가장 최근 결제일',
  );
  if (picked == null) return;

  await notifier.setBillingAnchor(subscription.id, picked);
}

/// 결제 수단 메모 고치기.
Future<void> showPaymentMethodEditor(
  BuildContext context,
  WidgetRef ref,
  Subscription subscription,
) async {
  final controller = TextEditingController(
    text: subscription.paymentMethod ?? '',
  );

  final saved = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('결제 수단'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: '예: 신한카드 1234'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
          child: const Text('저장'),
        ),
      ],
    ),
  );

  controller.dispose();
  if (saved == null) return;

  await ref
      .read(subscriptionsProvider.notifier)
      .setPaymentMethod(subscription.id, saved.isEmpty ? null : saved);
}

String _amountText(Money money) => money.decimalDigits == 0
    ? money.major.toStringAsFixed(0)
    : money.major.toStringAsFixed(2);

/// 눌러서 고칠 수 있다는 걸 알려주는 연필 아이콘.
class EditAffordance extends StatelessWidget {
  const EditAffordance({super.key, this.size = 15});

  final double size;

  @override
  Widget build(BuildContext context) => Icon(
    Icons.edit_outlined,
    size: size,
    color: AppColors.accent.withValues(alpha: 0.8),
  );
}

/// 상세 화면의 한 줄. [onTap] 을 주면 눌러서 바로 고칠 수 있다.
class EditableInfoTile extends StatelessWidget {
  const EditableInfoTile({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            Text(label, style: theme.textTheme.labelMedium),
            const Spacer(),
            Flexible(
              child: Text(
                value,
                style: theme.textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: AppSpacing.sm),
              const EditAffordance(),
            ],
          ],
        ),
      ),
    );
  }
}
