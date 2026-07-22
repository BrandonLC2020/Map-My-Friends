part of 'pulse_bloc.dart';

abstract class PulseState extends Equatable {
  const PulseState();

  @override
  List<Object?> get props => [];
}

class PulseInitial extends PulseState {}

class PulseLoading extends PulseState {}

class PulseError extends PulseState {
  final String message;

  const PulseError(this.message);

  @override
  List<Object?> get props => [message];
}

class PulseLoaded extends PulseState {
  final List<Person> people;
  final List<ContactLog> logs;

  /// Transient message for a failed action (log/cadence), shown once via a
  /// listener. Paired with [actionNonce] so repeated identical failures still
  /// notify.
  final String? actionError;
  final int actionNonce;

  const PulseLoaded({
    required this.people,
    required this.logs,
    this.actionError,
    this.actionNonce = 0,
  });

  PulseLoaded copyWith({
    List<Person>? people,
    List<ContactLog>? logs,
    String? actionError,
    int? actionNonce,
  }) {
    return PulseLoaded(
      people: people ?? this.people,
      logs: logs ?? this.logs,
      // actionError is deliberately not carried forward: it is a one-shot
      // signal, cleared on any emit that doesn't explicitly set it.
      actionError: actionError,
      actionNonce: actionNonce ?? this.actionNonce,
    );
  }

  @override
  List<Object?> get props => [people, logs, actionError, actionNonce];
}
