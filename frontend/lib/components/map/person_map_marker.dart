import 'package:flutter/material.dart';
import '../../models/person.dart';
import '../../screens/people/person_details_screen.dart';

class PersonMapMarker extends StatelessWidget {
  final Person person;

  const PersonMapMarker({super.key, required this.person});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('${person.firstName} ${person.lastName}'),
            content: Text('${person.city}, ${person.state}'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          PersonDetailsScreen(personId: person.id),
                    ),
                  );
                },
                child: const Text('View Details'),
              ),
            ],
          ),
        );
      },
      child: const Icon(Icons.location_on, color: Colors.red, size: 40),
    );
  }
}
