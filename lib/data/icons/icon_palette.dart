import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// 아이콘 이미지의 **가장자리 색**을 뽑아낸다.
///
/// 아이콘을 원으로 자를 때, 원을 이 색으로 먼저 칠하고 그 위에 아이콘 전체를
/// 축소해서 얹는다. 색이 아이콘 테두리와 같으니 이음매가 보이지 않고,
/// 아이콘은 한 조각도 잘리지 않는다.
///
/// 그냥 꽉 채워 자르면 로고가 가장자리까지 찬 아이콘은 잘려 나간다.
abstract final class IconPalette {
  /// 가장자리 몇 픽셀을 볼지. 작게 줄여서 읽으므로 2면 충분하다.
  static const _ringWidth = 2;
  static const _sampleSize = 24;

  static final _cache = <String, Color?>{};

  /// [url] 이미지의 테두리 대표색. 못 읽으면 null.
  static Future<Color?> edgeColor(String url) async {
    if (_cache.containsKey(url)) return _cache[url];

    final color = await _compute(url);
    _cache[url] = color;
    return color;
  }

  static Future<Color?> _compute(String url) async {
    try {
      // 화면에 띄울 때와 같은 캐시를 쓴다. 네트워크를 두 번 타지 않는다.
      final file = await DefaultCacheManager().getSingleFile(url);
      final bytes = await file.readAsBytes();

      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: _sampleSize,
        targetHeight: _sampleSize,
      );
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData();
      frame.image.dispose();
      codec.dispose();

      if (data == null) return null;
      return _averageRing(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  /// 바깥 테두리 픽셀들의 평균. 투명한 픽셀은 뺀다.
  static Color? _averageRing(Uint8List rgba) {
    var r = 0, g = 0, b = 0, count = 0;

    for (var y = 0; y < _sampleSize; y++) {
      for (var x = 0; x < _sampleSize; x++) {
        final onRing =
            x < _ringWidth ||
            y < _ringWidth ||
            x >= _sampleSize - _ringWidth ||
            y >= _sampleSize - _ringWidth;
        if (!onRing) continue;

        final i = (y * _sampleSize + x) * 4;
        if (rgba[i + 3] < 200) continue; // 투명한 가장자리는 무시

        r += rgba[i];
        g += rgba[i + 1];
        b += rgba[i + 2];
        count++;
      }
    }

    if (count == 0) return null;
    return Color.fromARGB(255, r ~/ count, g ~/ count, b ~/ count);
  }
}
