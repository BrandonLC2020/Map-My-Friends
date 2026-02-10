import 'package:flutter/material.dart';
import '../../models/person.dart';

class PersonCard extends StatelessWidget {
  final Person person;
  final VoidCallback onTap;

  const PersonCard({super.key, required this.person, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
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
                style: TextStyle(color: Theme.of(context).primaryColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
