import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';

/// Refractive Glass — the LLC Tier 3 (pure-Dart) material.
///
/// Depth comes from blurring what sits *behind* the surface, never from a
/// shadow cast below it (DESIGN.md §4, The Refraction-Over-Shadow Rule).
///
/// ## GPU budget
///
/// `impeller-optimization.md` caps a screen at **two concurrent
/// `BackdropFilter` layers**. Flutter satisfies that without rationing panels:
/// every [GlassContainer] under a common [BackdropGroup] samples the backdrop
/// **once** and shares the result, so a screen's whole chrome collapses to a
/// single layer no matter how many panels it draws.
///
/// The grouping is therefore not an optimisation you may skip — it is the
/// reason the budget holds. Every screen that renders glass must establish a
/// [BackdropGroup] above it; a debug assert below enforces this, because
/// `BackdropFilter.grouped` degrades *silently* to an ungrouped filter when no
/// group is found, and a silent degradation is exactly the regression that put
/// this app at 7+N layers on the Map.
///
/// Two rules come with the shared key:
///
/// * **One group per screen, not per app.** Route transitions overlap the
///   outgoing and incoming screens, and same-key filters that overlap render as
///   though only one of them applied.
/// * **Panels within a group must not overlap each other.** Chrome laid out
///   around the edges of a canvas satisfies this naturally. A surface that sits
///   over other glass — a modal, a sheet — belongs outside the group; use
///   [GlassContainer.isolated] there.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final double opacity;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double? width;
  final double? height;
  final String? semanticLabel;

  /// Whether this surface shares the enclosing [BackdropGroup]'s single
  /// backdrop sample. True for every in-screen surface; see
  /// [GlassContainer.isolated] for the exception.
  final bool grouped;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = MapGlass.radiusLg,
    this.blur = MapGlass.blurSigma,
    this.opacity = MapGlass.tintLight,
    this.padding = const EdgeInsets.all(16.0),
    this.color,
    this.width,
    this.height,
    this.semanticLabel,
  }) : grouped = true;

  /// A glass surface that owns its backdrop sample instead of sharing one.
  ///
  /// For surfaces that float *above* other glass — modal sheets, dialogs,
  /// overlays pushed onto the [Navigator]. These overlap the chrome beneath
  /// them, so sharing that chrome's backdrop key would blank the refraction in
  /// the overlapping region.
  const GlassContainer.isolated({
    super.key,
    required this.child,
    this.borderRadius = MapGlass.radiusLg,
    this.blur = MapGlass.blurSigma,
    this.opacity = MapGlass.tintLight,
    this.padding = const EdgeInsets.all(16.0),
    this.color,
    this.width,
    this.height,
    this.semanticLabel,
  }) : grouped = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool highContrast = MediaQuery.of(context).highContrast;
    final bool isDark = theme.brightness == Brightness.dark;

    // Dark surfaces float over less contrast, so they carry a slightly heavier
    // fill — but only slightly. The clamp reserves headroom for the sheen so
    // the *composed* top-left value still lands under MapGlass.tintMax; past
    // that ceiling the material stops reading as glass (DESIGN.md §6).
    // Dark mode buys the rest of its legibility at the edge, below.
    const double darkLift = MapGlass.tintDark - MapGlass.tintLight;
    final double effectiveOpacity = highContrast
        ? 1.0
        : (isDark ? opacity + darkLift : opacity).clamp(
            MapGlass.tintMin,
            MapGlass.tintMax - MapGlass.sheen,
          );
    // Negative sigma throws inside ImageFilter.blur and a negative radius
    // throws in the painter — both far from the call site that caused them.
    // Clamp so a bad computed value degrades to a flat or square surface
    // instead of crashing a screen the user is already looking at.
    final double effectiveBlur = highContrast ? 0.0 : math.max(0.0, blur);
    final double effectiveRadius = math.max(0.0, borderRadius);

    Widget container;

    if (highContrast) {
      // No backdrop sampling on this path — the surface is opaque, so it costs
      // nothing to composite and needs no RepaintBoundary or backdrop group.
      container = Container(
        width: width,
        height: height,
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(effectiveRadius),
          border: Border.all(color: theme.dividerColor, width: 1.0),
        ),
        child: child,
      );
    } else {
      assert(_debugAssertHasBackdropGroup(context));

      final baseColor = color ?? theme.colorScheme.surface;
      final blurFilter = ImageFilter.blur(
        sigmaX: effectiveBlur,
        sigmaY: effectiveBlur,
      );

      // The gradient supersedes `decoration.color`: BoxDecoration paints a
      // shader over the flat colour when both are set, so the colour is only
      // expressed through the stops below.
      final decoration = BoxDecoration(
        borderRadius: BorderRadius.circular(effectiveRadius),
        border: Border.all(
          color: Colors.white.withValues(
            alpha: isDark ? MapGlass.edgeDark : MapGlass.edgeLight,
          ),
          width: MapGlass.edgeWidth,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            baseColor.withValues(alpha: effectiveOpacity + MapGlass.sheen),
            baseColor.withValues(alpha: effectiveOpacity),
          ],
        ),
      );

      final tinted = Container(
        width: width,
        height: height,
        padding: padding,
        decoration: decoration,
        child: child,
      );

      // Isolate the glass subtree so an unrelated repaint in an ancestor — the
      // map tile layer, a scrolling list, a rebuilding BLoC — does not force
      // this surface to re-blur (impeller-optimization.md §Promotion).
      container = RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(effectiveRadius),
          child: grouped
              ? BackdropFilter.grouped(filter: blurFilter, child: tinted)
              : BackdropFilter(filter: blurFilter, child: tinted),
        ),
      );
    }

    if (semanticLabel != null) {
      return Semantics(label: semanticLabel, container: true, child: container);
    }

    return container;
  }

  bool _debugAssertHasBackdropGroup(BuildContext context) {
    if (!grouped || kReleaseMode) return true;
    if (BackdropGroup.of(context) != null) return true;
    throw FlutterError.fromParts(<DiagnosticsNode>[
      ErrorSummary(
        'A GlassContainer was built with no BackdropGroup above it.',
      ),
      ErrorDescription(
        'Without a BackdropGroup, BackdropFilter.grouped silently falls back to '
        'an unshared backdrop sample, so every glass surface on this screen '
        'costs a separate GPU layer.',
      ),
      ErrorHint(
        'Wrap this screen\'s root — the Scaffold body or the Stack holding its '
        'chrome — in a BackdropGroup. Use one group per screen rather than one '
        'for the whole app, so overlapping route transitions do not share a key.',
      ),
      ErrorHint(
        'If this surface deliberately floats above other glass (a modal sheet, '
        'a dialog), use GlassContainer.isolated instead.',
      ),
    ]);
  }
}
