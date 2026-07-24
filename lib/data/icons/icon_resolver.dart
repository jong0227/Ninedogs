import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 서비스 이름으로 고해상도 앱 아이콘 URL을 찾아온다.
///
/// 애플 App Store 검색 API를 쓴다. 키가 필요 없고 512px 원본을 주기 때문에
/// 파비콘(보통 32~64px)보다 화질이 훨씬 좋다. 한 번 찾은 URL은 로컬에
/// 캐시해서 앱을 켤 때마다 네트워크를 타지 않게 한다.
class IconResolver {
  IconResolver({http.Client? client, SharedPreferences? prefs})
    : _client = client ?? http.Client() {
    _prefs = prefs;
  }

  final http.Client _client;
  SharedPreferences? _prefs;

  final Map<String, String?> _memoryCache = {};

  static const _keyPrefix = 'icon_url:';
  static const _stampPrefix = 'icon_ts:';
  static const _cacheTtl = Duration(days: 30);
  static const _country = 'kr';

  /// [searchTerm] 에 해당하는 아이콘 URL. 못 찾으면 null.
  ///
  /// App Store 검색이 실패하면 [domain] 의 파비콘으로 넘어간다.
  /// 화질은 떨어지지만 첫 글자만 보여주는 것보다 훨씬 알아보기 쉽다.
  Future<String?> resolve(
    String serviceId,
    String searchTerm, {
    String? domain,
  }) async {
    if (_memoryCache.containsKey(serviceId)) return _memoryCache[serviceId];

    final cached = await _readCache(serviceId);
    if (cached != null) {
      _memoryCache[serviceId] = cached;
      return cached;
    }

    final url = await _lookup(searchTerm) ?? faviconUrl(domain);
    _memoryCache[serviceId] = url;
    if (url != null) await _writeCache(serviceId, url);
    return url;
  }

  /// 도메인 파비콘 주소. PNG 로 돌려주는 구글 서비스를 쓴다.
  /// (.ico 를 주는 곳들은 플러터가 디코딩하지 못한다)
  static String? faviconUrl(String? domain) {
    if (domain == null || domain.isEmpty) return null;
    return 'https://www.google.com/s2/favicons?domain=$domain&sz=128';
  }

  Future<String?> _lookup(String searchTerm) async {
    final uri = Uri.https('itunes.apple.com', '/search', {
      'term': searchTerm,
      'country': _country,
      'entity': 'software',
      'limit': '1',
    });

    try {
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map<String, Object?>) return null;

      final results = body['results'];
      if (results is! List || results.isEmpty) return null;

      final first = results.first;
      if (first is! Map<String, Object?>) return null;

      final artwork =
          first['artworkUrl512'] as String? ??
          first['artworkUrl100'] as String? ??
          first['artworkUrl60'] as String?;
      return artwork == null ? null : upscale(artwork);
    } catch (_) {
      // 네트워크가 없거나 응답이 이상하면 그냥 대체 아이콘으로 넘어간다.
      return null;
    }
  }

  /// App Store 아트워크 URL은 크기가 경로에 박혀 있다. 512로 올린다.
  static String upscale(String url) =>
      url.replaceFirst(RegExp(r'/\d+x\d+bb'), '/512x512bb');

  Future<SharedPreferences> get _preferences async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<String?> _readCache(String serviceId) async {
    final prefs = await _preferences;
    final stamp = prefs.getInt('$_stampPrefix$serviceId');
    if (stamp == null) return null;

    final age = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(stamp),
    );
    if (age > _cacheTtl) return null;

    return prefs.getString('$_keyPrefix$serviceId');
  }

  Future<void> _writeCache(String serviceId, String url) async {
    final prefs = await _preferences;
    await prefs.setString('$_keyPrefix$serviceId', url);
    await prefs.setInt(
      '$_stampPrefix$serviceId',
      DateTime.now().millisecondsSinceEpoch,
    );
  }
}
