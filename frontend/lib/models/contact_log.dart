/// The channels through which a touchpoint can happen.
///
/// [apiValue] mirrors the Django `ContactLog.CHANNEL_*` constants. Kept as
/// plain Dart (no Flutter import) so the model layer stays unit-testable; the
/// icon mapping lives in a UI-side extension (see contact_recency.dart).
enum ContactChannel {
  call('CALL', 'Call'),
  video('VIDEO', 'Video chat'),
  message('MESSAGE', 'Message');

  const ContactChannel(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static ContactChannel? fromApi(String? value) {
    if (value == null) return null;
    for (final channel in ContactChannel.values) {
      if (channel.apiValue == value) return channel;
    }
    return null;
  }
}

/// A single logged interaction with a [Person]: one call, video chat, or
/// message on one day. Powers the Keep-in-Touch calendar and recency spectrum.
class ContactLog {
  final String id;
  final String personId;
  final ContactChannel channel;
  final DateTime contactedAt;
  final String? note;

  ContactLog({
    required this.id,
    required this.personId,
    required this.channel,
    required this.contactedAt,
    this.note,
  });

  factory ContactLog.fromJson(Map<String, dynamic> json) {
    return ContactLog(
      id: json['id'].toString(),
      personId: json['person'].toString(),
      channel:
          ContactChannel.fromApi(json['channel'] as String?) ??
          ContactChannel.message,
      contactedAt: DateTime.parse(json['contacted_at'] as String).toLocal(),
      note: json['note'] as String?,
    );
  }

  /// Payload for creating a log. Server assigns `id`/`created_at`.
  Map<String, dynamic> toCreateJson() {
    final data = <String, dynamic>{
      'person': personId,
      'channel': channel.apiValue,
      // Send UTC so the server stores an unambiguous instant.
      'contacted_at': contactedAt.toUtc().toIso8601String(),
    };
    if (note != null && note!.isNotEmpty) data['note'] = note;
    return data;
  }
}
