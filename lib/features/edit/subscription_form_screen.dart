import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/format/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/catalog/catalog_service.dart';
import '../../data/models/billing_cycle.dart';
import '../../data/models/money.dart';
import '../../data/models/subscription.dart';
import '../../providers/subscription_providers.dart';
import '../../widgets/service_icon.dart';

/// 금액이 바뀌었을 때 그 의미.
enum _PriceEditKind {
  /// 실제로 요금이 바뀜 -> 이력에 새 항목을 남기고 그 전 결제는 옛 금액으로 둔다.
  changed,

  /// 처음부터 잘못 적음 -> 마지막 항목을 고쳐서 누적 지출을 다시 계산한다.
  correction,
}

/// 구독 추가·편집 화면. 두 경우가 입력 항목이 같아서 한 화면으로 쓴다.
class SubscriptionFormScreen extends ConsumerStatefulWidget {
  const SubscriptionFormScreen({
    super.key,
    this.service,
    this.customName,
    this.existing,
  });

  /// 카탈로그에서 고른 서비스. 직접 입력이면 null.
  final CatalogService? service;

  /// 직접 입력한 서비스 이름.
  final String? customName;

  /// 편집 중인 구독. 새로 추가하는 경우 null.
  final Subscription? existing;

  bool get isEditing => existing != null;

  @override
  ConsumerState<SubscriptionFormScreen> createState() =>
      _SubscriptionFormScreenState();
}

