import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/format/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/catalog/catalog_service.dart';
import '../../data/catalog/service_catalog.dart';
import '../../data/models/billing_cycle.dart';
import '../../data/models/money.dart';
import '../../data/models/subscription.dart';
import '../../providers/subscription_providers.dart';
import '../../widgets/app_date_picker.dart';
import '../../widgets/service_icon.dart';
import 'quick_edits.dart';

/// 구독 추가·편집 화면. 두 경우가 입력 항목이 같아서 한 화면으로 쓴다.
class SubscriptionFormScreen extends ConsumerStatefulWidget {
  const SubscriptionFormScreen({
    super.key,
    this.service,
    this.customName,
    this.existing,
    this.initialPlan,
  });

  /// 카탈로그에서 고른 서비스. 직접 입력이면 null.
  final CatalogService? service;

  /// 직접 입력한 서비스 이름.
  final String? customName;

  /// 편집 중인 구독. 새로 추가하는 경우 null.
  final Subscription? existing;

  /// 기본 요금제 대신 미리 골라둘 요금제.
  ///
  /// 상위 상품(와우 멤버십 등)을 이미 등록한 사람에게 0원 '포함' 요금제를
  /// 골라준 채로 화면을 열 때 쓴다.
  final CatalogPlan? initialPlan;

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
  DateTime? _trialEndsAt;

  CatalogPlan? _selectedPlan;
  String? _amountError;

  /// 이 구독에 해당하는 카탈로그 서비스.
  ///
  /// 새로 추가할 때는 고른 서비스가 그대로 넘어오지만, 편집할 때는 넘어오지
  /// 않는다. 그래서 구독에 저장된 serviceId 로 다시 찾아온다.
  /// 이게 있어야 편집할 때도 요금제를 골라서 바꿀 수 있다.
  CatalogService? get _catalog =>
      widget.service ?? ServiceCatalog.byId(widget.existing?.serviceId ?? '');

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final service = _catalog;
    final plan = widget.initialPlan ?? service?.defaultPlan;

    _selectedPlan = existing == null ? plan : _matchPlan(service, existing);

    _name = TextEditingController(
      text: existing?.name ?? service?.name ?? widget.customName ?? '',
    );
    // 편집일 때는 기존 값이 우선이고, 새로 추가할 때만 기본 요금제로 채운다.
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
    _trialEndsAt = existing?.trialEndsAt;
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _paymentMethod.dispose();
    _memo.dispose();
    super.dispose();
  }

  /// 편집 화면을 열었을 때 지금 쓰는 요금제가 어느 것인지 짚어준다.
  /// 메모에 요금제 이름을 남겨두므로 그것부터 보고, 없으면 금액으로 찾는다.
  static CatalogPlan? _matchPlan(CatalogService? service, Subscription current) {
    if (service == null) return null;

    for (final plan in service.plans) {
      if (plan.name == current.memo) return plan;
    }
    for (final plan in service.plans) {
      if (plan.price == current.currentPrice && plan.cycle == current.cycle) {
        return plan;
      }
    }
    // 직접 고친 금액이면 어느 요금제도 아니다. 칩은 아무것도 선택되지 않는다.
    return null;
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
      trialEndsAt: _trialEndsAt,
      priceHistory: [PricePoint(effectiveFrom: _startedAt, amount: price)],
      paymentMethod: _nullIfBlank(_paymentMethod.text),
      memo: _nullIfBlank(_memo.text),
    );

    await ref.read(subscriptionsProvider.notifier).add(subscription);
  }

  Future<void> _applyEdit(Subscription existing, Money price) async {
    var history = existing.priceHistory;

    if (price != existing.currentPrice) {
      final kind = await askPriceEditKind(
        context,
        before: existing.currentPrice,
        next: price,
      );
      if (kind == null) return; // 사용자가 취소함

      if (kind == PriceEditKind.changed) {
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
      trialEndsAt: _trialEndsAt,
      priceHistory: history,
      canceledAt: existing.canceledAt,
      accessEndsAt: existing.accessEndsAt,
      paymentMethod: _nullIfBlank(_paymentMethod.text),
      credentialId: existing.credentialId,
      memo: _nullIfBlank(_memo.text),
    );

    await ref.read(subscriptionsProvider.notifier).replace(updated);
  }

  Future<DateTime?> _pickEffectiveDate() => pickDate(
    context,
    initialDate: DateTime.now(),
    firstDate: _startedAt,
    lastDate: DateTime.now(),
    helpText: '언제부터 바뀐 금액인가요?',
  );

  Future<void> _pickDate({
    required DateTime initial,
    required String helpText,
    required ValueChanged<DateTime> onPicked,
    DateTime? last,
  }) async {
    final picked = await pickDate(
      context,
      initialDate: initial,
      firstDate: DateTime(2010),
      lastDate: last ?? DateTime.now().add(const Duration(days: 365)),
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
    final service = _catalog;
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
                // serviceId 가 없으면 ServiceIcon 이 이름으로 캐시·검색한다
                serviceId: widget.existing?.serviceId ?? service?.id,
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

          // 무료 체험 중이면 그 기간엔 돈이 나가지 않는다. 체험 종료일이
          // 곧 첫 결제일이라 누적 지출 계산의 기준이 된다.
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('무료 체험 중이에요'),
            subtitle: Text(
              _trialEndsAt == null
                  ? '체험이 끝나는 날부터 결제된 것으로 계산해요'
                  : '${formatDate(_trialEndsAt!)}에 첫 결제 · 그전까지는 0원',
              style: theme.textTheme.labelMedium,
            ),
            value: _trialEndsAt != null,
            activeThumbColor: AppColors.accent,
            onChanged: (on) {
              if (!on) {
                setState(() => _trialEndsAt = null);
              } else {
                _pickDate(
                  initial: DateTime.now().add(const Duration(days: 7)),
                  helpText: '무료 체험이 끝나는 날',
                  // 체험 종료일은 앞으로의 날짜다. 기본 상한(오늘)으로는 고를 수 없다.
                  last: DateTime.now().add(const Duration(days: 365 * 2)),
                  onPicked: (date) => _trialEndsAt = date,
                );
              }
            },
          ),
          if (_trialEndsAt != null)
            _DateRow(
              value: formatDate(_trialEndsAt!),
              hint: '무료 체험 종료 · 이날 첫 결제',
              onTap: () => _pickDate(
                initial: _trialEndsAt!,
                helpText: '무료 체험이 끝나는 날',
                last: DateTime.now().add(const Duration(days: 365 * 2)),
                onPicked: (date) => _trialEndsAt = date,
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
