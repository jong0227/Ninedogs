import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'form_fields.dart';
import '../../core/format/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/catalog/catalog_service.dart';
import '../../data/catalog/service_catalog.dart';
import '../../data/models/billing_cycle.dart';
import '../../data/models/money.dart';
import '../../data/models/people.dart';
import '../../data/models/subscription.dart';
import '../../providers/people_providers.dart';
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
  String? _owner;
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
    _owner = existing?.owner;

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
  static CatalogPlan? _matchPlan(
    CatalogService? service,
    Subscription current,
  ) {
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

  Money? get _enteredPrice => Money.tryParse(_amount.text, currency: _currency);

  // ── 저장 ────────────────────────────────────────────────

  Future<void> _save() async {
    final price = _enteredPrice;
    // 0원은 허용한다. 상위 상품(와우 멤버십 등)에 포함돼서 따로 결제가
    // 없는 구독을 0원으로 등록할 수 있어야 한다. 막아야 하는 건 아예
    // 입력하지 않은 경우(빈 문자열 -> tryParse 가 null)뿐이다.
    if (price == null) {
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
    final subscription = Subscription.create(
      id: const Uuid().v4(),
      serviceId: widget.service?.id,
      name: _name.text.trim(),
      brandColorValue: widget.service?.brandColor ?? _colorForName(_name.text),
      cycle: _cycle,
      startedAt: _startedAt,
      billingAnchor: _billingAnchor,
      trialEndsAt: _trialEndsAt,
      priceHistory: [
        PricePoint(effectiveFrom: _startedAt, amount: price, cycle: _cycle),
      ],
      paymentMethod: _nullIfBlank(_paymentMethod.text),
      memo: _nullIfBlank(_memo.text),
      owner: _owner,
    );

    await ref.read(subscriptionsProvider.notifier).add(subscription);
  }

  Future<void> _applyEdit(Subscription existing, Money price) async {
    final history = await _nextPriceHistory(existing, price);
    if (history == null) return; // 사용자가 취소함

    // 예전엔 여기서 Subscription 을 통째로 다시 만들다가 pastPeriods 와
    // reminderDaysBefore 를 빠뜨려, 편집만 해도 구독 이력이 날아갔다.
    // copyWith 는 건드리지 않은 필드를 그대로 넘기므로 그 사고가 안 난다.
    final updated = existing.copyWith(
      name: _name.text.trim(),
      cycle: _cycle,
      startedAt: _startedAt,
      priceHistory: history,
      billingAnchor: () => _billingAnchor,
      trialEndsAt: () => _trialEndsAt,
      paymentMethod: () => _nullIfBlank(_paymentMethod.text),
      memo: () => _nullIfBlank(_memo.text),
      owner: () => _owner,
    );

    await ref.read(subscriptionsProvider.notifier).replace(updated);
  }

  /// 바뀐 금액·주기를 반영한 가격 이력. 사용자가 중간에 취소하면 null.
  Future<List<PricePoint>?> _nextPriceHistory(
    Subscription existing,
    Money price,
  ) async {
    final currencyChanged = _currency != existing.currency;
    final priceChanged = price != existing.currentPrice;
    final cycleChanged = _cycle != existing.cycle;

    // 통화를 바꾸면 옛 항목은 원화, 새 항목은 달러가 되어 이력에 두 통화가
    // 섞인다. 그 상태로는 누적 지출을 더할 수 없다 — Money 의 통화 검사는
    // assert 라 릴리즈에서는 사라지고, 13,500원을 $135.00 로 조용히 더한다.
    // 그래서 섞이게 두지 않고, 이력을 새 통화로 다시 시작할지 먼저 묻는다.
    if (currencyChanged) {
      final reset = await _confirmCurrencyReset(existing);
      if (reset != true) return null;
      return [
        PricePoint(effectiveFrom: _startedAt, amount: price, cycle: _cycle),
      ];
    }

    if (!priceChanged && !cycleChanged) return existing.priceHistory;

    // 금액이 그대로고 주기만 바뀐 경우엔 "요금이 올랐나 / 잘못 적었나"를
    // 묻는 게 말이 안 된다. 언제부터 그 주기였는지만 물으면 된다.
    if (!priceChanged) {
      final from = await _pickEffectiveDate(helpText: '언제부터 이 주기로 바뀌었나요?');
      if (from == null) return null;
      return [
        ...existing.priceHistory,
        PricePoint(effectiveFrom: from, amount: price, cycle: _cycle),
      ];
    }

    final kind = await askPriceEditKind(
      context,
      before: existing.currentPrice,
      next: price,
    );
    if (kind == null) return null;

    if (kind == PriceEditKind.changed) {
      final from = await _pickEffectiveDate();
      if (from == null) return null;
      return [
        ...existing.priceHistory,
        PricePoint(effectiveFrom: from, amount: price, cycle: _cycle),
      ];
    }

    // 정정: 이력을 늘리지 않고 마지막 항목을 갈아끼운다.
    final last = existing.priceHistory.last;
    return [
      ...existing.priceHistory.take(existing.priceHistory.length - 1),
      PricePoint(
        effectiveFrom: last.effectiveFrom,
        amount: price,
        cycle: _cycle,
      ),
    ];
  }

  Future<bool?> _confirmCurrencyReset(Subscription existing) =>
      showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('통화를 바꿀까요?'),
          content: Text(
            '${existing.currency} 로 쌓인 가격 이력 ${existing.priceHistory.length}건을 '
            '지우고 $_currency 로 다시 시작해요. 두 통화를 섞으면 누적 지출이 '
            '엉뚱하게 계산돼서, 이력을 함께 정리해야 해요.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('바꾸기'),
            ),
          ],
        ),
      );

  Future<DateTime?> _pickEffectiveDate({String helpText = '언제부터 바뀐 금액인가요?'}) =>
      pickDate(
        context,
        initialDate: DateTime.now(),
        firstDate: _startedAt,
        lastDate: DateTime.now(),
        helpText: helpText,
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
      0xFF5B6ABF,
      0xFF3FB68B,
      0xFFD9705A,
      0xFF8E6BBF,
      0xFF3D8FB5,
      0xFFC2913C,
      0xFFB5527E,
      0xFF4F9E5C,
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
            const FieldLabel('요금제'),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final plan in plans)
                  FormChip(
                    label: plan.name,
                    active: plan == _selectedPlan,
                    onTap: () => setState(() {
                      _selectedPlan = plan;
                      _cycle = plan.cycle;
                      _currency = Money.krw;
                      // 0원 요금제(번들 포함)를 고르면 '0'을 그대로 보여준다.
                      // 빈칸으로 두면 아무것도 안 고른 것처럼 보여 헷갈린다.
                      _amount.text = plan.price.isZero
                          ? '0'
                          : _formatAmountInput(plan.price);
                      _amountError = null;
                      _memo.text = plan.name;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
          ],

          const FieldLabel('금액'),
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
              CurrencyToggle(
                currency: _currency,
                onChanged: (value) => setState(() => _currency = value),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          const FieldLabel('결제 주기'),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final cycle in BillingCycle.values)
                FormChip(
                  label: cycle.label,
                  active: cycle == _cycle,
                  onTap: () => setState(() => _cycle = cycle),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          const FieldLabel('구독 시작일'),
          DateRow(
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
            DateRow(
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
            DateRow(
              value: formatDate(_billingAnchor!),
              hint: '기준 결제일',
              onTap: () => _pickDate(
                initial: _billingAnchor!,
                helpText: '가장 최근 결제일',
                onPicked: (date) => _billingAnchor = date,
              ),
            ),
          const SizedBox(height: AppSpacing.xl),

          const FieldLabel('누구 것'),
          _OwnerPicker(
            value: _owner,
            onChanged: (value) => setState(() => _owner = value),
          ),
          const SizedBox(height: AppSpacing.xl),

          const FieldLabel('결제 수단'),
          TextField(
            controller: _paymentMethod,
            decoration: const InputDecoration(hintText: '예: 신한카드 1234'),
          ),
          const SizedBox(height: AppSpacing.xl),

          const FieldLabel('메모'),
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

/// 구독 주인 고르기. 두 사람 + 공동(미지정). 색은 목록의 이름표와 같다.
class _OwnerPicker extends ConsumerWidget {
  const _OwnerPicker({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final people = ref.watch(peopleProvider);
    Widget chip(String? key, String label, Color? color) {
      final selected = value == key;
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        selectedColor: (color ?? Theme.of(context).colorScheme.onSurface)
            .withValues(alpha: 0.18),
        labelStyle: TextStyle(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? color : null,
        ),
        onSelected: (_) => onChanged(key),
      );
    }

    return Wrap(
      spacing: AppSpacing.sm,
      children: [
        for (final key in People.slots)
          chip(key, people.nameOf(key), People.colorOf(key)),
        chip(null, '공동', null),
      ],
    );
  }
}
