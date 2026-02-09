import 'package:dio/dio.dart';
import '../models/person.dart';

class ApiService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl:
          'http://localhost:8000/api/', // Adjust for emulator/device if needed (10.0.2.2 for Android emulator)
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 3),
    ),
  );

  // Singleton pattern
  static final ApiService _instance = ApiService._internal();

  factory ApiService() {
    return _instance;
  }

  ApiService._internal();

  Future<List<Person>> getPeople() async {
    try {
      final response = await _dio.get('people/');
      if (response.statusCode == 200) {
        List<dynamic> data = response.data;
        return data.map((json) => Person.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load people');
      }
    } catch (e) {
      throw Exception('Failed to load people: $e');
    }
  }

  Future<Person> addPerson(Person person) async {
    try {
      final response = await _dio.post('people/', data: person.toJson());
      if (response.statusCode == 201) {
        return Person.fromJson(response.data);
      } else {
        throw Exception('Failed to add person');
      }
    } catch (e) {
      throw Exception('Failed to add person: $e');
    }
  }

  Future<Person> updatePerson(Person person) async {
    try {
      final response = await _dio.put(
        'people/${person.id}/',
        data: person.toJson(),
      );
      if (response.statusCode == 200) {
        return Person.fromJson(response.data);
      } else {
        throw Exception('Failed to update person');
      }
    } catch (e) {
      throw Exception('Failed to update person: $e');
    }
  }

  Future<void> deletePerson(String id) async {
    try {
      final response = await _dio.delete('people/$id/');
      if (response.statusCode != 204) {
        throw Exception('Failed to delete person');
      }
    } catch (e) {
      throw Exception('Failed to delete person: $e');
    }
  }
}
