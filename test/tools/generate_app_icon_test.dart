@Tags(['tool'])
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 앱 아이콘을 그려서 PNG로 저장하는 도구.
///
/// 실행:
///   flutter test test/tools/generate_app_icon_test.dart
///
/// 결과: assets/icon/app_icon.png (1024x1024)
/// 이 파일을 flutter_launcher_icons 가 각 밀도로 변환한다.
///
/// 테스트로 만든 이유는 별도 도구 없이 Flutter 의 캔버스를 그대로 쓰기
/// 위해서다. 검증이 아니라 생성이 목적이라 `tool` 태그를 달아 일반
/// 테스트 실행에서 빼도 되게 했다.
void main() {
  test('앱 아이콘 PNG 생성', () async {
    const size = 1024.0;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    NinedogsIconPainter().paint(canvas, const Size(size, size));

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    expect(bytes, isNotNull);

    final file = File('assets/icon/app_icon.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());

    // 전경만 있는 버전도 만든다. 안드로이드 적응형 아이콘에서 쓴다.
    final fgRecorder = ui.PictureRecorder();
    final fgCanvas = Canvas(fgRecorder);
    NinedogsIconPainter(
      background: false,
      scale: 0.62,
    ).paint(fgCanvas, const Size(size, size));

    final fgImage = await fgRecorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final fgBytes = await fgImage.toByteData(format: ui.ImageByteFormat.png);
    await File(
      'assets/icon/app_icon_foreground.png',
    ).writeAsBytes(fgBytes!.buffer.asUint8List());
  });
}

/// Ninedogs 아이콘.
///
/// 검정 바탕에 도베르만 얼굴, 빨간 목걸이. 뒤에는 구독 서비스 타일을
/// 아주 흐리게 깔아 '구독 관리'라는 성격을 준다.
///
/// 작은 크기(48px)에서도 알아볼 수 있게 형태를 단순하게 유지한다.
/// 뒤 타일은 작아지면 사라지지만 그래도 괜찮다 — 주인공은 개다.
class NinedogsIconPainter {
  const NinedogsIconPainter({this.background = true, this.scale = 1.0});

  /// 검정 배경을 칠할지. 적응형 아이콘 전경 레이어에서는 끈다.
  final bool background;

  /// 개를 얼마나 키울지. 적응형 아이콘은 가장자리가 잘리므로 줄인다.
  final double scale;

  // 색
  static const _bg = Color(0xFF000000);
  static const _tile = Color(0xFF121214);
  static const _bodyTop = Color(0xFF44444C);
  static const _bodyBottom = Color(0xFF1E1E23);
  static const _rust = Color(0xFF9A5230);
  static const _collar = Color(0xFFE50914);
  static const _collarShade = Color(0xFF9E0610);
  static const _eye = Color(0xFFF7F7F9);
  static const _ink = Color(0xFF08080A);

  void paint(Canvas canvas, Size size) {
    final s = size.width;

    if (background) {
      canvas.drawRect(Offset.zero & size, Paint()..color = _bg);
      _paintTiles(canvas, s);
    }

    canvas.save();
    // 개를 화면 중앙 기준으로 확대·축소한다
    canvas.translate(s / 2, s / 2);
    canvas.scale(scale);
    canvas.translate(-s / 2, -s / 2);

    // 목 -> 목걸이 -> 머리 순서. 머리가 목걸이 위를 덮어야
    // 목걸이가 '목에 걸린' 것처럼 보인다.
    _paintNeck(canvas, s);
    _paintCollar(canvas, s);
    _paintHead(canvas, s);
    _paintFace(canvas, s);

    canvas.restore();
  }

  /// 뒤에 깔리는 구독 타일들. 개를 방해하지 않게 작고 어둡게, 가장자리 안쪽에.
  void _paintTiles(Canvas canvas, double s) {
    // (x, y, 크기, 살짝 섞을 색)
    const tiles = <(double, double, double, Color)>[
      (0.075, 0.115, 0.105, Color(0xFFE50914)),
      (0.240, 0.055, 0.085, Color(0xFF1DB954)),
      (0.820, 0.120, 0.105, Color(0xFF0A84FF)),
      (0.680, 0.055, 0.080, Color(0xFF9B51E0)),
      (0.070, 0.760, 0.095, Color(0xFFF2A93B)),
      (0.845, 0.755, 0.100, Color(0xFF00C4CC)),
      (0.230, 0.895, 0.075, Color(0xFF0A84FF)),
      (0.720, 0.900, 0.070, Color(0xFF1DB954)),
    ];

    for (final (cx, cy, w, tint) in tiles) {
      final side = w * s;
      final rect = Rect.fromCenter(
        center: Offset(cx * s, cy * s),
        width: side,
        height: side,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(side * 0.30)),
        Paint()..color = Color.alphaBlend(tint.withValues(alpha: 0.22), _tile),
      );
    }
  }

  /// 목. 머리 아래로 이어져야 목걸이가 걸릴 자리가 생긴다.
  void _paintNeck(Canvas canvas, double s) {
    final neck = Path()
      ..moveTo(0.405 * s, 0.700 * s)
      ..lineTo(0.372 * s, 0.930 * s)
      ..lineTo(0.628 * s, 0.930 * s)
      ..lineTo(0.595 * s, 0.700 * s)
      ..close();

    canvas.drawPath(
      neck,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0.5 * s, 0.70 * s),
          Offset(0.5 * s, 0.93 * s),
          const [_bodyBottom, Color(0xFF141418)],
        ),
    );
  }

  void _paintCollar(Canvas canvas, double s) {
    // 목을 감싸느라 아래로 살짝 처진 띠
    final band = Path()
      ..moveTo(0.360 * s, 0.792 * s)
      ..quadraticBezierTo(0.5 * s, 0.846 * s, 0.640 * s, 0.792 * s)
      ..lineTo(0.648 * s, 0.856 * s)
      ..quadraticBezierTo(0.5 * s, 0.912 * s, 0.352 * s, 0.856 * s)
      ..close();

    canvas.drawPath(band, Paint()..color = _collar);

    // 아래쪽 그늘
    canvas.save();
    canvas.clipPath(band);
    canvas.drawRect(
      Rect.fromLTWH(0.34 * s, 0.868 * s, 0.32 * s, 0.06 * s),
      Paint()..color = _collarShade,
    );
    canvas.restore();

    // 인식표
    final tagCenter = Offset(0.5 * s, 0.918 * s);
    canvas.drawCircle(tagCenter, 0.032 * s, Paint()..color = _collar);
    canvas.drawCircle(
      tagCenter,
      0.032 * s,
      Paint()
        ..color = _collarShade
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.006 * s,
    );
    canvas.drawCircle(
      Offset(tagCenter.dx, tagCenter.dy - 0.006 * s),
      0.011 * s,
      Paint()..color = _ink.withValues(alpha: 0.6),
    );
  }

  void _paintHead(Canvas canvas, double s) {
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0.5 * s, 0.12 * s),
        Offset(0.5 * s, 0.78 * s),
        const [_bodyTop, _bodyBottom],
      );

    // 귀 — 도베르만의 쫑긋한 삼각형. 실루엣의 핵심이라 크고 곧게.
    for (final left in [true, false]) {
      canvas.drawPath(_ear(s, left: left), paint);
      canvas.drawPath(
        _earInner(s, left: left),
        Paint()..color = _rust.withValues(alpha: 0.40),
      );
    }

    final head = _head(s);
    canvas.drawPath(head, paint);

    // 주둥이는 머리 안에서만 그린다. 밖으로 삐져나가면 상자처럼 보인다.
    canvas.save();
    canvas.clipPath(head);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0.5 * s, 0.648 * s),
        width: 0.205 * s,
        height: 0.195 * s,
      ),
      Paint()..color = _ink.withValues(alpha: 0.50),
    );

    // 왼쪽 가장자리에 빨간 반사광 — 검정 위 검정이라 형태가 묻히는 걸 막는다
    canvas.drawRect(
      Rect.fromLTWH(0.28 * s, 0.20 * s, 0.055 * s, 0.62 * s),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0.28 * s, 0),
          Offset(0.335 * s, 0),
          [_collar.withValues(alpha: 0.30), _collar.withValues(alpha: 0.0)],
        ),
    );
    canvas.restore();
  }

  Path _ear(double s, {required bool left}) {
    final dir = left ? -1.0 : 1.0;

    // 머리 옆면에 붙여서 시작한다. 떨어지면 뿔처럼 보인다.
    return Path()
      ..moveTo((0.5 + dir * 0.150) * s, 0.300 * s)
      ..lineTo((0.5 + dir * 0.232) * s, 0.062 * s)
      ..quadraticBezierTo(
        (0.5 + dir * 0.268) * s,
        0.052 * s,
        (0.5 + dir * 0.286) * s,
        0.108 * s,
      )
      ..lineTo((0.5 + dir * 0.262) * s, 0.420 * s)
      ..quadraticBezierTo(
        (0.5 + dir * 0.230) * s,
        0.400 * s,
        (0.5 + dir * 0.196) * s,
        0.352 * s,
      )
      ..close();
  }

  Path _earInner(double s, {required bool left}) {
    final dir = left ? -1.0 : 1.0;
    return Path()
      ..moveTo((0.5 + dir * 0.186) * s, 0.312 * s)
      ..lineTo((0.5 + dir * 0.248) * s, 0.116 * s)
      ..lineTo((0.5 + dir * 0.236) * s, 0.376 * s)
      ..close();
  }

  /// 앞에서 본 도베르만 머리는 위가 넓고 아래로 좁아지는 쐐기 모양이다.
  Path _head(double s) {
    return Path()
      // 왼쪽 관자놀이
      ..moveTo(0.300 * s, 0.400 * s)
      ..cubicTo(
        0.302 * s,
        0.268 * s,
        0.388 * s,
        0.208 * s,
        0.500 * s,
        0.208 * s,
      )
      ..cubicTo(
        0.612 * s,
        0.208 * s,
        0.698 * s,
        0.268 * s,
        0.700 * s,
        0.400 * s,
      )
      // 오른쪽 볼에서 주둥이까지 곧게 좁혀 내려간다
      ..cubicTo(
        0.700 * s,
        0.512 * s,
        0.652 * s,
        0.596 * s,
        0.614 * s,
        0.664 * s,
      )
      ..cubicTo(
        0.598 * s,
        0.730 * s,
        0.560 * s,
        0.768 * s,
        0.500 * s,
        0.768 * s,
      )
      ..cubicTo(
        0.440 * s,
        0.768 * s,
        0.402 * s,
        0.730 * s,
        0.386 * s,
        0.664 * s,
      )
      ..cubicTo(
        0.348 * s,
        0.596 * s,
        0.300 * s,
        0.512 * s,
        0.300 * s,
        0.400 * s,
      )
      ..close();
  }

  void _paintFace(Canvas canvas, double s) {
    // 눈썹 위 적갈색 반점 — 도베르만의 상징. 이게 있어야 견종이 읽힌다.
    for (final dir in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate((0.5 + dir * 0.112) * s, 0.392 * s);
      canvas.rotate(dir * -0.20);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: 0.098 * s,
          height: 0.046 * s,
        ),
        Paint()..color = _rust,
      );
      canvas.restore();
    }

    // 눈 — 안쪽 끝을 내려서 살짝 치켜뜬 눈매를 만든다.
    // 수평이면 순한 표정이 되고, 너무 기울이면 사나워 보인다.
    for (final dir in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate((0.5 + dir * 0.113) * s, 0.472 * s);
      canvas.rotate(dir * -0.24);

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: 0.096 * s,
          height: 0.062 * s,
        ),
        Paint()..color = _eye,
      );
      canvas.drawCircle(
        Offset(dir * 0.008 * s, 0.002 * s),
        0.024 * s,
        Paint()..color = _ink,
      );
      canvas.drawCircle(
        Offset(dir * 0.017 * s, -0.012 * s),
        0.008 * s,
        Paint()..color = Colors.white.withValues(alpha: 0.95),
      );
      canvas.restore();
    }

    // 코
    final nose = Path()
      ..moveTo(0.5 * s, 0.686 * s)
      ..cubicTo(
        0.556 * s,
        0.682 * s,
        0.560 * s,
        0.618 * s,
        0.500 * s,
        0.608 * s,
      )
      ..cubicTo(
        0.440 * s,
        0.618 * s,
        0.444 * s,
        0.682 * s,
        0.500 * s,
        0.686 * s,
      )
      ..close();
    canvas.drawPath(nose, Paint()..color = _ink);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0.484 * s, 0.632 * s),
        width: 0.026 * s,
        height: 0.014 * s,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.26),
    );

    // 입 — 무심한 듯 살짝 올라간 선. 이 각도가 '귀엽지만 간지나는' 지점.
    final mouth = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.013 * s
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(0.5 * s, 0.686 * s),
      Offset(0.5 * s, 0.716 * s),
      mouth,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(0.468 * s, 0.712 * s),
        width: 0.064 * s,
        height: 0.044 * s,
      ),
      0,
      math.pi * 0.62,
      false,
      mouth,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(0.532 * s, 0.712 * s),
        width: 0.064 * s,
        height: 0.044 * s,
      ),
      math.pi * 0.38,
      math.pi * 0.62,
      false,
      mouth,
    );
  }
}
