import 'package:flutter/material.dart';

class LanguageFlag extends StatelessWidget {
  const LanguageFlag({super.key, required this.countryCode, this.width = 30});

  final String countryCode;
  final double width;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, width * 0.67),
      painter: _FlagPainter(countryCode.toLowerCase()),
    );
  }
}

class _FlagPainter extends CustomPainter {
  const _FlagPainter(this.code);

  final String code;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)));

    switch (code) {
      case 'br':
        _paintBrazil(canvas, size);
      case 'us':
        _paintUnitedStates(canvas, size);
      case 'es':
        _horizontal(
          canvas,
          size,
          [
            const Color(0xFFC60B1E),
            const Color(0xFFFFC400),
            const Color(0xFFC60B1E),
          ],
          [0.25, 0.5, 0.25],
        );
      case 'fr':
        _vertical(canvas, size, const [
          Color(0xFF0055A4),
          Colors.white,
          Color(0xFFEF4135),
        ]);
      case 'it':
        _vertical(canvas, size, const [
          Color(0xFF009246),
          Colors.white,
          Color(0xFFCE2B37),
        ]);
      case 'de':
        _horizontal(canvas, size, const [
          Colors.black,
          Color(0xFFD00),
          Color(0xFFFFCE00),
        ]);
      case 'jp':
        canvas.drawRect(rect, Paint()..color = Colors.white);
        canvas.drawCircle(
          Offset(size.width / 2, size.height / 2),
          size.height * 0.29,
          Paint()..color = const Color(0xFFBC002D),
        );
      case 'kr':
        _paintKorea(canvas, size);
      default:
        canvas.drawRect(rect, Paint()..color = const Color(0xFFB8B8B8));
    }

    canvas.restore();
    final border = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(0.35), const Radius.circular(3)),
      border,
    );
  }

  void _vertical(Canvas canvas, Size size, List<Color> colors) {
    final paint = Paint();
    final width = size.width / colors.length;
    for (var i = 0; i < colors.length; i++) {
      paint.color = colors[i];
      canvas.drawRect(
        Rect.fromLTWH(i * width, 0, width + 0.5, size.height),
        paint,
      );
    }
  }

  void _horizontal(
    Canvas canvas,
    Size size,
    List<Color> colors, [
    List<double>? weights,
  ]) {
    final paint = Paint();
    final values =
        weights ?? List<double>.filled(colors.length, 1 / colors.length);
    var top = 0.0;
    for (var i = 0; i < colors.length; i++) {
      final height = size.height * values[i];
      paint.color = colors[i];
      canvas.drawRect(Rect.fromLTWH(0, top, size.width, height + 0.5), paint);
      top += height;
    }
  }

  void _paintBrazil(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF009B3A),
    );
    final center = Offset(size.width / 2, size.height / 2);
    final diamond = Path()
      ..moveTo(center.dx, 1)
      ..lineTo(size.width - 2, center.dy)
      ..lineTo(center.dx, size.height - 1)
      ..lineTo(2, center.dy)
      ..close();
    canvas.drawPath(diamond, Paint()..color = const Color(0xFFFFDF00));
    canvas.drawCircle(
      center,
      size.height * 0.27,
      Paint()..color = const Color(0xFF002776),
    );
  }

  void _paintUnitedStates(Canvas canvas, Size size) {
    _horizontal(canvas, size, const [
      Color(0xFFB22234),
      Colors.white,
      Color(0xFFB22234),
      Colors.white,
      Color(0xFFB22234),
      Colors.white,
      Color(0xFFB22234),
      Colors.white,
      Color(0xFFB22234),
      Colors.white,
      Color(0xFFB22234),
      Colors.white,
      Color(0xFFB22234),
    ]);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width * 0.42, size.height * 0.54),
      Paint()..color = const Color(0xFF3C3B6E),
    );
  }

  void _paintKorea(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(
      center,
      size.height * 0.28,
      Paint()..color = const Color(0xFFCD2E3A),
    );
    canvas.drawCircle(
      Offset(center.dx, center.dy + size.height * 0.08),
      size.height * 0.20,
      Paint()..color = const Color(0xFF0047A0),
    );
  }

  @override
  bool shouldRepaint(covariant _FlagPainter oldDelegate) =>
      oldDelegate.code != code;
}
