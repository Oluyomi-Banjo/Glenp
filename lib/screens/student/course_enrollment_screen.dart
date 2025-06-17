import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:attendance_app/services/auth_service.dart';
import 'package:attendance_app/services/course_service.dart';
import 'package:attendance_app/utils/constants.dart';

class CourseEnrollmentScreen extends StatefulWidget {
  const CourseEnrollmentScreen({super.key});

  @override
  State<CourseEnrollmentScreen> createState() => _CourseEnrollmentScreenState();
}

class _CourseEnrollmentScreenState extends State<CourseEnrollmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _courseIdController = TextEditingController();
  final _passKeyController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  List<Map<String, dynamic>> _availableCourses = [];

  @override
  void initState() {
    super.initState();
    _loadAvailableCourses();
  }

  @override
  void dispose() {
    _courseIdController.dispose();
    _passKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableCourses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final courseService = Provider.of<CourseService>(context, listen: false);

      if (authService.token != null) {
        await courseService.fetchCourses(authService.token!);
        
        final courses = courseService.courses;
        _availableCourses = courses.map((course) => {
          'id': course.id,
          'name': course.name,
          'code': course.code,
        }).toList();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load courses: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _enrollInCourse() async {
    if (_formKey.currentState?.validate() != true) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final courseService = Provider.of<CourseService>(context, listen: false);

      if (authService.token != null) {
        final courseId = int.parse(_courseIdController.text);
        final passkey = _passKeyController.text;

        final result = await courseService.enrollInCourse(
          authService.token!,
          courseId,
          passkey,
        );

        if (result['success']) {
          setState(() {
            _successMessage = 'Successfully enrolled in course!';
            _courseIdController.clear();
            _passKeyController.clear();
          });
        } else {
          setState(() {
            _errorMessage = result['message'];
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error enrolling in course: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enroll in Course'),
      ),
      body: _buildEnrollmentContent(),
    );
  }
  
  Widget _buildEnrollmentContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'Course Registration',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter the course ID and passkey provided by your educator to enroll in a course.',
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),

          // Available Courses
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Available Courses',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _availableCourses.isEmpty
                          ? const Text('No courses available')
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _availableCourses.length,
                              itemBuilder: (context, index) {
                                final course = _availableCourses[index];
                                return ListTile(
                                  title: Text('${course['name']} (${course['code']})'),
                                  subtitle: Text('Course ID: ${course['id']}'),
                                  onTap: () {
                                    setState(() {
                                      _courseIdController.text = course['id'].toString();
                                    });
                                  },
                                );
                              },
                            ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Enrollment Form
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Course ID Field
                TextFormField(
                  controller: _courseIdController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Course ID',
                    prefixIcon: Icon(Icons.school),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the course ID';
                    }
                    if (int.tryParse(value) == null) {
                      return 'Course ID must be a number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Passkey Field
                TextFormField(
                  controller: _passKeyController,
                  decoration: const InputDecoration(
                    labelText: 'Passkey',
                    prefixIcon: Icon(Icons.vpn_key),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the passkey';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Error Message
                if (_errorMessage != null)                    Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.red.withAlpha(26), // 0.1 * 255 = ~26
                    child: Row(
                      children: [
                        const Icon(Icons.error, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Success Message
                if (_successMessage != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.green.withAlpha(26), // 0.1 * 255 = ~26
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _successMessage!,
                            style: const TextStyle(color: Colors.green),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                // Enroll Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _enrollInCourse,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Enroll in Course'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
