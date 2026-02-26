import 'package:flutter/material.dart';
import '../../models/person.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';

class PersonCard extends StatelessWidget {
  final Person person;
  final VoidCallback onTap;

  const PersonCard({super.key, required this.person, required this.onTap});

  @override
  Widget build(BuildContext context) {
    String? timeString;
    if (person.timezone != null && person.timezone!.isNotEmpty) {
      try {
        final location = tz.getLocation(person.timezone!);
        final now = tz.TZDateTime.now(location);
        timeString = DateFormat.jm().format(now);
      } catch (_) {
        // Ignore invalid timezones
      }
    }

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
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    person.relationshipTag,
                    style: TextStyle(color: Theme.of(context).primaryColor),
                  ),
                  if (timeString != null)
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          timeString,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
