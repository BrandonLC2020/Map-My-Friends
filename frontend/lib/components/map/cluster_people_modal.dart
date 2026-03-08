import 'package:flutter/material.dart';
import '../../models/person.dart';
import '../../screens/people/person_details_screen.dart';

class ClusterPeopleModal extends StatelessWidget {
  final List<Person> people;

  const ClusterPeopleModal({super.key, required this.people});

  factory ClusterPeopleModal.withPeople({
    Key? key,
    required List<Person> people,
  }) {
    return ClusterPeopleModal(key: key, people: people);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 32),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            people.length == 1
                ? '1 Person Here'
                : '${people.length} People Here',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: people.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final p = people[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    backgroundImage: p.profileImageUrl != null
                        ? NetworkImage(p.profileImageUrl!)
                        : null,
                    child: p.profileImageUrl == null
                        ? Text(
                            (p.firstName.isNotEmpty ? p.firstName[0] : '') +
                                (p.lastName.isNotEmpty ? p.lastName[0] : ''),
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  title: Text('${p.firstName} ${p.lastName}'),
                  subtitle: Text(
                    p.relationshipTag,
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(context); // close modal
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            PersonDetailsScreen(personId: p.id),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
