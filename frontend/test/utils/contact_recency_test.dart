import 'package:flutter_test/flutter_test.dart';
import 'package:map_my_friends/models/person.dart';
import 'package:map_my_friends/utils/contact_recency.dart';

Person _person({
  String tag = 'FRIEND',
  int? cadence,
  DateTime? lastContacted,
}) {
  return Person(
    id: '1',
    firstName: 'Test',
    lastName: 'Person',
    relationshipTag: tag,
    city: 'City',
    state: 'ST',
    country: 'Country',
    contactCadenceDays: cadence,
    lastContactedAt: lastContacted,
  );
}

void main() {
  final now = DateTime(2026, 7, 22);

  group('defaultCadenceForTag', () {
    test('family is tighter than friend', () {
      expect(ContactRecency.defaultCadenceForTag('FAMILY'), 14);
      expect(ContactRecency.defaultCadenceForTag('FRIEND'), 30);
    });

    test('is case-insensitive and falls back to friend cadence', () {
      expect(ContactRecency.defaultCadenceForTag('family'), 14);
      expect(ContactRecency.defaultCadenceForTag('UNKNOWN'), 30);
    });
  });

  group('never contacted', () {
    test('is silent, needs attention, and sorts to the top', () {
      final r = ContactRecency.forPerson(_person(), now: now);
      expect(r.level, RecencyLevel.silent);
      expect(r.everContacted, isFalse);
      expect(r.daysSince, isNull);
      expect(r.overdueRatio, double.infinity);
      expect(r.isAttentionNeeded, isTrue);
      expect(r.label, 'Not yet logged');
      // Falls back to the tag default cadence for display.
      expect(r.cadenceDays, 30);
    });
  });

  group('level bands (cadence 30)', () {
    ContactRecency at(int daysAgo) => ContactRecency.forPerson(
          _person(lastContacted: now.subtract(Duration(days: daysAgo))),
          now: now,
        );

    test('fresh below half a cadence', () {
      expect(at(0).level, RecencyLevel.fresh);
      expect(at(10).level, RecencyLevel.fresh); // ratio 0.33
    });

    test('steady between half and one cadence', () {
      expect(at(20).level, RecencyLevel.steady); // ratio 0.67
    });

    test('due just past cadence', () {
      expect(at(35).level, RecencyLevel.due); // ratio 1.17
      expect(at(35).isAttentionNeeded, isFalse);
    });

    test('overdue past 1.5x cadence', () {
      expect(at(60).level, RecencyLevel.overdue); // ratio 2.0
      expect(at(60).isAttentionNeeded, isTrue);
    });

    test('silent past 2.5x cadence', () {
      expect(at(90).level, RecencyLevel.silent); // ratio 3.0
      expect(at(90).everContacted, isTrue);
      expect(at(90).label, 'Long overdue');
    });
  });

  group('per-person cadence overrides tag default', () {
    test('a tight custom cadence heats up faster', () {
      final person = _person(
        tag: 'FRIEND',
        cadence: 7,
        lastContacted: now.subtract(const Duration(days: 20)),
      );
      final r = ContactRecency.forPerson(person, now: now);
      // 20 / 7 = 2.86 -> silent, whereas the friend default (30) would be steady.
      expect(r.cadenceDays, 7);
      expect(r.level, RecencyLevel.silent);
    });
  });

  group('progress and phrasing', () {
    test('progress clamps to 1.0 when overdue', () {
      final r = ContactRecency.forPerson(
        _person(lastContacted: now.subtract(const Duration(days: 90))),
        now: now,
      );
      expect(r.progress, 1.0);
    });

    test('future or same-day contact reads as today with zero days', () {
      final r = ContactRecency.forPerson(
        _person(lastContacted: now),
        now: now,
      );
      expect(r.daysSince, 0);
      expect(r.lastContactPhrase, 'Contacted today');
    });

    test('week-scale phrasing', () {
      final r = ContactRecency.forPerson(
        _person(lastContacted: now.subtract(const Duration(days: 9))),
        now: now,
      );
      expect(r.lastContactPhrase, 'Contacted last week');
    });
  });
}
