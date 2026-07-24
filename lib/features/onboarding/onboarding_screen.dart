import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/format/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/catalog/catalog_service.dart';
import '../../data/models/money.dart';
import '../../data/models/subscription.dart';
import '../../providers/app_providers.dart';
import '../../providers/subscription_providers.dart';
import '../../widgets/service_browser.dart';
import '../../widgets/service_icon.dart';
import '../home/home_screen.dart';

/// 첫 실행 화면. 두 단계로 나눈다.
///
/// 1단계 — 구독 중인 서비스를 그리드에서 탭해서 고른다.
/// 2단계 — 고른 것들의 요금제와 시작일만 확인한다. 전부 기본값이 채워져 있어
///        그대로 "완료"를 눌러도 쓸 만한 데이터가 남는다.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _selected = <String>{};
  final _drafts = <String, _SubscriptionDraft>{};
  final _search = TextEditingController();

  String _query = '';
  bool _reviewing = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggle(CatalogService service) {
    setState(() {
      if (_selected.remove(service.id)) {
        _drafts.remove(service.id);
      } else {
        _selected.add(service.id);
        _drafts[service.id] = _SubscriptionDraft(service);
      }
    });
  }

  Future<void> _finish() async {
    final uuid = const Uuid();
    final subscriptions = _drafts.values.map(
      (draft) => Subscription(
        id: uuid.v4(),
        serviceId: draft.service.id,
        name: draft.service.name,
        brandColorValue: draft.service.brandColor,
        cycle: draft.plan.cycle,
        startedAt: draft.startedAt,
        priceHistory: [
          PricePoint(effectiveFrom: draft.startedAt, amount: draft.price),
        ],
        memo: draft.plan.name,
      ),
    );

    await ref.read(subscriptionsProvider.notifier).addAll(subscriptions);
    await ref.read(onboardingCompleteProvider.notifier).complete();

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _reviewing ? _buildReviewStep() : _buildPickStep(),
      ),
    );
  }

  // ── 1단계: 고르기 ────────────────────────────────────────

  Widget _buildPickStep() {
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.xxl,
            AppSpacing.screenH,
            AppSpacing.lg,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '어떤 걸\n구독하고 계세요?',
              style: theme.textTheme.displayMedium,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
          child: TextField(
            controller: _search,
            decoration: const InputDecoration(
              hintText: '서비스 검색',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // 분야는 필터가 아니라 목차다. 눌러도 다른 분야가 사라지지 않는다.
        Expanded(
          child: ServiceBrowser(
            query: _query,
            selectedIds: _selected,
            onTap: _toggle,
          ),
        ),
        // 고르기만 하면 끝난다. 요금제와 시작일은 기본값으로 채우고,
        // 굳이 손보고 싶은 사람만 두 번째 단계로 간다.
        _BottomBar(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_selected.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    '기본 요금제로 등록돼요. 나중에 언제든 바꿀 수 있어요.',
                    style: theme.textTheme.labelMedium,
                  ),
                ),
              FilledButton(
                onPressed: _selected.isEmpty ? null : _finish,
                child: Text(
                  _selected.isEmpty
                      ? '구독 중인 서비스를 골라주세요'
                      : '${_selected.length}개로 시작하기',
                ),
              ),
              TextButton(
                onPressed: _selected.isEmpty
                    ? _skip
                    : () => setState(() => _reviewing = true),
                child: Text(
                  _selected.isEmpty ? '나중에 직접 추가할게요' : '요금제·시작일 직접 고르기',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _skip() async {
    await ref.read(onboardingCompleteProvider.notifier).complete();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  // ── 2단계: 요금제·시작일 확인 ─────────────────────────────

  Widget _buildReviewStep() {
    final theme = Theme.of(context);
    final drafts = _drafts.values.toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.screenH,
            0,
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _reviewing = false),
                icon: const Icon(Icons.arrow_back),
              ),
              const Spacer(),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.sm,
            AppSpacing.screenH,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('요금제만 확인해주세요', style: theme.textTheme.displaySmall),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '기본값이 채워져 있어요. 다른 게 있으면 눌러서 바꿔주세요.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.labelMedium?.color,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              0,
              AppSpacing.screenH,
              AppSpacing.xxl,
            ),
            itemCount: drafts.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) => _DraftCard(
              draft: drafts[index],
              onChanged: () => setState(() {}),
            ),
          ),
        ),
        _BottomBar(
          child: FilledButton(onPressed: _finish, child: const Text('완료')),
        ),
      ],
    );
  }
}

/// 2단계에서 편집 중인 구독 한 건.
class _SubscriptionDraft {
  _SubscriptionDraft(this.service)
    : plan = service.defaultPlan,
      price = service.defaultPlan.price,
      startedAt = DateTime.now();

  final CatalogService service;
  CatalogPlan plan;
  Money price;
  DateTime startedAt;

  void selectPlan(CatalogPlan next) {
    plan = next;
    price = next.price;
  }
}

class _DraftCard extends StatelessWidget {
  const _DraftCard({required this.draft, required this.onChanged});

  final _SubscriptionDraft draft;
  final VoidCallback onChanged;

  Future<void> _pickStartDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: draft.startedAt,
      firstDate: DateTime(2010),
      lastDate: DateTime.now(),
      helpText: '구독을 시작한 날',
    );
    if (picked != null) {
      draft.startedAt = picked;
      onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = draft.service;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ServiceIcon.fromCatalog(service, size: 44),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    service.name,
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  draft.price.format(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (service.plans.length > 1) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final plan in service.plans)
                    _PlanChip(
                      label: plan.name,
                      active: plan == draft.plan,
                      onTap: () {
                        draft.selectPlan(plan);
                        onChanged();
                      },
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            InkWell(
              onTap: () => _pickStartDate(context),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_outlined,
                      size: 16,
                      color: theme.textTheme.labelMedium?.color,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '시작 ${formatDate(draft.startedAt)}',
                      style: theme.textTheme.labelMedium,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '(${formatDuration(draft.startedAt)})',
                      style: theme.textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanChip extends StatelessWidget {
  const _PlanChip({
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

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.md,
        AppSpacing.screenH,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: child,
    );
  }
}
