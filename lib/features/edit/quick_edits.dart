import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/money.dart';
import '../../data/models/subscription.dart';
import '../../providers/subscription_providers.dart';
import '../../widgets/app_date_picker.dart';

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
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);

      void submit() => Navigator.pop(
        dialogContext,
        Money.tryParse(controller.text, currency: subscription.currency),
      );

      return AlertDialog(
        title: const Text('얼마인가요?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              // 금액은 오른쪽 정렬이 읽기 편하고 자릿수도 가늠된다.
              textAlign: TextAlign.right,
              style: theme.textTheme.displaySmall,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => submit(),
              decoration: InputDecoration(
                suffixText: subscription.currency,
                suffixStyle: theme.textTheme.labelMedium,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '포함된 혜택이라 따로 돈이 안 나가면 0을 넣어주세요.',
              style: theme.textTheme.labelMedium,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: TextButton.styleFrom(
              foregroundColor: theme.textTheme.labelMedium?.color,
            ),
            child: const Text('취소'),
          ),
          TextButton(onPressed: submit, child: const Text('확인')),
        ],
      );
    },
  );

  controller.dispose();

  // 0원도 받는다. 상위 상품(와우 멤버십 등)에 포함돼서 따로 돈이 나가지 않는
  // 구독을 0원으로 두면 목록에는 남으면서 합계에는 안 잡힌다.
  if (entered == null) return;
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

  final kind = await askPriceEditKind(context, before: before, next: next);
  if (kind == null || !context.mounted) return;

  final notifier = ref.read(subscriptionsProvider.notifier);

  if (kind == PriceEditKind.correction) {
    await notifier.correctLatestPrice(subscription.id, next);
    return;
  }

  final effectiveFrom = await pickDate(
    context,
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

/// 금액이 바뀌었을 때 그 의미.
enum PriceEditKind {
  /// 실제로 요금이 바뀜 → 이력에 새 항목을 남기고 그 전 결제는 옛 금액으로 둔다.
  changed,

  /// 처음부터 잘못 적음 → 마지막 항목을 고쳐서 누적 지출을 다시 계산한다.
  correction,
}

/// 금액이 달라진 이유를 묻는다. 상세 화면과 편집 화면이 같이 쓴다.
///
/// 선택지 문구가 길어서 버튼을 가로로 늘어놓으면 줄이 깨지고 어디를 눌러야
/// 할지도 안 읽힌다. 각각을 설명이 붙은 카드로 세워 고르게 한다.
Future<PriceEditKind?> askPriceEditKind(
  BuildContext context, {
  required Money before,
  required Money next,
}) {
  final increased = next.minor > before.minor;

  return showDialog<PriceEditKind>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);

      return AlertDialog(
        title: const Text('금액이 왜 달라졌나요?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AmountDelta(before: before, next: next),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '고르는 것에 따라 누적 지출이 달라져요.',
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            _ChoiceCard(
              icon: increased ? Icons.trending_up : Icons.trending_down,
              title: increased ? '요금이 올랐어요' : '요금이 내렸어요',
              body: '바뀐 날부터 새 금액으로 계산해요. 그 전 결제는 옛 금액 그대로예요.',
              onTap: () => Navigator.pop(dialogContext, PriceEditKind.changed),
            ),
            const SizedBox(height: AppSpacing.sm),
            _ChoiceCard(
              icon: Icons.edit_outlined,
              title: '처음부터 잘못 적었어요',
              body: '시작일까지 거슬러 새 금액으로 다시 계산해요.',
              onTap: () =>
                  Navigator.pop(dialogContext, PriceEditKind.correction),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: TextButton.styleFrom(
              foregroundColor: theme.textTheme.labelMedium?.color,
            ),
            child: const Text('취소'),
          ),
        ],
      );
    },
  );
}

/// 바뀌기 전 금액 → 바뀐 금액. 얼마나 달라졌는지 한 줄로 보여준다.
class _AmountDelta extends StatelessWidget {
  const _AmountDelta({required this.before, required this.next});

  final Money before;
  final Money next;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final increased = next.minor > before.minor;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              before.format(),
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium
                  ?.merge(AppTheme.numeric)
                  .copyWith(
                    color: theme.textTheme.labelMedium?.color,
                    decoration: TextDecoration.lineThrough,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Icon(
              Icons.arrow_forward,
              size: 14,
              color: theme.textTheme.labelMedium?.color,
            ),
          ),
          Flexible(
            child: Text(
              next.format(),
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium
                  ?.merge(AppTheme.numeric)
                  .copyWith(
                    fontWeight: FontWeight.w800,
                    color: increased ? AppColors.negative : AppColors.positive,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 바텀시트에서 고르는 항목 한 줄. [_ChoiceCard] 와 같은 결로 맞춘다.
class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.accent),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(body, style: theme.textTheme.labelMedium),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: theme.textTheme.labelMedium?.color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 설명이 붙은 선택지 한 장.
class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: AppColors.accent),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: theme.textTheme.labelMedium?.copyWith(height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 구독 시작일 고치기. 누적 지출과 결제일이 여기서 계산되므로
/// 바꾸면 화면의 숫자들이 함께 달라진다.
Future<void> showStartDateEditor(
  BuildContext context,
  WidgetRef ref,
  Subscription subscription,
) async {
  final picked = await pickDate(
    context,
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
              Text('카드 결제일 기준', style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '구독을 시작한 날과 실제 카드가 빠져나가는 날이 다를 때 맞춰주세요.',
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              _SheetAction(
                icon: Icons.event_outlined,
                title: '결제일 직접 지정',
                body: '가장 최근에 결제된 날을 골라주세요',
                onTap: () => Navigator.pop(sheetContext, 'pick'),
              ),
              if (subscription.billingAnchor != null) ...[
                const SizedBox(height: AppSpacing.sm),
                _SheetAction(
                  icon: Icons.restart_alt,
                  title: '시작일과 같게',
                  body: '따로 정한 결제일을 지워요',
                  onTap: () => Navigator.pop(sheetContext, 'clear'),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );

  if (choice == null || !context.mounted) return;

  if (choice == 'clear') {
    await notifier.setBillingAnchor(subscription.id, null);
    return;
  }

  final picked = await pickDate(
    context,
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
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);

      void submit() =>
          Navigator.pop(dialogContext, controller.text.trim());

      return AlertDialog(
        title: const Text('어떤 걸로 결제하나요?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => submit(),
              decoration: const InputDecoration(
                hintText: '예: 신한카드 1234',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '비워두면 등록하지 않은 것으로 둬요.',
              style: theme.textTheme.labelMedium,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: TextButton.styleFrom(
              foregroundColor: theme.textTheme.labelMedium?.color,
            ),
            child: const Text('취소'),
          ),
          TextButton(onPressed: submit, child: const Text('저장')),
        ],
      );
    },
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

    // 라벨은 왼쪽 고정폭, 값은 남는 자리를 채우며 오른쪽 정렬한다.
    // Spacer 로 밀어내면 값 길이에 따라 라벨 위치가 흔들려서 줄이 안 맞는다.
    // 연필 아이콘 자리는 항상 비워둬서 값 끝선도 어긋나지 않게 한다.
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.xs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 104,
              child: Text(
                label,
                style: theme.textTheme.labelMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                value,
                style: theme.textTheme.bodyMedium?.merge(AppTheme.numeric),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 15,
              child: onTap == null ? null : const EditAffordance(),
            ),
          ],
        ),
      ),
    );
  }
}
