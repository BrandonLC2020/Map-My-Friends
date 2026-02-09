part of 'people_bloc.dart';

abstract class PeopleEvent extends Equatable {
  const PeopleEvent();

  @override
  List<Object> get props => [];
}

class LoadPeople extends PeopleEvent {}

class AddPerson extends PeopleEvent {
  final Person person;

  const AddPerson(this.person);

  @override
  List<Object> get props => [person];
}

class UpdatePerson extends PeopleEvent {
  final Person person;

  const UpdatePerson(this.person);

  @override
  List<Object> get props => [person];
}

class DeletePerson extends PeopleEvent {
  final String id;

  const DeletePerson(this.id);

  @override
  List<Object> get props => [id];
}
