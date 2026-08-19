import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/people/people_bloc.dart';
import 'add_edit_person_screen.dart';
import 'person_details_screen.dart';
import '../../components/people/person_card.dart';
import '../../components/shared/glass_empty_state.dart';
import '../../utils/window_size.dart';

class PeopleScreen extends StatelessWidget {
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('People'), centerTitle: true),
      body: SafeArea(
        child: BlocBuilder<PeopleBloc, PeopleState>(
          builder: (context, state) {
            if (state is PeopleLoading) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is PeopleLoaded) {
              if (state.people.isEmpty) {
                return _buildEmptyState(context);
              }
              return LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = MapWindow(
                    Size(constraints.maxWidth, constraints.maxHeight),
                  ).isWide;

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
                                    PersonDetailsScreen(personId: person.id),
                              ),
                            );
                          },
                        );
                      },
                    );
                  } else {
                    // Mobile: List layout
                    return ListView.builder(
                      padding: const EdgeInsets.only(
                        bottom: 120,
                      ), // Bottom nav padding
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
                                    PersonDetailsScreen(personId: person.id),
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
      floatingActionButton: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = MapWindow(
            Size(constraints.maxWidth, constraints.maxHeight),
          ).isWide;
          return Padding(
            padding: EdgeInsets.only(bottom: isDesktop ? 0 : 90),
            child: FloatingActionButton(
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
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return GlassEmptyState(
      icon: Icons.people_outline,
      title: 'No Friends Added Yet',
      message:
          'Add friends and family to see their locations on the map and plan '
          'shared routes!',
      actionLabel: 'Add Your First Friend',
      actionIcon: Icons.person_add_alt_1,
      onAction: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AddEditPersonScreen()),
      ),
    );
  }
}
