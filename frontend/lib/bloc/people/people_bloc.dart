import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/person.dart';
import '../../services/api_service.dart';

part 'people_event.dart';
part 'people_state.dart';

class PeopleBloc extends Bloc<PeopleEvent, PeopleState> {
  final ApiService _apiService;

  PeopleBloc({required ApiService apiService})
    : _apiService = apiService,
      super(PeopleInitial()) {
    on<LoadPeople>(_onLoadPeople);
    on<AddPerson>(_onAddPerson);
    on<UpdatePerson>(_onUpdatePerson);
    on<DeletePerson>(_onDeletePerson);
  }

  Future<void> _onLoadPeople(
    LoadPeople event,
    Emitter<PeopleState> emit,
  ) async {
    emit(PeopleLoading());
    try {
      final people = await _apiService.getPeople();
      emit(PeopleLoaded(people));
    } catch (e) {
      emit(PeopleError(e.toString()));
    }
  }

  Future<void> _onAddPerson(AddPerson event, Emitter<PeopleState> emit) async {
    final currentState = state;
    if (currentState is PeopleLoaded) {
      try {
        final newPerson = await _apiService.addPerson(event.person);
        final updatedList = List<Person>.from(currentState.people)
          ..add(newPerson);
        emit(PeopleLoaded(updatedList));
      } catch (e) {
        emit(PeopleError(e.toString()));
        // Re-emit loaded state to allow retry without full reload?
        // Or handle specific error state for operations.
        // For simplicity, just error for now. A better approach would be separate status.
      }
    } else {
      // If not loaded yet, just try to load? Or add blind?
      // Let's assume user is on a screen where load happened.
      emit(PeopleError("Cannot add person before loading list"));
    }
  }

  Future<void> _onUpdatePerson(
    UpdatePerson event,
    Emitter<PeopleState> emit,
  ) async {
    final currentState = state;
    if (currentState is PeopleLoaded) {
      try {
        final updatedPerson = await _apiService.updatePerson(event.person);
        final updatedList = currentState.people.map((p) {
          return p.id == updatedPerson.id ? updatedPerson : p;
        }).toList();
        emit(PeopleLoaded(updatedList));
      } catch (e) {
        emit(PeopleError(e.toString()));
      }
    }
  }

  Future<void> _onDeletePerson(
    DeletePerson event,
    Emitter<PeopleState> emit,
  ) async {
    final currentState = state;
    if (currentState is PeopleLoaded) {
      try {
        await _apiService.deletePerson(event.id);
        final updatedList = currentState.people
            .where((p) => p.id != event.id)
            .toList();
        emit(PeopleLoaded(updatedList));
      } catch (e) {
        emit(PeopleError(e.toString()));
      }
    }
  }
}
