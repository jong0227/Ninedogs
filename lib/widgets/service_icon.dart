import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/catalog/catalog_service.dart';
import '../data/catalog/service_catalog.dart';
import '../data/models/subscription.dart';
import '../providers/app_providers.dart';

/// 서비스 아이콘. 테두리도 받침 테두리선도 없이 동그란 모양이다.
///
/// ## 잘리지도 않고, 이음매도 안 보이게
///
/// 아이콘을 그냥 원으로 오려내면 로고가 가장자리까지 찬 아이콘은 잘려 나간다.
/// 그렇다고 작게 넣으면 원본 배경이 링처럼 남아 지저분해진다.
///
/// 그래서 **아이콘의 가장자리 색을 뽑아 원 전체를 그 색으로 칠하고**, 그 위에
/// 아이콘 원본을 통째로 얹는다. 바깥 색이 아이콘 테두리와 같으니 경계가
/// 보이지 않고, 아이콘은 한 조각도 잘리지 않는다.
/// (대부분의 앱 아이콘은 배경이 단색이라 완전히 매끄럽게 이어진다)
///
/// 색을 아직 못 읽었으면 브랜드 색으로 채워 두고, 읽히면 부드럽게 바뀐다.
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

  /// 원형으로 자를지. false 면 모서리만 둥근 사각형.
  final bool circular;

  /// 아이콘 URL 캐시 키. 카탈로그에 없는 서비스도 이름으로 캐시해서
  /// 직접 추가한 구독도 목록에서 아이콘이 나온다.
  String get _cacheId {
    final id = serviceId;
    if (id != null && id.isNotEmpty) return id;
    return 'name:${name.trim()}';
  }

  String get _term => (searchTerm ?? name).trim();

  /// 정사각형이 원 안에 완전히 들어가는 한계는 지름의 70.7%(1/√2).
  /// 딱 그만큼 쓰면 네 귀퉁이가 원에 닿아 아슬아슬하므로 조금 줄인다.
  static const _fitRatio = 0.70;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url =
        imageUrl ??
        (_term.isEmpty
            ? null
            : ref
                  .watch(
                    iconUrlProvider((
                      serviceId: _cacheId,
                      searchTerm: _term,
                      domain: ServiceCatalog.domainOf(serviceId),
                    )),
                  )
                  .value);

    // 아이콘 테두리에서 뽑은 색. 아직 못 읽었으면 브랜드 색으로 버틴다.
    final edge = url == null
        ? null
        : ref.watch(iconEdgeColorProvider(url)).value;
    final fill = edge ?? brandColor;

    final inner = size * _fitRatio;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circular ? null : BorderRadius.circular(size * 0.26),
      ),
      child: url == null
          ? _monogram(context)
          : CachedNetworkImage(
              imageUrl: url,
              width: inner,
              height: inner,
              // contain + 클립 없음 = 아이콘이 잘리지 않는다.
              // 바깥은 위에서 칠한 테두리 색이라 이어져 보인다.
              fit: BoxFit.contain,
              fadeInDuration: const Duration(milliseconds: 180),
              placeholder: (_, _) => SizedBox(width: inner, height: inner),
              errorWidget: (_, _, _) => _monogram(context),
            ),
    );
  }

  /// 아이콘도 파비콘도 못 받았을 때의 마지막 수단.
  Widget _monogram(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first;

    return Text(
      initial,
      style: TextStyle(
        color: brandColor.computeLuminance() > 0.5
            ? Colors.black87
            : Colors.white,
        fontSize: size * 0.38,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
