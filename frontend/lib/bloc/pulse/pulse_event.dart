part of 'pulse_bloc.dart';

abstract class PulseEvent extends Equatable {
  const PulseEvent();

  @override
  List<Object?> get props => [];
}

/// Load people + their contact history for the Keep-in-Touch screen.
class LoadPulse extends PulseEvent {}

/// Record a new touchpoint with a person.
class LogContact extends PulseEvent {
  final String personId;
  final ContactChannel channel;
  final DateTime contactedAt;
  final String? note;

  const LogContact({
    required this.personId,
    required this.channel,
    required this.contactedAt,
    this.note,
  });

  @override
  List<Object?> get props => [personId, channel, contactedAt, note];
}

/// Override a person's target contact cadence (days between touchpoints).
class SetCadence extends PulseEvent {
  final String personId;
  final int cadenceDays;

  const SetCadence({required this.personId, required this.cadenceDays});

  @override
  List<Object?> get props => [personId, cadenceDays];
}
