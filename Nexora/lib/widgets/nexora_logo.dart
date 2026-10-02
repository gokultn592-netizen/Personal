import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The official minimal premium Nexora Logo.
///
/// Icon: Bold geometric letter N where the diagonal stroke doubles as a verification checkmark.
/// Colors: Electric Cobalt (#4F8BFF) with Purple (#9D4EDD) checkmark accent.
/// Background: Dark Obsidian (#0B0F14).
/// Wordmark: NEXORA (Inter Bold, all caps, wide letter spacing).
/// Subtitle: NEXT ERA (JetBrains Mono small caps in slate gray).
class NexoraLogo extends StatelessWidget {
  final double size;
  final bool showWordmark;
  final bool showSubtitle;
  final bool useAssetImage;

  const NexoraLogo({
    super.key,
    this.size = 64,
    this.showWordmark = true,
    this.showSubtitle = true,
    this.useAssetImage = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!showWordmark) {
      return _iconMark();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _iconMark(),
        SizedBox(height: size * 0.24),
        Text(
          'NEXORA',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: size * 0.42,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 4.5,
            height: 1.0,
          ),
        ),
        if (showSubtitle) ...[
          SizedBox(height: size * 0.12),
          Text(
            'NEXT ERA',
            textAlign: TextAlign.center,
            style: GoogleFonts.jetBrainsMono(
              fontSize: size * 0.16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF94A3B8),
              letterSpacing: 3.2,
            ),
          ),
        ],
      ],
    );
  }

  Widget _iconMark() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        'assets/images/nexora_icon.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _vectorMark(),
      ),
    );
  }

  Widget _vectorMark() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF0B0F14),
        borderRadius: BorderRadius.circular(size * 0.24),
        border: Border.all(
          color: const Color(0xFF1E2633),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F8BFF).withValues(alpha: 0.16),
            blurRadius: size * 0.35,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: SizedBox(
          width: size * 0.65,
          height: size * 0.65,
          child: CustomPaint(
            painter: _NexoraMarkPainter(),
          ),
        ),
      ),
    );
  }
}

/// Precise geometric custom painter for the letter N + Checkmark combination mark.
class _NexoraMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final strokeWidth = w * 0.19;

    // Shift canvas slightly right for visual balance (checkmark extends right)
    canvas.translate(w * 0.06, 0);

    // Upright stroke 1: Left vertical pillar (Electric Cobalt #4F8BFF)
    final leftPillar = Paint()
      ..color = const Color(0xFF4F8BFF)
      ..style = PaintingStyle.fill;

    final leftRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, strokeWidth, h),
      Radius.circular(strokeWidth * 0.35),
    );
    canvas.drawRRect(leftRect, leftPillar);

    // Upright stroke 2: Right vertical pillar lower stem (Electric Cobalt)
    final rightRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w - strokeWidth, h * 0.38, strokeWidth, h * 0.62),
      Radius.circular(strokeWidth * 0.35),
    );
    canvas.drawRRect(rightRect, leftPillar);

    // Diagonal Checkmark Stroke (Purple #9D4EDD with subtle gradient)
    final checkmarkPath = Path();
    // Start of checkmark dip from left pillar
    checkmarkPath.moveTo(strokeWidth * 0.7, h * 0.44);
    // Tip of checkmark at bottom center
    checkmarkPath.lineTo(w * 0.42, h * 0.82);
    // Extended high checkmark tail doubling as the diagonal & extending up-right
    checkmarkPath.lineTo(w * 0.85, h * 0.15);

    final checkmarkPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 1.05
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.miter
      ..shader = const LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [
          Color(0xFF9D4EDD), // Electric Purple
          Color(0xFFC77DFF), // Radiant Violet accent
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(checkmarkPath, checkmarkPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
