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
            return LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 600;

                if (isDesktop) {
                  // Desktop: Grid layout
                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: constraints.maxWidth >= 900 ? 3 : 2,
                      childAspectRatio: 2.5,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: state.people.length,
                    itemBuilder: (context, index) {
                      final person = state.people[index];
                      return Card(
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    AddEditPersonScreen(person: person),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${person.firstName} ${person.lastName}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text('${person.city}, ${person.state}'),
                                Text(
                                  person.relationshipTag,
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                } else {
                  // Mobile: List layout
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
                }
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
