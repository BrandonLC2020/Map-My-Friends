import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/people/people_bloc.dart';
import 'add_edit_person_screen.dart';

class PeopleScreen extends StatelessWidget {
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('People')),
      body: BlocBuilder<PeopleBloc, PeopleState>(
        builder: (context, state) {
          if (state is PeopleLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is PeopleLoaded) {
            if (state.people.isEmpty) {
              return const Center(child: Text('No people added yet.'));
            }
            return ListView.builder(
              itemCount: state.people.length,
              itemBuilder: (context, index) {
                final person = state.people[index];
                return ListTile(
                  title: Text('${person.firstName} ${person.lastName}'),
                  subtitle: Text('${person.city}, ${person.state}'),
                  trailing: Text(person.relationshipTag),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AddEditPersonScreen(person: person),
                      ),
                    );
                  },
                );
              },
            );
          } else if (state is PeopleError) {
            return Center(child: Text('Error: ${state.message}'));
          }
          return const Center(child: Text('Start adding people!'));
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddEditPersonScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
