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

/// Refractive Glass material constants. See DESIGN.md §4–5 and the LLC
/// `refractive-glass.md` Tier 3 template.
///
/// The tint band is the load-bearing part. Below [tintMin] the surface stops
/// separating from what it floats over; above [tintMax] it stops reading as
/// glass and starts reading as a tinted card — the flat-UI register PRODUCT.md
/// lists as an anti-reference. Dark mode is where that ceiling matters most,
/// because DESIGN.md §6 asks for "pristine glass in a void", not dark blue
/// software.
///
/// Legibility in dark mode is therefore bought at the *edge*, not in the fill:
/// [edgeDark] carries more than [edgeLight] precisely because [tintDark] is
/// only marginally higher than [tintLight].
class MapGlass {
  const MapGlass._();

  /// Backdrop blur sigma. The LLC standard refractive look.
  static const double blurSigma = 20.0;

  /// Fill opacity band for the Tier 3 material. The *composed* value —
  /// base tint plus [sheen] — is what must stay inside it.
  static const double tintMin = 0.05;
  static const double tintMax = 0.15;

  /// Top-left lift that gives the surface a direction of light.
  static const double sheen = 0.03;

  /// Base fill per appearance.
  static const double tintLight = 0.10;
  static const double tintDark = 0.12;

  /// The precision edge (DESIGN.md §5).
  static const double edgeLight = 0.20;
  static const double edgeDark = 0.28;
  static const double edgeWidth = 0.5;

  /// Radii on the DESIGN.md scale: sm 8 / md 16 / lg 30.
  static const double radiusSm = 8.0;
  static const double radiusMd = 16.0;
  static const double radiusLg = 30.0;

  /// Selection inside glass chrome (DESIGN.md §5, Navigation): a background
  /// lift, never a solid colour fill. Dark carries more because a white lift
  /// on a dark pane reads weaker than a black lift on a light one.
  static const double selectionLiftDark = 0.15;
  static const double selectionLiftLight = 0.08;

  /// The selection lift resolved for [brightness].
  static Color selectionLift(Brightness brightness) {
    return brightness == Brightness.dark
        ? Colors.white.withValues(alpha: selectionLiftDark)
        : Colors.black.withValues(alpha: selectionLiftLight);
  }
}

/// LLC Interaction Physics — the constants in
/// `llc-standards/context/interaction-physics.md`, and the two-phase Thermal
/// Glow they drive.
///
/// The spec asks for three things that only fit together once you notice they
/// describe different parts of one gesture: a 50ms excitation, a 300ms
/// dissipation, and a spring for "all state returns" (DESIGN.md §6). The
/// spring is not the glow. Energy blooms and cools on a curve; the *surface*
/// is what yields under the touch and springs back.
class MapMotion {
  const MapMotion._();

  /// Phase 1 — the strike. Intent converts to energy.
  static const Duration excitation = Duration(milliseconds: 50);

  /// Phase 2 — the cooling cycle.
  static const Duration dissipation = Duration(milliseconds: 300);

  /// `interaction-physics.md` §Animation Curvature: velocity highest at the
  /// start, trailing off. Quart.out or Quint.out, and nothing else — the
  /// component previously used easeOutExpo, which is neither.
  static const Curve strike = Curves.easeOutQuart;

  static const double springMass = 1.0;
  static const double springStiffness = 180.0;
  static const double springDamping = 12.0;

  /// The return to neutral. Damping 12 against stiffness 180 sits at a ratio
  /// of ~0.45 — underdamped on purpose, so the surface arrives with one
  /// slight overshoot rather than easing to a stop. That overshoot is the
  /// "sharp, authoritative return" the spec asks for; a critically damped
  /// spring would read as soft.
  static const SpringDescription returnSpring = SpringDescription(
    mass: springMass,
    stiffness: springStiffness,
    damping: springDamping,
  );

  /// How far a surface yields under contact, as a fraction of its size.
  ///
  /// Small on purpose: these wrap 44pt controls and map pills, and PRODUCT.md
  /// asks for a precision instrument, not a toy. At 4% a 44pt control moves
  /// under two logical pixels — felt more than seen, which is the point.
  static const double pressDepth = 0.04;
}

/// The DESIGN.md spacing scale.
///
/// Layout reads as intentional when gaps come from a scale rather than from
/// whatever number looked right in the moment. Tight groups take [xs]–[sm];
/// distinct groups take [md]–[lg].
class MapSpacing {
  const MapSpacing._();

  static const double xs = 8.0;
  static const double sm = 16.0;
  static const double md = 24.0;
  static const double lg = 32.0;

  /// Interior padding for a full-surface glass panel — an empty state, a
  /// dialog body. Deliberately above [lg]: these panels earn their calm from
  /// the air around their content.
  static const double panel = 40.0;
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
