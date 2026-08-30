import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'onboarding_parts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/catalog/catalog_service.dart';
import '../../data/catalog/service_catalog.dart';
import '../../data/models/subscription.dart';
import '../../providers/app_providers.dart';
import '../../providers/subscription_providers.dart';
import '../../widgets/service_browser.dart';
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
  final _drafts = <String, SubscriptionDraft>{};
  final _search = TextEditingController();

  String _query = '';
  bool _reviewing = false;

  /// 맨 처음 보여주는 앱 소개. "시작하기"를 누르면 고르기 단계로 넘어간다.
  bool _showIntro = true;

  /// 상위 상품에 포함돼서 0원으로 맞춘 것들. 아래에 안내로 보여준다.
  final _bundledNames = <String>[];

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
        _drafts[service.id] = SubscriptionDraft(service);
      }
      _applyBundleDefaults();
    });
  }

  /// 상위 상품까지 같이 고른 서비스는 0원 요금제로 맞춘다.
  ///
  /// 와우 멤버십과 쿠팡플레이를 둘 다 고르면 7,890원이 두 번 잡힌다.
  /// 여기서는 탭 몇 번으로 끝내는 흐름이라 창을 띄워 묻지 않고 조용히
  /// 맞춘 뒤 아래에 안내만 남긴다. 요금제는 다음 단계에서 바꿀 수 있다.
  void _applyBundleDefaults() {
    _bundledNames.clear();

    for (final draft in _drafts.values) {
      final parentId = draft.service.includedIn;
      if (parentId == null || !_selected.contains(parentId)) continue;

      final included = ServiceCatalog.includedPlanOf(draft.service);
      if (included == null) continue;

      draft.selectPlan(included);
      final parent = ServiceCatalog.byId(parentId);
      if (parent != null) {
        _bundledNames.add('${draft.service.name}은(는) ${parent.name}에 포함');
      }
    }
  }

  Future<void> _finish() async {
    final uuid = const Uuid();
    final subscriptions = _drafts.values.map(
      (draft) => Subscription.create(
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
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const AppShell()));
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
                const IntroPoint(
                  icon: Icons.grid_view_rounded,
                  title: '구독 한눈에 모아보기',
                  body: '넷플릭스부터 멜론까지, 아이콘으로 깔끔하게.',
                ),
                const IntroPoint(
                  icon: Icons.trending_up_rounded,
                  title: '누적 지출 자동 계산',
                  body: '앱별로, 전체로 지금까지 얼마 썼는지 알려줘요.',
                ),
                const IntroPoint(
                  icon: Icons.notifications_active_outlined,
                  title: '결제 전 미리 알림',
                  body: '결제일이 다가오면 며칠 전에 짚어드려요.',
                ),
                const IntroPoint(
                  icon: Icons.lock_outline,
                  title: '아이디·비밀번호 금고',
                  body: '서비스 계정 정보를 암호화해서 보관해요.',
                ),
                const IntroPoint(
                  icon: Icons.favorite_outline,
                  title: '배우자와 함께 보기',
                  body: '연결하면 같은 구독 목록을 함께 관리해요.',
                ),
              ],
            ),
          ),
        ),
        BottomBar(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton(
                onPressed: () => setState(() => _showIntro = false),
                child: const Text('시작하기'),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text('입력한 정보는 이 기기에 저장돼요', style: theme.textTheme.labelMedium),
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
        SelectedStrip(services: _selectedServices, onRemove: _toggle),
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
        BottomBar(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 번들로 묶인 게 있으면 그것부터 알려준다. 왜 0원으로
              // 잡혔는지 모르면 오히려 잘못된 줄 안다.
              if (_bundledNames.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.card_giftcard_outlined,
                        size: 14,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          '${_bundledNames.join(', ')}돼서 0원으로 잡았어요',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else if (_selected.isNotEmpty)
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
            itemBuilder: (context, index) => DraftCard(
              draft: drafts[index],
              onChanged: () => setState(() {}),
            ),
          ),
        ),
        BottomBar(
          child: FilledButton(onPressed: _finish, child: const Text('완료')),
        ),
      ],
    );
  }
}

/// 소개 화면의 기능 한 줄. 아이콘 + 제목 + 설명.