class _SubscriptionFormScreenState
    extends ConsumerState<SubscriptionFormScreen> {
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late final TextEditingController _paymentMethod;
  late final TextEditingController _memo;

  late String _currency;
  late BillingCycle _cycle;
  late DateTime _startedAt;
  DateTime? _billingAnchor;

  CatalogPlan? _selectedPlan;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final service = widget.service;
    final plan = service?.defaultPlan;

    _selectedPlan = existing == null ? plan : null;

    _name = TextEditingController(
      text: existing?.name ?? service?.name ?? widget.customName ?? '',
    );
    _currency = existing?.currency ?? Money.krw;
    _amount = TextEditingController(
      text: _formatAmountInput(
        existing?.currentPrice ?? plan?.price ?? Money.zero(),
      ),
    );
    _paymentMethod = TextEditingController(text: existing?.paymentMethod ?? '');
    _memo = TextEditingController(text: existing?.memo ?? plan?.name ?? '');

    _cycle = existing?.cycle ?? plan?.cycle ?? BillingCycle.monthly;
    _startedAt = existing?.startedAt ?? DateTime.now();
    _billingAnchor = existing?.billingAnchor;
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _paymentMethod.dispose();
    _memo.dispose();
    super.dispose();
  }

  String _formatAmountInput(Money money) {
    if (money.isZero) return '';
    final major = money.major;
    return money.decimalDigits == 0
        ? major.toStringAsFixed(0)
        : major.toStringAsFixed(2);
  }

  Money? get _enteredPrice =>
      Money.tryParse(_amount.text, currency: _currency);

  // ── 저장 ────────────────────────────────────────────────

  Future<void> _save() async {
    final price = _enteredPrice;
    if (price == null || price.isZero) {
      setState(() => _amountError = '금액을 입력해주세요');
      return;
    }
    if (_name.text.trim().isEmpty) return;

    setState(() => _amountError = null);

    final existing = widget.existing;
    if (existing == null) {
      await _create(price);
    } else {
      await _applyEdit(existing, price);
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _create(Money price) async {
    final subscription = Subscription(
      id: const Uuid().v4(),
      serviceId: widget.service?.id,
      name: _name.text.trim(),
      brandColorValue: widget.service?.brandColor ?? _colorForName(_name.text),
      cycle: _cycle,
      startedAt: _startedAt,
      billingAnchor: _billingAnchor,
      priceHistory: [PricePoint(effectiveFrom: _startedAt, amount: price)],
      paymentMethod: _nullIfBlank(_paymentMethod.text),
      memo: _nullIfBlank(_memo.text),
    );

    await ref.read(subscriptionsProvider.notifier).add(subscription);
  }

  Future<void> _applyEdit(Subscription existing, Money price) async {
    var history = existing.priceHistory;

    if (price != existing.currentPrice) {
      final kind = await _askPriceEditKind(existing.currentPrice, price);
      if (kind == null) return; // 사용자가 취소함

      if (kind == _PriceEditKind.changed) {
        final effectiveFrom = await _pickEffectiveDate();
        if (effectiveFrom == null) return;
        history = [
          ...history,
          PricePoint(effectiveFrom: effectiveFrom, amount: price),
        ];
      } else {
        history = [
          ...history.take(history.length - 1),
          PricePoint(
            effectiveFrom: history.last.effectiveFrom,
            amount: price,
          ),
        ];
      }
    }

    final updated = Subscription(
      id: existing.id,
      serviceId: existing.serviceId,
      name: _name.text.trim(),
      iconUrl: existing.iconUrl,
      brandColorValue: existing.brandColorValue,
      cycle: _cycle,
      startedAt: _startedAt,
      billingAnchor: _billingAnchor,
      priceHistory: history,
      canceledAt: existing.canceledAt,
      accessEndsAt: existing.accessEndsAt,
      paymentMethod: _nullIfBlank(_paymentMethod.text),
      credentialId: existing.credentialId,
      memo: _nullIfBlank(_memo.text),
    );

    await ref.read(subscriptionsProvider.notifier).replace(updated);
  }

  /// 금액이 달라졌을 때, 실제 인상인지 오타 정정인지 물어본다.
  /// 이 구분에 따라 누적 지출 계산이 달라지므로 그냥 덮어쓰지 않는다.
  Future<_PriceEditKind?> _askPriceEditKind(Money before, Money after) {
    final increased = after.minor > before.minor;

    return showDialog<_PriceEditKind>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('금액이 ${before.format()} → ${after.format()} 으로 달라졌어요'),
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
            onPressed: () =>
                Navigator.pop(dialogContext, _PriceEditKind.changed),
            child: Text(increased ? '요금이 올랐어요' : '요금이 내렸어요'),
          ),
        ],
      ),
    );
  }

  Future<DateTime?> _pickEffectiveDate() => showDatePicker(
    context: context,
    initialDate: DateTime.now(),
    firstDate: _startedAt,
    lastDate: DateTime.now(),
    helpText: '언제부터 바뀐 금액인가요?',
  );

  Future<void> _pickDate({
    required DateTime initial,
    required String helpText,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2010),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: helpText,
    );
    if (picked != null) setState(() => onPicked(picked));
  }

  static String? _nullIfBlank(String text) =>
      text.trim().isEmpty ? null : text.trim();

  /// 카탈로그에 없는 서비스의 대체 타일 색. 이름이 같으면 늘 같은 색이 나온다.
  static int _colorForName(String name) {
    const palette = [
      0xFF5B6ABF, 0xFF3FB68B, 0xFFD9705A, 0xFF8E6BBF,
      0xFF3D8FB5, 0xFFC2913C, 0xFFB5527E, 0xFF4F9E5C,
    ];
    var hash = 0;
    for (final unit in name.trim().codeUnits) {
      hash = (hash * 31 + unit) & 0x7FFFFFFF;
    }
    return palette[hash % palette.length];
  }

  // ── 화면 ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = widget.service;
    final plans = service?.plans ?? const <CatalogPlan>[];

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? '구독 편집' : '구독 추가')),
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
                name: _name.text,
                brandColor: Color(
                  widget.existing?.brandColorValue ??
                      service?.brandColor ??
                      _colorForName(_name.text),
                ),
                serviceId:
                    widget.existing?.serviceId ??
                    service?.id ??
                    'custom:${_name.text.trim()}',
                searchTerm: service?.searchTerm ?? _name.text.trim(),
                imageUrl: widget.existing?.iconUrl,
                size: 56,
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: '서비스 이름'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          if (plans.length > 1) ...[
            const _FieldLabel('요금제'),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final plan in plans)
                  _ChoiceChip(
                    label: plan.name,
                    active: plan == _selectedPlan,
                    onTap: () => setState(() {
                      _selectedPlan = plan;
                      _cycle = plan.cycle;
                      _currency = Money.krw;
                      _amount.text = _formatAmountInput(plan.price);
                      _memo.text = plan.name;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
          ],

          const _FieldLabel('금액'),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: InputDecoration(
                    hintText: '0',
                    errorText: _amountError,
                  ),
                  onChanged: (_) => setState(() => _selectedPlan = null),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              _CurrencyToggle(
                currency: _currency,
                onChanged: (value) => setState(() => _currency = value),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          const _FieldLabel('결제 주기'),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final cycle in BillingCycle.values)
                _ChoiceChip(
                  label: cycle.label,
                  active: cycle == _cycle,
                  onTap: () => setState(() => _cycle = cycle),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          const _FieldLabel('구독 시작일'),
          _DateRow(
            value: formatDate(_startedAt),
            hint: formatDuration(_startedAt),
            onTap: () => _pickDate(
              initial: _startedAt,
              helpText: '구독을 시작한 날',
              onPicked: (date) => _startedAt = date,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('카드 결제일이 시작일과 달라요'),
            subtitle: Text(
              _billingAnchor == null
                  ? '매번 ${_startedAt.day}일에 결제되는 것으로 계산해요'
                  : '매번 ${_billingAnchor!.day}일에 결제돼요',
              style: theme.textTheme.labelMedium,
            ),
            value: _billingAnchor != null,
            activeThumbColor: AppColors.accent,
            onChanged: (on) {
              if (!on) {
                setState(() => _billingAnchor = null);
              } else {
                _pickDate(
                  initial: _billingAnchor ?? DateTime.now(),
                  helpText: '가장 최근 결제일',
                  onPicked: (date) => _billingAnchor = date,
                );
              }
            },
          ),
          if (_billingAnchor != null)
            _DateRow(
              value: formatDate(_billingAnchor!),
              hint: '기준 결제일',
              onTap: () => _pickDate(
                initial: _billingAnchor!,
                helpText: '가장 최근 결제일',
                onPicked: (date) => _billingAnchor = date,
              ),
            ),
          const SizedBox(height: AppSpacing.xl),

          const _FieldLabel('결제 수단'),
          TextField(
            controller: _paymentMethod,
            decoration: const InputDecoration(hintText: '예: 신한카드 1234'),
          ),
          const SizedBox(height: AppSpacing.xl),

          const _FieldLabel('메모'),
          TextField(
            controller: _memo,
            decoration: const InputDecoration(hintText: '요금제 이름 등'),
          ),
          const SizedBox(height: AppSpacing.xxl),

          FilledButton(
            onPressed: _save,
            child: Text(widget.isEditing ? '저장' : '추가'),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(text, style: Theme.of(context).textTheme.labelMedium),
  );
}

class _DateRow extends StatelessWidget {
  const _DateRow({required this.value, required this.hint, required this.onTap});

  final String value;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            children: [
              const Icon(Icons.event_outlined, size: 18),
              const SizedBox(width: AppSpacing.md),
              Text(value, style: theme.textTheme.bodyMedium),
              const Spacer(),
              Text(hint, style: theme.textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrencyToggle extends StatelessWidget {
  const _CurrencyToggle({required this.currency, required this.onChanged});

  final String currency;
  final ValueChanged<String> onChanged;

  static const _options = [Money.krw, 'USD'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in _options)
            GestureDetector(
              onTap: () => onChanged(option),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.lg,
                ),
                decoration: BoxDecoration(
                  color: option == currency
                      ? AppColors.accent.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.md - 1),
                ),
                child: Text(
                  option,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: option == currency
                        ? AppColors.accent
                        : theme.textTheme.labelMedium?.color,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
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
