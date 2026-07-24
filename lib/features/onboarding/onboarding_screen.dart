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
import '../shell/app_shell.dart';

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

  /// 맨 처음 보여주는 앱 소개. "시작하기"를 누르면 고르기 단계로 넘어간다.
  bool _showIntro = true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// 고른 순서대로. Set 과 Map 모두 넣은 순서를 유지한다.
  List<CatalogService> get _selectedServices =>
      _drafts.values.map((draft) => draft.service).toList();

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
      MaterialPageRoute(builder: (_) => const AppShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _showIntro
            ? _buildIntroStep()
            : _reviewing
            ? _buildReviewStep()
            : _buildPickStep(),
      ),
    );
  }

  // ── 0단계: 앱 소개 ──────────────────────────────────────

  Widget _buildIntroStep() {
    final theme = Theme.of(context);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.xxl,
              AppSpacing.screenH,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xl),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    width: 84,
                    height: 84,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('Ninedogs', style: theme.textTheme.displayMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '흩어진 구독을 한곳에서.\n뭘 얼마에 쓰고 있는지 한눈에 봐요.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.textTheme.labelMedium?.color,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                const _IntroPoint(
                  icon: Icons.grid_view_rounded,
                  title: '구독 한눈에 모아보기',
                  body: '넷플릭스부터 멜론까지, 아이콘으로 깔끔하게.',
                ),
                const _IntroPoint(
                  icon: Icons.trending_up_rounded,
                  title: '누적 지출 자동 계산',
                  body: '앱별로, 전체로 지금까지 얼마 썼는지 알려줘요.',
                ),
                const _IntroPoint(
                  icon: Icons.notifications_active_outlined,
                  title: '결제 전 미리 알림',
                  body: '결제일이 다가오면 며칠 전에 짚어드려요.',
                ),
                const _IntroPoint(
                  icon: Icons.lock_outline,
                  title: '아이디·비밀번호 금고',
                  body: '서비스 계정 정보를 암호화해서 보관해요.',
                ),
                const _IntroPoint(
                  icon: Icons.favorite_outline,
                  title: '배우자와 함께 보기',
                  body: '연결하면 같은 구독 목록을 함께 관리해요.',
                ),
              ],
            ),
          ),
        ),
        _BottomBar(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton(
                onPressed: () => setState(() => _showIntro = false),
                child: const Text('시작하기'),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '입력한 정보는 이 기기에 저장돼요',
                style: theme.textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ],
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
        // 무엇을 몇 개 골랐는지 항상 보이게 한다.
        // 그리드만 있으면 스크롤하다가 내가 뭘 골랐는지 놓치게 된다.
        _SelectedStrip(
          services: _selectedServices,
          onRemove: _toggle,
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
    ).pushReplacement(MaterialPageRoute(builder: (_) => const AppShell()));
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

/// 소개 화면의 기능 한 줄. 아이콘 + 제목 + 설명.
class _IntroPoint extends StatelessWidget {
  const _IntroPoint({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, size: 22, color: AppColors.accent),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.labelMedium?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 지금까지 고른 서비스를 작은 아이콘으로 늘어놓는 띠.
///
/// 하나도 없으면 자리를 차지하지 않고, 고르는 순간 부드럽게 펼쳐진다.
/// 아이콘을 누르면 선택이 풀린다 — 그리드에서 다시 찾아 누를 필요가 없다.
class _SelectedStrip extends StatefulWidget {
  const _SelectedStrip({required this.services, required this.onRemove});

  final List<CatalogService> services;
  final ValueChanged<CatalogService> onRemove;

  @override
  State<_SelectedStrip> createState() => _SelectedStripState();
}

class _SelectedStripState extends State<_SelectedStrip> {
  final _scroll = ScrollController();

  static const _iconSize = 38.0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_SelectedStrip old) {
    super.didUpdateWidget(old);

    // 새로 고른 게 끝에 붙으므로 끝으로 밀어준다.
    // 안 그러면 방금 고른 게 화면 밖에 있어서 반응이 없어 보인다.
    if (widget.services.length > old.services.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: widget.services.isEmpty
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.screenH,
                      bottom: AppSpacing.sm,
                    ),
                    child: Text(
                      '고른 구독 ${widget.services.length}개 · 눌러서 빼기',
                      style: theme.textTheme.labelMedium,
                    ),
                  ),
                  SizedBox(
                    height: _iconSize,
                    child: ListView.separated(
                      controller: _scroll,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenH,
                      ),
                      itemCount: widget.services.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final service = widget.services[index];
                        return GestureDetector(
                          onTap: () => widget.onRemove(service),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              ServiceIcon.fromCatalog(
                                service,
                                size: _iconSize,
                              ),
                              Positioned(
                                top: -2,
                                right: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(1),
                                  decoration: BoxDecoration(
                                    color: theme.scaffoldBackgroundColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.cancel,
                                    size: 14,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
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
