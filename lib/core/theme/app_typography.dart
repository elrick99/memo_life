import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Font pairing ported from `resources/css/app.css`: Inter for body text,
/// Poppins (500-800) for headings/display, matching the web app exactly.
class AppTypography {
  const AppTypography._();

  static TextTheme textTheme(Color foreground) {
    final base = GoogleFonts.interTextTheme();
    final display = GoogleFonts.poppinsTextTheme();

    return base
        .copyWith(
          displayLarge: display.displayLarge,
          displayMedium: display.displayMedium,
          displaySmall: display.displaySmall,
          headlineLarge: display.headlineLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          headlineMedium: display.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          headlineSmall: display.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          titleLarge: display.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          titleMedium: display.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          titleSmall: display.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        )
        .apply(bodyColor: foreground, displayColor: foreground);
  }
}
