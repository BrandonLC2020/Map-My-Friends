import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_my_friends/utils/app_theme.dart';

/// Conformance tests for the app theme.
///
/// DESIGN.md §4 rejects traditional drop shadows outright and resolves depth
/// through refraction; §6 repeats the ban. The theme nonetheless shipped
/// `elevation: 2` on every ElevatedButton and every Card in both appearances —
/// a Material default leaking through rather than a decision this system made.
/// It survived an audit because Material spells a drop shadow as a number, not
/// as a BoxShadow, so grepping for the shadow never found it.

const _themes = <String, bool>{'light': false, 'dark': true};

/// Reads the applied theme from a live tree.
///
/// AppTheme resolves its faces through google_fonts, which reaches into the
/// binding at construction time, so the theme has to be exercised the way the
/// app exercises it rather than poked at statically.
Future<ThemeData> _theme(WidgetTester tester, bool dark) async {
  late ThemeData applied;
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      home: Builder(
        builder: (context) {
          applied = Theme.of(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return applied;
}

void main() {
  // AppTheme builds its TextTheme through google_fonts at static-init time,
  // which reaches into ServicesBinding. See the report: the brand faces are
  // fetched at runtime rather than bundled.

  _themes.forEach((name, dark) {
    group(name, () {
      testWidgets('buttons are flat', (tester) async {
        final style = (await _theme(tester, dark)).elevatedButtonTheme.style!;
        expect(
          style.elevation!.resolve(const <WidgetState>{}),
          0,
          reason: 'a raised button is a cast shadow, which DESIGN.md §6 bans',
        );
      });

      testWidgets('buttons sit on the radius scale at rounded.sm', (
        tester,
      ) async {
        final theme = await _theme(tester, dark);
        final shape =
            theme.elevatedButtonTheme.style!.shape!.resolve(
                  const <WidgetState>{},
                )!
                as RoundedRectangleBorder;

        // DESIGN.md components.button-thermal: rounded.sm.
        expect(shape.borderRadius, BorderRadius.circular(8));
      });

      testWidgets('cards declare depth as an edge, never a shadow', (
        tester,
      ) async {
        final card = (await _theme(tester, dark)).cardTheme;
        expect(card.elevation, 0);

        final shape = card.shape! as RoundedRectangleBorder;
        expect(
          shape.side.style,
          BorderStyle.solid,
          reason:
              'with the shadow gone a card needs a hairline to separate from '
              'the surface behind it — declare elevation once, as an edge',
        );
        expect(shape.borderRadius, BorderRadius.circular(16));
      });

      testWidgets('inputs share the radius of the controls beside them', (
        tester,
      ) async {
        final border =
            (await _theme(tester, dark)).inputDecorationTheme.border!
                as OutlineInputBorder;
        expect(border.borderRadius, BorderRadius.circular(8));
      });

      testWidgets('app bar titles carry the display face', (tester) async {
        final theme = await _theme(tester, dark);
        // Light overrode this with a raw TextStyle, which silently dropped
        // Montserrat and set a size dark did not share. Both now resolve to
        // titleLarge's geometry.
        final title =
            theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge!;

        expect(title.fontFamily, contains('Montserrat'));
        expect(title.fontSize, theme.textTheme.titleLarge!.fontSize);
        expect(title.fontWeight, FontWeight.w700);
      });

      testWidgets('touch targets meet the documented minimum', (tester) async {
        final theme = await _theme(tester, dark);
        for (final style in [
          theme.elevatedButtonTheme.style,
          theme.textButtonTheme.style,
          theme.outlinedButtonTheme.style,
          theme.iconButtonTheme.style,
        ]) {
          expect(
            style!.minimumSize!.resolve(const <WidgetState>{})!.height,
            greaterThanOrEqualTo(48),
          );
        }
      });
    });
  });

  testWidgets('no raised elevation survives anywhere in the theme', (
    tester,
  ) async {
    for (final dark in [false, true]) {
      final theme = await _theme(tester, dark);
      expect(theme.appBarTheme.elevation, 0);
      expect(theme.appBarTheme.scrolledUnderElevation, 0);
      expect(theme.cardTheme.elevation, 0);
      expect(
        theme.elevatedButtonTheme.style!.elevation!.resolve(
          const <WidgetState>{},
        ),
        0,
      );
    }
  });
}
