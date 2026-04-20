import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class KineticStyles {
  // Colors
  static const Color background = Color(0xFF0E0E13);
  static const Color surface = Color(0xFF19191F);
  static const Color surfaceVariant = Color(0xFF25252D);
  static const Color primary = Color(0xFF81ECFF);
  static const Color primaryContainer = Color(0xFF00E3FD);
  static const Color secondary = Color(0xFFAC89FF);
  static const Color outlineVariant = Color(0x2648474D); // 15% opacity
  static const Color error = Color(0xFFFF716C);
  static const Color onSurfaceVariant = Color(0xFFA1A1AA);

  // Typography
  static TextStyle headline(double size, {Color color = Colors.white, FontWeight weight = FontWeight.w500}) {
    return GoogleFonts.spaceGrotesk(
      fontSize: size,
      color: color,
      fontWeight: weight,
      letterSpacing: -0.5,
    );
  }

  static TextStyle body(double size, {Color color = Colors.white, FontWeight weight = FontWeight.w400}) {
    return GoogleFonts.inter(
      fontSize: size,
      color: color,
      fontWeight: weight,
    );
  }

  static TextStyle label(double size, {Color color = Colors.white, FontWeight weight = FontWeight.w500}) {
    return GoogleFonts.inter(
      fontSize: size,
      color: color,
      fontWeight: weight,
      letterSpacing: 1.2,
    );
  }

  // Glass Decoration
  static BoxDecoration glassDecoration({
    Color color = surfaceVariant,
    double opacity = 0.4,
    double borderRadius = 12,
    bool hasBorder = true,
  }) {
    return BoxDecoration(
      color: color.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: hasBorder ? Border.all(color: outlineVariant, width: 1) : null,
    );
  }
}
