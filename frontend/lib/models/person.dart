import 'package:latlong2/latlong.dart';

enum RelationshipType {
  FRIEND,
  FAMILY,
}

class Person {
  final int id;
  final RelationshipType tag;
  final LatLng location;

  Person({required this.id, required this.tag, required this.location});

  factory Person.fromJson(Map<String, dynamic> json) {
    final properties = json['properties'];
    final geometry = json['geometry'];
    final coordinates = geometry['coordinates'];

    // GeoJSON Point coordinates are [longitude, latitude]
    final lat = coordinates[1].toDouble();
    final lng = coordinates[0].toDouble();

    return Person(
      id: json['id'],
      tag: properties['tag'] == 'FRIEND' ? RelationshipType.FRIEND : RelationshipType.FAMILY,
      location: LatLng(lat, lng),
    );
  }
}
