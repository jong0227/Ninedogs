import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../data/catalog/catalog_service.dart';
import '../data/catalog/service_catalog.dart';
import 'service_icon.dart';

/// 서비스를 분야별로 묶어 보여주는 그리드.
///
/// 위쪽 분야 칩은 **필터가 아니라 목차**다. 누르면 그 분야로 스크롤만 하고
/// 나머지 분야도 그대로 남아 있어서, 이동한 뒤에도 위아래로 훑어볼 수 있다.
/// 반대로 손으로 스크롤하면 지금 보고 있는 분야가 칩에 표시된다.
///
/// 검색 중일 때는 분야 구분 없이 결과만 펼친다.
class ServiceBrowser extends StatefulWidget {
  const ServiceBrowser({
    super.key,
    required this.onTap,
    this.query = '',
    this.selectedIds = const {},
    this.bottomPadding = AppSpacing.xxl,
  });

  final ValueChanged<CatalogService> onTap;

  /// 검색어. 비어 있지 않으면 분야 구분 없이 결과만 보여준다.
  final String query;

  /// 선택 표시를 할 서비스들. 비어 있으면 선택 표시를 하지 않는다.
  final Set<String> selectedIds;

  final double bottomPadding;

  @override
  State<ServiceBrowser> createState() => _ServiceBrowserState();
}

class _ServiceBrowserState extends State<ServiceBrowser> {
  final _scroll = ScrollController();
  final _chipKeys = <ServiceCategory, GlobalKey>{
    for (final category in ServiceCategory.values) category: GlobalKey(),
  };

  /// 분야별 스크롤 시작 위치. 화면 폭이 정해져야 계산할 수 있다.
  List<double> _offsets = const [];
  int _activeIndex = 0;

  /// 내가 눌러서 움직이는 중에는 스크롤 감지를 잠시 끈다.
  /// 안 그러면 지나치는 분야들이 순간적으로 활성 표시된다.
  bool _jumping = false;

  // 그리드 규격. 스크롤 위치를 미리 계산하려면 고정값이어야 한다.
  static const _columns = 4;
  static const _aspectRatio = 0.68;
  static const _crossSpacing = AppSpacing.md;
  static const _mainSpacing = AppSpacing.lg;
  static const _headerHeight = 54.0;
  static const _sectionGap = AppSpacing.lg;

  List<ServiceCategory> get _categories => ServiceCategory.values;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  /// 각 분야가 시작하는 스크롤 위치를 미리 구한다.
  /// 그리드가 지연 생성이라 실제로 그려지기 전에는 위치를 물어볼 수 없어서,
  /// 규격이 고정이라는 점을 이용해 직접 계산한다.
  void _measure(double width) {
    final cellWidth =
        (width - AppSpacing.screenH * 2 - _crossSpacing * (_columns - 1)) /
        _columns;
    final cellHeight = cellWidth / _aspectRatio;

    final offsets = <double>[];
    var running = 0.0;

    for (final category in _categories) {
      offsets.add(running);

      final count = ServiceCatalog.byCategory(category).length;
      final rows = (count / _columns).ceil();
      final gridHeight = rows <= 0
          ? 0.0
          : rows * cellHeight + (rows - 1) * _mainSpacing;

      running += _headerHeight + gridHeight + _sectionGap;
    }

    _offsets = offsets;
  }

  void _onScroll() {
    if (_jumping || _offsets.isEmpty) return;

    // 헤더가 화면 위쪽에 걸치는 순간 그 분야로 넘어간 것으로 본다
    final position = _scroll.offset + _headerHeight;

    var index = 0;
    for (var i = 0; i < _offsets.length; i++) {
      if (_offsets[i] <= position) index = i;
    }

    if (index != _activeIndex) {
      setState(() => _activeIndex = index);
      _revealChip(index);
    }
  }

