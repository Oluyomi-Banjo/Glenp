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
      if (kDebugMode) {
        print('Enrolling in course $courseId with passkey $passkey');
      }

      final Map<String, dynamic> payload = {
        'course_id': courseId,
        'passkey': passkey,
      };

      final response = await NetworkUtils.authenticatedPost(
        '${ApiConstants.baseUrl}${ApiConstants.enrollment}',
        token,
        payload,
      );

      if (kDebugMode) {
        print('Enrollment response status: ${response.statusCode}');
        print('Enrollment response body: ${response.body}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true};
      } else {
        final Map<String, dynamic> error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['detail'] ?? 'Failed to enroll in course',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error enrolling in course: $e');
      }
      return {
        'success': false,
        'message': 'Network error: $e',
      };
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
      final response = await NetworkUtils.authenticatedGet(
        '${ApiConstants.baseUrl}${ApiConstants.attendance}/export/course/$courseId',
        token,
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

  // Get courses the student is enrolled in
  Future<void> fetchEnrolledCourses(String token, {String? search}) async {
    // Set loading state but don't notify during build
    _isLoading = true;
    _error = null;
    // Notify listeners after current build completes
    Future.microtask(() => notifyListeners());

    try {
      String url = '${ApiConstants.baseUrl}${ApiConstants.courses}/enrolled';
      if (search != null && search.isNotEmpty) {
        url += '?search=$search';
      }

      if (kDebugMode) {
        print('Fetching enrolled courses from: $url');
      }

      final response = await NetworkUtils.authenticatedGet(url, token);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _courses = data.map((json) => Course.fromJson(json)).toList();
        if (kDebugMode) {
          print('Fetched ${_courses.length} enrolled courses');
        }
      } else {
        _error = 'Failed to fetch enrolled courses: ${response.statusCode}';
        if (kDebugMode) {
          print('Error fetching enrolled courses: ${response.statusCode}');
          print('Response body: ${response.body}');
        }
      }
    } catch (e) {
      _error = 'Network error: $e';
      if (kDebugMode) {
        print('Error fetching enrolled courses: $e');
      }
    } finally {
      _isLoading = false;
      // Notify listeners after data is loaded
      Future.microtask(() => notifyListeners());
    }
  }

  // Get all available courses for enrollment
  Future<void> fetchAvailableCourses(String token,
      {String? search, String? courseCode}) async {
    // Set loading state but don't notify during build
    _isLoading = true;
    _error = null;
    // Notify listeners after current build completes
    Future.microtask(() => notifyListeners());

    try {
      String url = '${ApiConstants.baseUrl}${ApiConstants.courses}/available';

      // Build query parameters
      List<String> queryParams = [];
      if (search != null && search.isNotEmpty) {
        queryParams.add('search=$search');
      }
      if (courseCode != null && courseCode.isNotEmpty) {
        queryParams.add('code=$courseCode');
      }

      if (queryParams.isNotEmpty) {
        url += '?${queryParams.join('&')}';
      }

      if (kDebugMode) {
        print('Fetching available courses from: $url');
      }

      final response = await NetworkUtils.authenticatedGet(url, token);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _courses = data.map((json) => Course.fromJson(json)).toList();
        if (kDebugMode) {
          print('Fetched ${_courses.length} available courses');
        }
      } else {
        _error = 'Failed to fetch available courses: ${response.statusCode}';
        if (kDebugMode) {
          print('Error fetching available courses: ${response.statusCode}');
          print('Response body: ${response.body}');
        }
      }
    } catch (e) {
      _error = 'Network error: $e';
      if (kDebugMode) {
        print('Error fetching available courses: $e');
      }
    } finally {
      _isLoading = false;
      // Notify listeners after data is loaded
      Future.microtask(() => notifyListeners());
    }
  }

  Future<List<Map<String, dynamic>>> getEnrolledStudents(
      String token, int courseId) async {
    try {
      final response = await NetworkUtils.authenticatedGet(
        '${ApiConstants.baseUrl}${ApiConstants.courses}/$courseId/students',
        token,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception(
            'Failed to fetch enrolled students: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching enrolled students: $e');
      }
      // Return empty list on error
      return [];
    }
  }
}
