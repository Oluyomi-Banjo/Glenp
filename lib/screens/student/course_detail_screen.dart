import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:attendance_app/models/course.dart';
import 'package:attendance_app/models/attendance_session.dart';
import 'package:attendance_app/services/auth_service.dart';
import 'package:attendance_app/services/course_service.dart';
import 'package:attendance_app/utils/constants.dart';
import 'package:attendance_app/utils/network_utils.dart';
import 'package:attendance_app/screens/student/face_enrollment_screen.dart';
import 'package:attendance_app/screens/student/attendance_check_in_screen.dart';
import 'package:intl/intl.dart';

class CourseDetailScreen extends StatefulWidget {
  final Course course;

  const CourseDetailScreen({
    super.key,
    required this.course,
  });

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  List<AttendanceSession> _sessions = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isOnLocalNetwork = false;

  @override
  void initState() {
    super.initState();
    _loadSessions();
    _checkNetworkStatus();
  }

  Future<void> _checkNetworkStatus() async {
    final isOnNetwork = await NetworkUtils.isOnLocalNetwork();
    if (mounted) {
      setState(() {
        _isOnLocalNetwork = isOnNetwork;
      });
    }
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final courseService = Provider.of<CourseService>(context, listen: false);

      if (authService.token != null) {
        final sessions = await courseService.getCourseSessions(
          authService.token!,
          widget.course.id,
        );

        if (mounted) {
          setState(() {
            _sessions = sessions;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load attendance sessions: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToFaceEnrollment() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FaceEnrollmentScreen(course: widget.course),
      ),
    );
  }

  void _navigateToAttendanceCheckIn(AttendanceSession session) {
    if (!_isOnLocalNetwork) {
      _showNetworkErrorDialog();
      return;
    }

    if (!session.isOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This attendance session is closed')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AttendanceCheckInScreen(
          course: widget.course,
          session: session,
        ),
      ),
    );
  }

  void _showNetworkErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Network Error'),
        content: const Text(
          'You must be connected to the local network to check in for attendance. '
          'Please connect to the university Wi-Fi and try again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _checkNetworkStatus();
            },
            child: const Text('Retry Connection'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadSessions();
              _checkNetworkStatus();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSessions,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.defaultPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Course Info Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.school,
                              size: 24,
                              color: Theme.of(context).primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.course.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.code, size: 20),
                            const SizedBox(width: 8),
                            Text('Course Code: ${widget.course.code}'),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.face, size: 20),
                            const SizedBox(width: 8),
                            const Text('Face Enrollment: '),
                            TextButton(
                              onPressed: _navigateToFaceEnrollment,
                              child: const Text('Enroll Now'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              _isOnLocalNetwork
                                  ? Icons.wifi
                                  : Icons.wifi_off,
                              size: 20,
                              color: _isOnLocalNetwork
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isOnLocalNetwork
                                  ? 'Connected to Local Network'
                                  : 'Not Connected to Local Network',
                              style: TextStyle(
                                color: _isOnLocalNetwork
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Attendance Sessions
                const Text(
                  'Attendance Sessions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_errorMessage != null)
                  Center(
                    child: Column(
                      children: [
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadSessions,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                else if (_sessions.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No attendance sessions available for this course yet.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _sessions.length,
                    itemBuilder: (context, index) {
                      final session = _sessions[index];
                      final openedDate = DateFormat('MMM d, yyyy').format(session.openedAt);
                      final openedTime = DateFormat('h:mm a').format(session.openedAt);
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: session.isOpen
                                ? Colors.green
                                : Colors.grey,
                            child: Icon(
                              session.isOpen
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              color: Colors.white,
                            ),
                          ),
                          title: Text('Session #${session.id}'),
                          subtitle: Text('$openedDate at $openedTime'),
                          trailing: ElevatedButton(
                            onPressed: session.isOpen
                                ? () => _navigateToAttendanceCheckIn(session)
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: session.isOpen
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                            child: Text(
                              session.isOpen ? 'Check In' : 'Closed',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
