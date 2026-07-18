import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/people/people_bloc.dart';
import 'add_edit_person_screen.dart';
import 'person_details_screen.dart';
import '../../components/people/person_card.dart';
import '../../components/shared/glass_container.dart';

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
          final isDesktop = constraints.maxWidth >= 600;
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
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: GlassContainer(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.people_outline,
                size: 64,
                color: onSurface.withValues(alpha: 0.2),
              ),
              const SizedBox(height: 24),
              Text(
                'No Friends Added Yet',
                style: TextStyle(
                  color: onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add friends and family to see their locations on the map and plan shared routes!',
                textAlign: TextAlign.center,
                style: TextStyle(color: onSurface.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddEditPersonScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Add Your First Friend'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
