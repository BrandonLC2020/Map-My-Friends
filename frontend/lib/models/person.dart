class Person {
  final String id;
  final String firstName;
  final String lastName;
  final String relationshipTag;
  final String city;
  final String state;
  final String country;
  final String? street;
  final DateTime? birthday;
  final String? phoneNumber;
  final double? latitude;
  final double? longitude;
  final String? profileImageUrl;

  Person({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.relationshipTag,
    required this.city,
    required this.state,
    required this.country,
    this.street,
    this.birthday,
    this.phoneNumber,
    this.latitude,
    this.longitude,
    this.profileImageUrl,
  });

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: json['id'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      relationshipTag: json['relationship_tag'] as String,
      city: json['city'] as String,
      state: json['state'] as String,
      country: json['country'] as String,
      street: json['street'] as String?,
      birthday: json['birthday'] != null
          ? DateTime.parse(json['birthday'] as String)
          : null,
      phoneNumber: json['phone_number'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      profileImageUrl: json['profile_image'] as String?,
    );
  }

  factory Person.fromGeoJson(Map<String, dynamic> json) {
    final properties = json['properties'] as Map<String, dynamic>;
    final geometry = json['geometry'] as Map<String, dynamic>?;
    final coordinates = geometry?['coordinates'] as List<dynamic>?;

    return Person(
      id: json['id'].toString(),
      firstName: properties['first_name'] as String,
      lastName: properties['last_name'] as String,
      relationshipTag: properties['relationship_tag'] as String,
      city: properties['city'] as String,
      state: properties['state'] as String,
      country: properties['country'] as String,
      street: properties['street'] as String?,
      birthday: properties['birthday'] != null
          ? DateTime.parse(properties['birthday'] as String)
          : null,
      phoneNumber: properties['phone_number'] as String?,
      // GeoJSON Point coordinates are [longitude, latitude]
      latitude: coordinates != null ? (coordinates[1] as num).toDouble() : null,
      longitude: coordinates != null
          ? (coordinates[0] as num).toDouble()
          : null,
      profileImageUrl: properties['profile_image'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'first_name': firstName,
      'last_name': lastName,
      'relationship_tag': relationshipTag,
      'city': city,
      'state': state,
      'country': country,
      'street': street,
      'birthday': birthday?.toIso8601String(),
      'phone_number': phoneNumber,
      'latitude': latitude,
      'longitude': longitude,
    };
    if (id.isNotEmpty) {
      data['id'] = id;
    }
    return data;
  }

  Person copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? relationshipTag,
    String? city,
    String? state,
    String? country,
    String? street,
    DateTime? birthday,
    String? phoneNumber,
    double? latitude,
    double? longitude,
    String? profileImageUrl,
  }) {
    return Person(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      relationshipTag: relationshipTag ?? this.relationshipTag,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      street: street ?? this.street,
      birthday: birthday ?? this.birthday,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }
}
