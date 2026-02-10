import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/people/people_bloc.dart';
import 'add_edit_person_screen.dart';
import '../../components/people/person_card.dart';

class PeopleScreen extends StatelessWidget {
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<PeopleBloc, PeopleState>(
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
                      padding: EdgeInsets.fromLTRB(
                        isDesktop ? 120 : 16,
                        16,
                        16,
                        16,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: constraints.maxWidth >= 900 ? 3 : 2,
                        childAspectRatio: 2.5,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: state.people.length,
                      itemBuilder: (context, index) {
                        final person = state.people[index];
                        return PersonCard(
                          person: person,
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
