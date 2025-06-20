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

  @override
  void dispose() {
    _courseIdController.dispose();
    _passKeyController.dispose();
    super.dispose();
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
  }

  @override
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
            'Enter the course ID and passkey provided by your instructor.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
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
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.red.withAlpha(26), // 0.1 opacity = ~26 alpha
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
                    color:
                        Colors.green.withAlpha(26), // 0.1 opacity = ~26 alpha
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
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _enrollInCourse,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Enroll in Course'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
