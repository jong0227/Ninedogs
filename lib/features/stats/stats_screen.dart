import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'stats_sections.dart';
import '../../core/theme/app_spacing.dart';
import '../../widgets/category_colors.dart';
import '../../providers/stats_providers.dart';
import '../../widgets/ninedogs_app_bar.dart';

/// 어느 분야에 얼마나 쓰는지 보여주는 화면.
///
/// 색은 빨강 하나의 투명도만 바꿔서 쓴다. 분야마다 다른 색을 쓰면
/// 화면이 알록달록해지고, 순서(많이 쓰는 순)도 색으로 읽히지 않는다.
class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  /// 펼쳐놓은 분야. 라벨로 구분한다.
  final _expanded = <String>{};

  StatsMode _mode = StatsMode.monthly;

  bool get _isLifetime => _mode == StatsMode.lifetime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spends = _isLifetime
        ? ref.watch(categoryLifetimeProvider)
        : ref.watch(categorySpendProvider);
    final total = _isLifetime
        ? ref.watch(categoryLifetimeTotalProvider)
        : ref.watch(categoryTotalProvider);

    return Scaffold(
      appBar: const NinedogsAppBar(section: '구독 분석'),
      body: spends.isEmpty
          ? const EmptyStats()
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.sm,
                AppSpacing.screenH,
                AppSpacing.xxl,
              ),
              children: [
                // 지금 뭔가 해볼 수 있는 것부터 보여준다. 숫자를 늘어놓는 것보다
                // "합치면 얼마 아껴요" 한 줄이 실제로 행동을 바꾼다.
                const InsightSection(),
                ModeToggle(
                  mode: _mode,
                  onChanged: (mode) => setState(() => _mode = mode),
                ),
                const SizedBox(height: AppSpacing.xl),
                TotalHeader(
                  total: total,
                  count: _countAll(spends),
                  mode: _mode,
                ),
                const SizedBox(height: AppSpacing.xl),
                CompositionBar(
                  spends: spends,
                  total: total,
                  lifetime: _isLifetime,
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('분야별', style: theme.textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.md),
                for (final spend in spends)
                  CategoryRow(
                    spend: spend,
                    total: total,
                    color: CategoryColors.of(spend.category),
                    lifetime: _isLifetime,
                    expanded: _expanded.contains(spend.label),
                    onTap: () => setState(() {
                      if (!_expanded.remove(spend.label)) {
                        _expanded.add(spend.label);
                      }
                    }),
                  ),
              ],
            ),
    );
  }

  static int _countAll(List<CategorySpend> spends) =>
      spends.fold(0, (sum, spend) => sum + spend.count);
}

/// 눈여겨볼 것들. 없으면 자리를 차지하지 않는다.
