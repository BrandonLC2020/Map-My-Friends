part of 'people_bloc.dart';

abstract class PeopleState extends Equatable {
  const PeopleState();

  @override
  List<Object> get props => [];
}

class PeopleInitial extends PeopleState {}

class PeopleLoading extends PeopleState {}

class PeopleLoaded extends PeopleState {
  final List<Person> people;

  const PeopleLoaded(this.people);

  @override
  List<Object> get props => [people];
}

class PeopleError extends PeopleState {
  final String message;

  const PeopleError(this.message);

  @override
  List<Object> get props => [message];
}

class PeopleOperationSuccess extends PeopleState {
  final String message;

  const PeopleOperationSuccess(this.message);

  @override
  List<Object> get props => [message];
}
