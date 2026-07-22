import 'package:flutter_test/flutter_test.dart';
import 'package:map_my_friends/models/contact_log.dart';

void main() {
  group('ContactChannel', () {
    test('round-trips api values', () {
      expect(ContactChannel.fromApi('CALL'), ContactChannel.call);
      expect(ContactChannel.fromApi('VIDEO'), ContactChannel.video);
      expect(ContactChannel.fromApi('MESSAGE'), ContactChannel.message);
    });

    test('returns null for unknown or missing values', () {
      expect(ContactChannel.fromApi('CARRIER_PIGEON'), isNull);
      expect(ContactChannel.fromApi(null), isNull);
    });
  });

  group('ContactLog.fromJson', () {
    test('parses server payload and localizes the timestamp', () {
      final log = ContactLog.fromJson({
        'id': 42,
        'person': 7,
        'channel': 'VIDEO',
        'contacted_at': '2026-07-20T15:00:00Z',
        'note': 'Caught up',
      });
      expect(log.id, '42');
      expect(log.personId, '7');
      expect(log.channel, ContactChannel.video);
      expect(log.note, 'Caught up');
      expect(log.contactedAt.isUtc, isFalse); // converted to local
    });

    test('defaults an unrecognized channel to message', () {
      final log = ContactLog.fromJson({
        'id': 1,
        'person': 1,
        'channel': 'SMOKE_SIGNAL',
        'contacted_at': '2026-07-20T15:00:00Z',
      });
      expect(log.channel, ContactChannel.message);
    });
  });

  group('ContactLog.toCreateJson', () {
    test('sends UTC timestamp and omits an empty note', () {
      final log = ContactLog(
        id: 'temp',
        personId: '7',
        channel: ContactChannel.call,
        contactedAt: DateTime(2026, 7, 20, 10),
        note: '',
      );
      final json = log.toCreateJson();
      expect(json['person'], '7');
      expect(json['channel'], 'CALL');
      expect(json.containsKey('note'), isFalse);
      expect((json['contacted_at'] as String).endsWith('Z'), isTrue);
    });

    test('includes a non-empty note', () {
      final log = ContactLog(
        id: 'temp',
        personId: '7',
        channel: ContactChannel.message,
        contactedAt: DateTime(2026, 7, 20),
        note: 'Birthday text',
      );
      expect(log.toCreateJson()['note'], 'Birthday text');
    });
  });
}