  /// 활성 칩이 화면 밖이면 칩 목록도 따라 움직인다.
  void _revealChip(int index) {
    final context = _chipKeys[_categories[index]]?.currentContext;
    if (context == null) return;

    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      alignment: 0.5,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
    );
  }

  Future<void> _jumpTo(int index) async {
    if (_offsets.isEmpty || !_scroll.hasClients) return;

    setState(() {
      _activeIndex = index;
      _jumping = true;
    });
    _revealChip(index);

    final target = _offsets[index].clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    await _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );

    if (mounted) setState(() => _jumping = false);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.query.trim().isNotEmpty) {
      return _buildFlat(ServiceCatalog.search(widget.query));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        _measure(constraints.maxWidth);

        return Column(
          children: [
            _CategoryTabs(
              categories: _categories,
              activeIndex: _activeIndex,
              keys: _chipKeys,
              onTap: _jumpTo,
            ),
            Expanded(
              child: CustomScrollView(
                controller: _scroll,
                slivers: [
                  for (final category in _categories) ...[
                    SliverToBoxAdapter(
                      child: _SectionHeader(
                        category: category,
                        count: ServiceCatalog.byCategory(category).length,
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenH,
                      ),
                      sliver: _grid(ServiceCatalog.byCategory(category)),
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: _sectionGap),
                    ),
                  ],
                  SliverToBoxAdapter(
                    child: SizedBox(height: widget.bottomPadding),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFlat(List<CatalogService> services) {
    if (services.isEmpty) return const SizedBox.shrink();

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.lg,
            AppSpacing.screenH,
            widget.bottomPadding,
          ),
          sliver: _grid(services),
        ),
      ],
    );
  }

  Widget _grid(List<CatalogService> services) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _columns,
        mainAxisSpacing: _mainSpacing,
        crossAxisSpacing: _crossSpacing,
        childAspectRatio: _aspectRatio,
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        final service = services[index];
        return ServiceTile(
          service: service,
          selected: widget.selectedIds.contains(service.id),
          onTap: () => widget.onTap(service),
        );
      }, childCount: services.length),
    );
  }
}

class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({
    required this.categories,
    required this.activeIndex,
    required this.keys,
    required this.onTap,
  });

  final List<ServiceCategory> categories;
  final int activeIndex;
  final Map<ServiceCategory, GlobalKey> keys;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 44,
      // ListView 대신 Row 를 쓴다. 모든 칩이 만들어져 있어야
      // 화면 밖 칩으로도 자동 스크롤할 수 있다.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
        child: Row(
          children: [
            for (var i = 0; i < categories.length; i++)
              Padding(
                key: keys[categories[i]],
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: GestureDetector(
                  onTap: () => onTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: i == activeIndex
                          ? AppColors.accent
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: i == activeIndex
                            ? AppColors.accent
                            : theme.dividerColor,
                      ),
                    ),
                    child: Text(
                      categories[i].label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: i == activeIndex
                            ? AppColors.onAccent
                            : theme.textTheme.labelMedium?.color,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.category, required this.count});

  final ServiceCategory category;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 54,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.lg,
          AppSpacing.screenH,
          AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(category.label, style: theme.textTheme.headlineSmall),
            const SizedBox(width: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text('$count', style: theme.textTheme.labelMedium),
            ),
          ],
        ),
      ),
    );
  }
}

/// 그리드 한 칸. 동그란 아이콘과 이름, 선택되면 빨간 링과 체크.
class ServiceTile extends StatelessWidget {
  const ServiceTile({
    super.key,
    required this.service,
    required this.onTap,
    this.selected = false,
  });

  final CatalogService service;
  final VoidCallback onTap;
  final bool selected;

  static void _showHint(BuildContext context, CatalogService service) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(service.name),
        content: Text(service.pickerHint!),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final diameter = constraints.maxWidth;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 고르지 않았을 때도 링 두께만큼 자리를 비워둬서
                    // 선택할 때 크기가 튀지 않는다.
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: diameter,
                      height: diameter,
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? AppColors.accent
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: ServiceIcon.fromCatalog(
                        service,
                        size: diameter - 10,
                      ),
                    ),
                    if (selected)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.scaffoldBackgroundColor,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 11,
                            color: AppColors.onAccent,
                          ),
                        ),
                      ),
                    // 헷갈릴 만한 서비스만 안내를 단다 (예: 쿠팡플레이 스포츠패스).
                    // 바깥 GestureDetector 위에 얹히지만 자기 몫의 탭은 자기가
                    // 가져가므로 눌러도 서비스가 선택되지 않는다.
                    if (service.pickerHint != null)
                      Positioned(
                        top: -4,
                        left: -4,
                        child: GestureDetector(
                          onTap: () => _showHint(context, service),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.scaffoldBackgroundColor,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.question_mark,
                              size: 10,
                              color: theme.textTheme.labelMedium?.color,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Flexible(
            child: Text(
              service.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                height: 1.2,
                color: selected
                    ? theme.colorScheme.onSurface
                    : theme.textTheme.labelMedium?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
