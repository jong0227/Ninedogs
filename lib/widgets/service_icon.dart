import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/catalog/catalog_service.dart';
import '../data/catalog/service_catalog.dart';
import '../data/models/subscription.dart';
import '../providers/app_providers.dart';

/// 서비스 아이콘.
///
/// ## 아이콘은 절대 잘리지 않는다
///
/// 원(또는 둥근 사각형)은 아이콘을 오려내는 **마스크가 아니라 받침**이다.
/// 받침을 깔고 그 위에 아이콘 원본을 통째로 축소해서 얹는다.
///
/// - 정사각형이 원 안에 완전히 들어가는 한계는 지름의 70.7%(1/√2)다.
///   여기서는 64%만 쓰므로 사방에 여백이 남는다.
/// - 아이콘에는 `ClipRRect` 같은 잘라내는 처리를 **하지 않는다.**
///   `BoxFit.contain` 이라 가로세로 비율도 그대로 유지된다.
///
/// 이 구조 덕분에 로고가 모서리까지 꽉 찬 아이콘(워드마크형)도 안전하다.
class ServiceIcon extends ConsumerWidget {
  const ServiceIcon({
    super.key,
    required this.name,
    required this.brandColor,
    this.serviceId,
    this.searchTerm,
    this.imageUrl,
    this.size = 56,
    this.circular = true,
  });

  ServiceIcon.fromCatalog(
    CatalogService service, {
    super.key,
    this.size = 56,
    this.circular = true,
  }) : name = service.name,
       brandColor = Color(service.brandColor),
       serviceId = service.id,
       searchTerm = service.searchTerm,
       imageUrl = null;

  /// 구독에서 만든다. 카탈로그에 있는 서비스면 카탈로그의 검색어를 쓴다.
  /// 표시 이름('티빙')보다 카탈로그 검색어('TVING 티빙')가 아이콘을 더 잘 찾는다.
  factory ServiceIcon.forSubscription(
    Subscription subscription, {
    Key? key,
    double size = 56,
    bool circular = true,
  }) {
    final catalog = subscription.serviceId == null
        ? null
        : ServiceCatalog.byId(subscription.serviceId!);

    return ServiceIcon(
      key: key,
      name: subscription.name,
      brandColor: Color(
        subscription.brandColorValue ?? catalog?.brandColor ?? 0xFF6B7079,
      ),
      serviceId: subscription.serviceId,
      searchTerm: catalog?.searchTerm ?? subscription.name,
      imageUrl: subscription.iconUrl,
      size: size,
      circular: circular,
    );
  }

  final String name;
  final Color brandColor;
  final String? serviceId;
  final String? searchTerm;

  /// 이미 알고 있는 아이콘 URL. 있으면 조회를 건너뛴다.
  final String? imageUrl;

  final double size;

  /// 받침 모양. 원형이 기본이고, false 면 둥근 사각형 받침을 쓴다.
  /// 어느 쪽이든 아이콘 자체는 잘리지 않는다.
  final bool circular;

  /// 아이콘 URL 캐시 키. 카탈로그에 없는 서비스도 이름으로 캐시해서
  /// 직접 추가한 구독도 목록에서 아이콘이 나온다.
  String get _cacheId {
    final id = serviceId;
    if (id != null && id.isNotEmpty) return id;
    return 'name:${name.trim()}';
  }

  String get _term => (searchTerm ?? name).trim();

  /// 받침 지름 대비 아이콘 크기. 0.707 이 한계이므로 여백을 두고 0.64.
  static const _iconRatio = 0.64;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final url =
        imageUrl ??
        (_term.isEmpty
            ? null
            : ref
                  .watch(
                    iconUrlProvider((serviceId: _cacheId, searchTerm: _term)),
                  )
                  .value);

    // 브랜드 색을 아주 옅게만 깔아 서비스마다 다른 느낌을 주되,
    // 화면 전체가 알록달록해지지 않게 14%만 섞는다.
    final plate = Color.alphaBlend(
      brandColor.withValues(alpha: 0.14),
      theme.colorScheme.surface,
    );

    final inner = size * _iconRatio;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circular ? null : BorderRadius.circular(size * 0.28),
        color: plate,
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
      ),
      child: url == null
          ? _monogram(context, plate)
          : CachedNetworkImage(
              imageUrl: url,
              width: inner,
              height: inner,
              // contain + 클립 없음 = 아이콘의 어느 부분도 잘리지 않는다
              fit: BoxFit.contain,
              fadeInDuration: const Duration(milliseconds: 180),
              placeholder: (_, _) => _monogram(context, plate),
              errorWidget: (_, _, _) => _monogram(context, plate),
            ),
    );
  }

  /// 아이콘을 못 받았을 때 보여주는 첫 글자.
  Widget _monogram(BuildContext context, Color plate) {
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first;

    // 브랜드 색이 받침과 너무 비슷하면(예: 다크 모드의 검정 브랜드)
    // 글자가 묻히므로 기본 글자색으로 되돌린다.
    final gap =
        (brandColor.computeLuminance() - plate.computeLuminance()).abs();
    final color = gap < 0.15
        ? Theme.of(context).colorScheme.onSurface
        : brandColor;

    return Text(
      initial,
      style: TextStyle(
        color: color,
        fontSize: size * 0.34,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
