import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:attendance_app/models/course.dart';
import 'package:attendance_app/models/attendance_session.dart';
import 'package:attendance_app/utils/constants.dart';
import 'package:attendance_app/utils/network_utils.dart';

class CourseService extends ChangeNotifier {
  List<Course> _courses = [];
  bool _isLoading = false;
  String? _error;

  List<Course> get courses => _courses;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Future<void> fetchCourses(String token, {String? search}) async {
    // Set loading state but don't notify during build
    _isLoading = true;
    _error = null;
    // Notify listeners after current build completes
    Future.microtask(() => notifyListeners());

    try {
      String url = '${ApiConstants.baseUrl}${ApiConstants.courses}';
      if (search != null && search.isNotEmpty) {
        url += '?search=$search';
      }

      final response = await NetworkUtils.authenticatedGet(url, token);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _courses = data.map((json) => Course.fromJson(json)).toList();
      } else {
        _error = 'Failed to fetch courses: ${response.statusCode}';
      }
    } catch (e) {
      _error = 'Network error: $e';
    } finally {
      _isLoading = false;
      // Notify listeners after data is loaded
      Future.microtask(() => notifyListeners());
    }
  }

  Future<Map<String, dynamic>> createCourse(
      String token, String name, String code, String passkey) async {
    try {
      final response = await NetworkUtils.authenticatedPost(
        '${ApiConstants.baseUrl}${ApiConstants.courses}',
        token,
        {
          'name': name,
          'code': code,
          'passkey': passkey,
        },
      );

      if (response.statusCode == 200) {
        final course = Course.fromJson(jsonDecode(response.body));
        _courses.add(course);
        notifyListeners();
        return {'success': true, 'course': course};
      } else {
        return {
          'success': false,
          'message':
              'Failed to create course: ${jsonDecode(response.body)['detail']}',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> enrollInCourse(
      String token, int courseId, String passkey) async {
    try {
      final response = await NetworkUtils.authenticatedPost(
        '${ApiConstants.baseUrl}${ApiConstants.courses}/$courseId/register',
        token,
        {
          'course_id': courseId,
          'passkey': passkey,
        },
      );

      if (response.statusCode == 200) {
        // Refresh courses after successful enrollment
        await fetchCourses(token);
        return {'success': true};
      } else {
        return {
          'success': false,
          'message':
              'Failed to enroll in course: ${jsonDecode(response.body)['detail']}',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  Future<List<AttendanceSession>> getCourseSessions(
      String token, int courseId) async {
    try {
      final response = await NetworkUtils.authenticatedGet(
        '${ApiConstants.baseUrl}${ApiConstants.sessions}/course/$courseId',
        token,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => AttendanceSession.fromJson(json)).toList();
      } else {
        throw Exception('Failed to fetch sessions: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching sessions: $e');
      }
      return [];
    }
  }

  Future<AttendanceSession?> createAttendanceSession(
      String token, int courseId) async {
    try {
      final response = await NetworkUtils.authenticatedPost(
        '${ApiConstants.baseUrl}${ApiConstants.sessions}',
        token,
        {
          'course_id': courseId,
        },
      );

      if (response.statusCode == 200) {
        return AttendanceSession.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to create session: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error creating session: $e');
      }
      return null;
    }
  }

  Future<AttendanceSession?> updateAttendanceSession(
      String token, int sessionId, bool isOpen) async {
    try {
      final response = await NetworkUtils.authenticatedPatch(
        '${ApiConstants.baseUrl}${ApiConstants.sessions}/$sessionId',
        token,
        {
          'is_open': isOpen,
        },
      );

      if (response.statusCode == 200) {
        return AttendanceSession.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Failed to update session: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating session: $e');
      }
      return null;
    }
  }

  Future<String?> exportAttendance(String token, int courseId) async {
    try {
      final response = await http.get(
        Uri.parse(
            '${ApiConstants.baseUrl}/api/attendance/export/course/$courseId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return utf8.decode(response.bodyBytes);
      } else {
        throw Exception('Failed to export attendance: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error exporting attendance: $e');
      }
      return null;
    }
  }
}
