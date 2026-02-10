import 'package:flutter/material.dart';
import '../models/person.dart';

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
          ),
        );
      },
      child: const Icon(Icons.location_on, color: Colors.red, size: 40),
    );
  }
}
