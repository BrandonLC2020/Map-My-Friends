import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_my_friends/components/shared/nav_label.dart';

/// The mobile glass bar spans the viewport inset 16pt each side, pads 16pt
/// inside the glass, and splits the remainder across five tabs which pad 4pt
/// each. On the narrowest phone this project supports that is the slot a label
/// has to survive in.
double _mobileSlotWidth(double viewport) => (viewport - 32 - 32) / 5 - 8;

/// The desktop rail pins each item to a fixed 60pt column.
const double kRailSlotWidth = 60;

Widget _inSlot(double width, Widget child, {double scale = 1.0}) {
  return MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(width: width, child: child),
      ),
    ),
  );
}

void main() {
  // "People" is the widest English label and, being one word, has no wrap
  // point — it is the string that actually breaks the bar.
  const widest = 'People';

  testWidgets('fits its slot at every scale the platform can request', (
    tester,
  ) async {
    // 3.0 is beyond iOS's largest accessibility size; if it holds there it
    // holds everywhere.
    for (final scale in <double>[1.0, 1.3, 2.0, 3.0]) {
      for (final slot in <double>[
        _mobileSlotWidth(320), // smallest phone
        _mobileSlotWidth(390),
        kRailSlotWidth,
      ]) {
        await tester.pumpWidget(
          _inSlot(
            slot,
            const NavLabel(widest, style: TextStyle(fontSize: 11)),
            scale: scale,
          ),
        );

        expect(
          tester.takeException(),
          isNull,
          reason: 'overflowed a ${slot.toStringAsFixed(1)}pt slot at ${scale}x',
        );
      }
    }
  });

  testWidgets('stops scaling at the ceiling', (tester) async {
    const style = TextStyle(fontSize: 11);

    await tester.pumpWidget(
      _inSlot(200, const NavLabel(widest, style: style), scale: 3.0),
    );
    final capped = tester.getSize(find.text(widest));

    await tester.pumpWidget(
      _inSlot(
        200,
        const NavLabel(widest, style: style),
        scale: kNavLabelMaxScale,
      ),
    );
    final atCeiling = tester.getSize(find.text(widest));

    expect(capped.height, atCeiling.height);
  });

  testWidgets('still scales up to the ceiling', (tester) async {
    // The cap must not flatten scaling altogether — users who ask for larger
    // text get larger text, just bounded.
    const style = TextStyle(fontSize: 11);

    await tester.pumpWidget(
      _inSlot(200, const NavLabel(widest, style: style), scale: 1.0),
    );
    final base = tester.getSize(find.text(widest));

    await tester.pumpWidget(
      _inSlot(200, const NavLabel(widest, style: style), scale: 3.0),
    );
    final capped = tester.getSize(find.text(widest));

    expect(capped.height, greaterThan(base.height));
  });

  testWidgets('truncates a long translation rather than overflowing', (
    tester,
  ) async {
    // German and Spanish nav copy runs longer than the English source.
    await tester.pumpWidget(
      _inSlot(
        _mobileSlotWidth(320),
        const NavLabel('Reiseübersicht', style: TextStyle(fontSize: 11)),
      ),
    );

    expect(tester.takeException(), isNull);
    final text = tester.widget<Text>(find.byType(Text));
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
  });
}
