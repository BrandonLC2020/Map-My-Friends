import 'package:flutter/material.dart';
import '../models/contact_log.dart';
import '../models/person.dart';
import 'app_theme.dart';

/// How overdue a relationship is, expressed as bands along the thermal
/// spectrum. Ordered coolest → hottest so `.index` reads as rising urgency.
enum RecencyLevel { fresh, steady, due, overdue, silent }

/// Derives a person's contact recency and maps it onto the app's thermal
/// material language: calm/cool when recently in touch, igniting toward the
/// thermal core (#FF3B30) the longer a connection goes untended.
///
/// Color is never the sole signal — every consumer pairs it with a text label,
/// an icon, and the day count, so the roster stays legible for color-blind
/// users (and honors the "verify contrast" rule via [inkColor]).
class ContactRecency {
  const ContactRecency._({
    required this.level,
    required this.daysSince,
    required this.cadenceDays,
    required this.progress,
    required this.everContacted,
    required this.overdueRatio,
  });

  final RecencyLevel level;

  /// Whole days since the last logged touchpoint, or null if never contacted.
  final int? daysSince;

  /// The effective target cadence used to judge overdue-ness.
  final int cadenceDays;

  /// 0..1 fill of the current cadence window (clamped) — for progress bars.
  final double progress;

  final bool everContacted;

  /// daysSince / cadence, unclamped. Used to rank the roster (higher = more
  /// overdue). Never-contacted resolves to [double.infinity].
  final double overdueRatio;

  /// Default cadence targets when a person has no custom [Person.contactCadenceDays].
  /// Family runs tighter than friends by design.
  static const int familyCadenceDays = 14;
  static const int friendCadenceDays = 30;

  static int defaultCadenceForTag(String tag) =>
      tag.toUpperCase() == 'FAMILY' ? familyCadenceDays : friendCadenceDays;

  factory ContactRecency.forPerson(Person person, {DateTime? now}) {
    final cadence =
        person.contactCadenceDays ??
        defaultCadenceForTag(person.relationshipTag);
    return ContactRecency.fromValues(
      lastContactedAt: person.lastContactedAt,
      cadenceDays: cadence,
      now: now,
    );
  }

  factory ContactRecency.fromValues({
    required DateTime? lastContactedAt,
    required int cadenceDays,
    DateTime? now,
  }) {
    final cadence = cadenceDays <= 0 ? 1 : cadenceDays;

    if (lastContactedAt == null) {
      return ContactRecency._(
        level: RecencyLevel.silent,
        daysSince: null,
        cadenceDays: cadence,
        progress: 1.0,
        everContacted: false,
        overdueRatio: double.infinity,
      );
    }

    final today = now ?? DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final lastDate = DateTime(
      lastContactedAt.year,
      lastContactedAt.month,
      lastContactedAt.day,
    );
    final rawDays = todayDate.difference(lastDate).inDays;
    final days = rawDays < 0 ? 0 : rawDays;
    final ratio = days / cadence;

    return ContactRecency._(
      level: _levelForRatio(ratio),
      daysSince: days,
      cadenceDays: cadence,
      progress: ratio.clamp(0.0, 1.0).toDouble(),
      everContacted: true,
      overdueRatio: ratio,
    );
  }

  static RecencyLevel _levelForRatio(double ratio) {
    if (ratio < 0.5) return RecencyLevel.fresh;
    if (ratio < 1.0) return RecencyLevel.steady;
    if (ratio < 1.5) return RecencyLevel.due;
    if (ratio < 2.5) return RecencyLevel.overdue;
    return RecencyLevel.silent;
  }

  bool get isAttentionNeeded =>
      level == RecencyLevel.overdue || level == RecencyLevel.silent;

  /// Short status word for chips and labels.
  String get label {
    switch (level) {
      case RecencyLevel.fresh:
        return 'In touch';
      case RecencyLevel.steady:
        return 'On track';
      case RecencyLevel.due:
        return 'Due soon';
      case RecencyLevel.overdue:
        return 'Overdue';
      case RecencyLevel.silent:
        return everContacted ? 'Long overdue' : 'Not yet logged';
    }
  }

  /// Human relative phrasing of the last touchpoint.
  String get lastContactPhrase {
    final d = daysSince;
    if (d == null) return 'No contact logged yet';
    if (d == 0) return 'Contacted today';
    if (d == 1) return 'Contacted yesterday';
    if (d < 7) return 'Contacted $d days ago';
    if (d < 14) return 'Contacted last week';
    if (d < 30) return 'Contacted ${(d / 7).floor()} weeks ago';
    if (d < 60) return 'Contacted last month';
    if (d < 365) return 'Contacted ${(d / 30).floor()} months ago';
    return 'Contacted over a year ago';
  }

  /// Vivid, saturated tone — for status orbs, dots, and thermal glow. NOT for
  /// text (fails contrast on tinted surfaces by design).
  Color get vividColor {
    switch (level) {
      case RecencyLevel.fresh:
        return const Color(0xFF14B8A6); // teal — healthy connection
      case RecencyLevel.steady:
        return const Color(0xFF6B7280); // calm neutral slate
      case RecencyLevel.due:
        return MapPalette.thermalCorona; // #FF9500
      case RecencyLevel.overdue:
        return const Color(0xFFFF5A1F); // corona → core
      case RecencyLevel.silent:
        return MapPalette.thermalCore; // #FF3B30, hottest
    }
  }

  /// Contrast-safe tone for the person's name text. Darker on light themes,
  /// lighter on dark themes, so body text clears 4.5:1 either way.
  Color inkColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    switch (level) {
      case RecencyLevel.fresh:
        return isDark ? const Color(0xFF5EEAD4) : const Color(0xFF00695C);
      case RecencyLevel.steady:
        // Full-contrast neutral: a "calm" connection reads as ordinary text.
        return Theme.of(context).colorScheme.onSurface;
      case RecencyLevel.due:
        return isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309);
      case RecencyLevel.overdue:
        return isDark ? const Color(0xFFFB923C) : const Color(0xFFC2410C);
      case RecencyLevel.silent:
        return isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C);
    }
  }

  IconData get icon {
    switch (level) {
      case RecencyLevel.fresh:
        return Icons.favorite;
      case RecencyLevel.steady:
        return Icons.check_circle;
      case RecencyLevel.due:
        return Icons.schedule;
      case RecencyLevel.overdue:
        return Icons.local_fire_department;
      case RecencyLevel.silent:
        return everContacted ? Icons.priority_high : Icons.waving_hand;
    }
  }
}

/// UI adornments for [ContactChannel]. Kept out of the model so the data layer
/// stays Flutter-free.
extension ContactChannelUi on ContactChannel {
  IconData get icon {
    switch (this) {
      case ContactChannel.call:
        return Icons.call;
      case ContactChannel.video:
        return Icons.videocam;
      case ContactChannel.message:
        return Icons.chat_bubble;
    }
  }

  /// Distinct brand-palette hue per channel, for calendar day markers.
  Color get markerColor {
    switch (this) {
      case ContactChannel.call:
        return const Color(0xFF3F51B5); // brand indigo
      case ContactChannel.video:
        return const Color(0xFFFF4081); // secondary pink
      case ContactChannel.message:
        return const Color(0xFF14B8A6); // teal
    }
  }
}
