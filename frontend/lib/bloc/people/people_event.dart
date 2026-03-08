part of 'people_bloc.dart';

abstract class PeopleEvent extends Equatable {
  const PeopleEvent();

  @override
  List<Object?> get props => [];
}

class LoadPeople extends PeopleEvent {}

class AddPerson extends PeopleEvent {
  final Person person;
  final XFile? profileImage;
  final Uint8List? imageBytes;

  const AddPerson(this.person, {this.profileImage, this.imageBytes});

  @override
  List<Object?> get props => [person, profileImage, imageBytes];
}

class UpdatePerson extends PeopleEvent {
  final Person person;
  final XFile? profileImage;
  final Uint8List? imageBytes;

  const UpdatePerson(this.person, {this.profileImage, this.imageBytes});

  @override
  List<Object?> get props => [person, profileImage, imageBytes];
}

class DeletePerson extends PeopleEvent {
  final String id;

  const DeletePerson(this.id);

  @override
  List<Object?> get props => [id];
}
