import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/catalog/catalog_service.dart';
import '../providers/app_providers.dart';

/// 서비스 아이콘 타일.
///
/// 앱스토어에서 받아온 512px 아이콘을 보여주고, 아직 못 받았거나 실패하면
/// 브랜드 색 타일에 첫 글자를 얹어 대신 보여준다. 레이아웃이 흔들리지
/// 않도록 세 상태 모두 같은 크기를 차지한다.
class ServiceIcon extends ConsumerWidget {
  const ServiceIcon({
    super.key,
    required this.name,
    required this.brandColor,
    this.serviceId,
    this.searchTerm,
    this.imageUrl,
    this.size = 56,
  });

  ServiceIcon.fromCatalog(CatalogService service, {super.key, this.size = 56})
    : name = service.name,
      brandColor = Color(service.brandColor),
      serviceId = service.id,
      searchTerm = service.searchTerm,
      imageUrl = null;

  final String name;
  final Color brandColor;
  final String? serviceId;
  final String? searchTerm;

  /// 이미 알고 있는 아이콘 URL. 있으면 조회를 건너뛴다.
  final String? imageUrl;

  final double size;

  double get _radius => size * 0.24;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final known = imageUrl;
    if (known != null) return _frame(_image(known));

    if (serviceId == null || searchTerm == null) return _frame(_fallback());

    final resolved = ref.watch(
      iconUrlProvider((serviceId: serviceId!, searchTerm: searchTerm!)),
    );

    return _frame(
      resolved.maybeWhen(
        data: (url) => url == null ? _fallback() : _image(url),
        orElse: _fallback,
      ),
    );
  }

  Widget _frame(Widget child) => SizedBox(
    width: size,
    height: size,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(_radius),
      child: child,
    ),
  );

  Widget _image(String url) => CachedNetworkImage(
    imageUrl: url,
    width: size,
    height: size,
    fit: BoxFit.cover,
    fadeInDuration: const Duration(milliseconds: 180),
    placeholder: (_, _) => _fallback(),
    errorWidget: (_, _, _) => _fallback(),
  );

  Widget _fallback() {
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first;
    return ColoredBox(
      color: brandColor,
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: _readableOn(brandColor),
            fontSize: size * 0.4,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  static Color _readableOn(Color background) =>
      background.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
}
