import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'a11y_constants.dart';

/// Named accent colors for map overlays. See DESIGN.md §2.
///
/// These category accents (airport, station types) live deliberately outside
/// the natural OSM tile palette so map-overlay UI reads as distinct from
/// terrain, per the Outside-the-Tile-Palette Rule.
class MapPalette {
  const MapPalette._();

  static const Color airport = Color(0xFF1565C0);
  static const Color majorStation = Color(0xFFE65100);
  static const Color commuterRail = Color(0xFF00695C);
  static const Color subway = Color(0xFF2E7D32);
  static const Color regionalStation = Color(0xFF607D8B);

  // Compass north arrow. Red is the universally-read north convention;
  // tokenized here as a deliberate Evening Palette exception, not a leak.
  static const Color compassNorth = Color(0xFFC62828);

  // Default home-pin fallback when a profile has no custom pin color set.
  // Evening Indigo from the brand palette.
  static const Color defaultPin = Color(0xFF3F51B5);

  // Thermal energy tokens
  static const Color thermalCore = Color(0xFFFF3B30);
  static const Color thermalCorona = Color(0xFFFF9500);
}

class AppTheme {
  // Brand Colors
  static const Color _brandColor = Color(0xFF3F51B5);
  static const Color _secondaryColor = Color(0xFFFF4081);

  // Standardized Text Theme
  static TextTheme _buildTextTheme(Color color) {
    return TextTheme(
      displayLarge: GoogleFonts.montserrat(
        fontSize: 57,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -0.25,
        height: 1.1,
      ),
      displayMedium: GoogleFonts.montserrat(
        fontSize: 45,
        fontWeight: FontWeight.w700,
        color: color,
      ),
      displaySmall: GoogleFonts.montserrat(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        color: color,
      ),
      headlineLarge: GoogleFonts.montserrat(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: color,
      ),
      headlineMedium: GoogleFonts.montserrat(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      headlineSmall: GoogleFonts.montserrat(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      titleLarge: GoogleFonts.montserrat(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: color,
      ),
      titleMedium: GoogleFonts.openSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 0.15,
      ),
      titleSmall: GoogleFonts.openSans(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: color,
        letterSpacing: 0.1,
      ),
      bodyLarge: GoogleFonts.openSans(
        fontSize: 16,
        fontWeight: FontWeight.w300,
        color: color,
        letterSpacing: 0.5,
        height: 1.5,
      ),
      bodyMedium: GoogleFonts.openSans(
        fontSize: 14,
        fontWeight: FontWeight.w300,
        color: color,
        letterSpacing: 0.25,
      ),
      bodySmall: GoogleFonts.openSans(
        fontSize: 12,
        fontWeight: FontWeight.w300,
        color: color,
        letterSpacing: 0.4,
      ),
      labelLarge: GoogleFonts.montserrat(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: color,
        letterSpacing: 0.1,
      ),
      labelMedium: GoogleFonts.montserrat(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: color,
        letterSpacing: 0.5,
      ),
      labelSmall: GoogleFonts.montserrat(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: color,
        letterSpacing: 0.5,
      ),
    );
  }

  // Light Theme
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: _brandColor,
          brightness: Brightness.light,
          secondary: _secondaryColor,
        ).copyWith(
          onSurface: Colors.black87,
          onPrimaryContainer: Colors.indigo.shade900,
          onSecondaryContainer: const Color(0xFF4D002B), // High contrast pink
        ),
    textTheme: _buildTextTheme(Colors.black87),
    iconTheme: const IconThemeData(color: Colors.black87, size: 24),
    scaffoldBackgroundColor: Colors.grey[50],
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: _brandColor,
      titleTextStyle: TextStyle(
        color: _brandColor,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: A11yConstants.minTouchSize,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: A11yConstants.minTouchSize),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: A11yConstants.minTouchSize),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: A11yConstants.minTouchSize),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _brandColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    ),
  );

  // Dark Theme
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: _brandColor,
          brightness: Brightness.dark,
          secondary: _secondaryColor,
        ).copyWith(
          onSurface: Colors.white,
          onPrimaryContainer: const Color(0xFFE8EAF6), // Indigo 50
          onSecondaryContainer: const Color(0xFFFFE1F0), // Pink 50
        ),
    textTheme: _buildTextTheme(Colors.white),
    iconTheme: const IconThemeData(color: Colors.white, size: 24),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: A11yConstants.minTouchSize,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: A11yConstants.minTouchSize),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: A11yConstants.minTouchSize),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: A11yConstants.minTouchSize),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _brandColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    ),
  );
}
