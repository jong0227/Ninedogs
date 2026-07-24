import 'dart:ui' as ui;

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
/// 그래서 두 겹으로 그린다.
///  - **뒤 겹**: 아이콘을 원에 꽉 채워(cover) 살짝 흐리게 깐다. 링(테두리)
///    부분이 아이콘 자기 배경으로 채워지므로, 디즈니+·네이버처럼 배경이
///    **그라데이션**이어도 그 방향 그대로 원 끝까지 이어진다.
///  - **앞 겹**: 아이콘 원본을 통째로(contain) 얹는다. 한 조각도 잘리지 않는다.
///
/// 예전엔 가장자리 평균색 하나로 원을 칠했는데, 그라데이션 아이콘은 위(진한 색)와
/// 아래(밝은 색)가 평균색과 둘 다 어긋나 네모 경계가 드러났다. 아이콘 자기
/// 픽셀을 위치별로 깔면 그 경계가 사라진다.
///
/// 이미지를 아직 못 받았으면 브랜드/가장자리 색으로 원을 채워 둔다.
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

  /// App Store 아트워크는 사각형 둘레에 얇은 회색 실선 테두리가 있다. 원으로
  /// 자르면 위·아래·좌·우 끝에서 그 실선이 흰 테두리처럼 드러난다. 이미지를
  /// 살짝 키워 그 실선을 원 밖으로 밀어낸다. 로고는 가운데 안전 영역이라 무관.
  static const _overscan = 1.06;

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
    // 꽉 찬(full-bleed) 아이콘은 원으로 잘라 채우므로 이 색이 거의 안 보이지만,
    // 로딩 중이나 투명 배경 파비콘에서는 바탕으로 쓰인다.
    final edge = url == null
        ? null
        : ref.watch(iconEdgeColorProvider(url)).value;
    final fill = edge ?? brandColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: size,
      height: size,
      alignment: Alignment.center,
      // 아이콘을 원(또는 둥근 사각형) 모양으로 잘라낸다.
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: fill,
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circular ? null : BorderRadius.circular(size * 0.26),
      ),
      child: url == null ? _monogram(context) : _image(context, url),
    );
  }

  /// App Store 아트워크는 배경이 네 변까지 꽉 찬 정사각형이라, 원에 **꽉 채워**
  /// (cover) 잘라내면 그라데이션이 원 끝까지 그대로 이어지고 사각 경계가
  /// 사라진다. 로고는 가운데 안전 영역에 있어 모서리만 잘려도 멀쩡하다.
  ///
  /// 파비콘은 배경이 없거나 로고가 가장자리까지 차 있어 cover 로 자르면 로고가
  /// 잘린다. 그래서 통째로(contain) 얹고, 빈 링은 아이콘을 흐리게 깐 배경으로
  /// 메워 색을 잇는다.
  bool _isFullBleed(String url) => url.contains('mzstatic');

  Widget _image(BuildContext context, String url) {
    if (_isFullBleed(url)) {
      // 살짝 키워(_overscan) 아트워크 둘레의 실선 테두리를 원 밖으로 밀어낸다.
      return Transform.scale(
        scale: _overscan,
        child: CachedNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          fadeInDuration: const Duration(milliseconds: 180),
          placeholder: (_, _) => SizedBox(width: size, height: size),
          errorWidget: (_, _, _) => _monogram(context),
        ),
      );
    }

    final inner = size * _fitRatio;
    return Stack(
      alignment: Alignment.center,
      children: [
        // 뒤 겹: 아이콘을 꽉 채워 흐리게. 색을 원 끝까지 잇는다.
        Positioned.fill(
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: size * 0.08,
              sigmaY: size * 0.08,
              tileMode: TileMode.clamp,
            ),
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 180),
              placeholder: (_, _) => const SizedBox.shrink(),
              errorWidget: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),
        // 앞 겹: 선명한 아이콘 원본. contain 이라 잘리지 않는다.
        CachedNetworkImage(
          imageUrl: url,
          width: inner,
          height: inner,
          fit: BoxFit.contain,
          fadeInDuration: const Duration(milliseconds: 180),
          placeholder: (_, _) => SizedBox(width: inner, height: inner),
          errorWidget: (_, _, _) => _monogram(context),
        ),
      ],
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
