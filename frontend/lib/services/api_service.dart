import 'dart:io';
import 'package:dio/dio.dart';
import '../models/person.dart';
import 'auth_service.dart';

class ApiService {
  late final Dio _dio;
  final AuthService _authService = AuthService();

  // Singleton pattern
  static final ApiService _instance = ApiService._internal();

  factory ApiService() {
    return _instance;
  }

  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: 'http://localhost:8000/api/',
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 3),
      ),
    );

    // Add auth interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _authService.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            // Try to refresh the token
            final newToken = await _authService.refreshAccessToken();
            if (newToken != null) {
              // Retry the request with new token
              error.requestOptions.headers['Authorization'] =
                  'Bearer $newToken';
              final response = await _dio.fetch(error.requestOptions);
              return handler.resolve(response);
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

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

  Future<Person> addPerson(Person person, {File? profileImage}) async {
    try {
      FormData formData;

      if (profileImage != null) {
        formData = FormData.fromMap({
          ...person.toJson(),
          'profile_image': await MultipartFile.fromFile(
            profileImage.path,
            filename: profileImage.path.split('/').last,
          ),
        });
      } else {
        formData = FormData.fromMap(person.toJson());
      }

      final response = await _dio.post('people/', data: formData);
      if (response.statusCode == 201) {
        return Person.fromJson(response.data);
      } else {
        throw Exception('Failed to add person');
      }
    } catch (e) {
      throw Exception('Failed to add person: $e');
    }
  }

  Future<Person> updatePerson(Person person, {File? profileImage}) async {
    try {
      FormData formData;

      if (profileImage != null) {
        formData = FormData.fromMap({
          ...person.toJson(),
          'profile_image': await MultipartFile.fromFile(
            profileImage.path,
            filename: profileImage.path.split('/').last,
          ),
        });
      } else {
        formData = FormData.fromMap(person.toJson());
      }

      final response = await _dio.put('people/${person.id}/', data: formData);
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
