import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/catalog/catalog_service.dart';
import '../../data/models/money.dart';
import '../../widgets/service_icon.dart';
import '../../widgets/app_date_picker.dart';
import '../../core/format/formatters.dart';

// 온보딩 화면을 이루는 조각들.
///
// 화면 본문(단계 흐름)과 부품을 한 파일에 두면 어느 쪽을 고치든
// 700줄을 훑어야 한다. 부품은 따로 둔다.

class IntroPoint extends StatelessWidget {
  const IntroPoint({
    super.key,
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

// 지금까지 고른 서비스를 작은 아이콘으로 늘어놓는 띠.
///
// 하나도 없으면 자리를 차지하지 않고, 고르는 순간 부드럽게 펼쳐진다.
// 아이콘을 누르면 선택이 풀린다 — 그리드에서 다시 찾아 누를 필요가 없다.
class SelectedStrip extends StatefulWidget {
  const SelectedStrip({
    super.key,
    required this.services,
    required this.onRemove,
  });

  final List<CatalogService> services;
  final ValueChanged<CatalogService> onRemove;

  @override
  State<SelectedStrip> createState() => SelectedStripState();
}

class SelectedStripState extends State<SelectedStrip> {
  final _scroll = ScrollController();

  static const _iconSize = 38.0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SelectedStrip oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 새로 고른 게 끝에 붙으므로 끝으로 밀어준다.
    // 안 그러면 방금 고른 게 화면 밖에 있어서 반응이 없어 보인다.
    if (widget.services.length > oldWidget.services.length) {
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
                              ServiceIcon.fromCatalog(service, size: _iconSize),
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
class SubscriptionDraft {
  SubscriptionDraft(this.service)
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

class DraftCard extends StatelessWidget {
  const DraftCard({super.key, required this.draft, required this.onChanged});

  final SubscriptionDraft draft;
  final VoidCallback onChanged;

  Future<void> _pickStartDate(BuildContext context) async {
    final picked = await pickDate(
      context,
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
                    PlanChip(
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

class PlanChip extends StatelessWidget {
  const PlanChip({
    super.key,
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

class BottomBar extends StatelessWidget {
  const BottomBar({super.key, required this.child});

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
