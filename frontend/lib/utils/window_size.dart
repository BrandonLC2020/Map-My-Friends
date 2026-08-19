import 'package:flutter/widgets.dart';

/// The shape navigation takes in a given window.
enum NavShape {
  /// A horizontal bar along the bottom edge. Runs along the window's long axis
  /// whenever the window is wider than it is tall.
  bar,

  /// A vertical rail along the leading edge. Needs sustained vertical room for
  /// its destinations, which is exactly what landscape does not have.
  rail,
}

/// The window's size class, and the layout decisions that follow from it.
///
/// Width alone is not a size class. A phone in landscape is 844pt wide —
/// wider than a tablet in portrait — so a width-only test calls it "desktop"
/// and hands it a vertical rail, on the one orientation where vertical space
/// is scarcest. That is not a hypothetical: it clipped two of five
/// destinations off the bottom of the screen, silently, because the rail is
/// positioned rather than constrained and so never reported an overflow.
///
/// So the two questions this app actually asks are separated here:
///
/// * *Do I have width to spread content into?* — [isWide], a width-only test,
///   which is what column caps and page padding care about.
/// * *What shape can navigation take?* — [navShape], which needs both axes.
@immutable
class MapWindow {
  final Size size;

  const MapWindow(this.size);

  /// Reads the window from the ambient [MediaQuery].
  factory MapWindow.of(BuildContext context) {
    return MapWindow(MediaQuery.sizeOf(context));
  }

  /// The width below which content stops being laid out in columns.
  static const double wideThreshold = 600;

  /// The height a rail needs to seat five destinations plus the mark above
  /// them without running off the bottom edge.
  static const double railHeightThreshold = 600;

  /// Enough width to cap a column, pad a page, or place two panes side by
  /// side. Says nothing about navigation.
  bool get isWide => size.width >= wideThreshold;

  /// A rail only where both axes allow it. Everything else takes the bar,
  /// which runs along the window's abundant axis in landscape and is already
  /// an overlay, so it costs no layout space on either.
  NavShape get navShape =>
      size.width >= wideThreshold && size.height >= railHeightThreshold
      ? NavShape.rail
      : NavShape.bar;

  bool get usesRail => navShape == NavShape.rail;
  bool get usesBar => navShape == NavShape.bar;

  /// Too little vertical room to stack floating chrome without the stack
  /// dominating the canvas it floats over.
  ///
  /// Chrome laid out for a tall viewport does not merely look cramped when the
  /// window is short — the map controls stacked to 69% of a landscape phone's
  /// height, which inverts the relationship DESIGN.md §1 asks for, where the
  /// map is the canvas and chrome defers to it. Short windows lay the same
  /// groups out along the abundant axis instead.
  bool get isShortHeight => size.height < railHeightThreshold;

  /// Vertical space the bottom navigation occupies, measured up from the
  /// bottom edge and excluding the safe-area inset. Zero under a rail.
  ///
  /// Floating map chrome adds its own gap on top of this rather than
  /// restating the total. The controls used to infer the total from the same
  /// width test the shell used to pick its navigation, so changing when the
  /// bar appears would have silently parked the zoom stack behind it.
  double get navBarInset => usesBar ? 88 : 0;

  /// Inset for chrome floating against the window edge.
  double get edgeInset => isWide ? 24 : 16;

  @override
  bool operator ==(Object other) => other is MapWindow && other.size == size;

  @override
  int get hashCode => size.hashCode;
}
