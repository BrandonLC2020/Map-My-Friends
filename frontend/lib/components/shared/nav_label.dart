import 'package:flutter/material.dart';

/// Ceiling for navigation-label text scaling.
///
/// Above this the label outgrows its slot in the glass rail or bar. The icon
/// and the item's Semantics label carry the meaning past this point.
const double kNavLabelMaxScale = 1.3;

/// A navigation label sized to survive its slot.
///
/// Tab labels sit in fixed-width slots inside the glass chrome — 60pt in the
/// desktop rail, roughly a fifth of the screen in the mobile bar. They cannot
/// absorb unbounded text scaling: a single-word label like "People" has no wrap
/// point, so at 200% it paints an overflow stripe straight across the material
/// it sits on.
///
/// Capping the label's scale keeps the surface intact while the rest of the app
/// scales normally, which is what platform tab bars do. Nothing is lost to
/// assistive technology — each nav item wraps this in a [Semantics] node
/// carrying the full, uncapped label — and the ellipsis is the backstop for
/// translations longer than any English string here.
class NavLabel extends StatelessWidget {
  final String label;
  final TextStyle style;

  const NavLabel(this.label, {super.key, required this.style});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: style,
      textScaler: MediaQuery.textScalerOf(
        context,
      ).clamp(maxScaleFactor: kNavLabelMaxScale),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );
  }
}
