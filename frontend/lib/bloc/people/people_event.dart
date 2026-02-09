part of 'people_bloc.dart';

abstract class PeopleEvent extends Equatable {
  const PeopleEvent();

  @override
  List<Object?> get props => [];
}

class LoadPeople extends PeopleEvent {}

class AddPerson extends PeopleEvent {
  final Person person;
  final File? profileImage;

  const AddPerson(this.person, {this.profileImage});

  @override
  List<Object?> get props => [person, profileImage];
}

class UpdatePerson extends PeopleEvent {
  final Person person;
  final File? profileImage;

  const UpdatePerson(this.person, {this.profileImage});

  @override
  List<Object?> get props => [person, profileImage];
}

class DeletePerson extends PeopleEvent {
  final String id;

  const DeletePerson(this.id);

  @override
  List<Object?> get props => [id];
}
