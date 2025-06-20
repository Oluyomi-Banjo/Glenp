import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:attendance_app/models/course.dart';
import 'package:attendance_app/models/attendance_session.dart';
import 'package:attendance_app/services/auth_service.dart';
import 'package:attendance_app/services/course_service.dart';
import 'package:attendance_app/utils/constants.dart';
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

class _CourseDetailScreenState extends State<CourseDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<AttendanceSession> _sessions = [];
  List<dynamic> _students = [];
  bool _isLoadingSessions = false;
  bool _isLoadingStudents = false;
  bool _isExporting = false;
  String? _errorMessage;
  Timer? _autoCloseTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSessions();
    _loadStudents();

    // Start timer to check for sessions to auto-close every 5 minutes
    _autoCloseTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (mounted) {
        _autoCloseOldSessions();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _autoCloseTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoadingSessions = true;
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

        setState(() {
          _sessions = sessions;
        });

        // Check for and close sessions that are over 2 hours old
        _autoCloseOldSessions();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load attendance sessions: $e';
      });
    } finally {
      setState(() {
        _isLoadingSessions = false;
      });
    }
  }

  Future<void> _loadStudents() async {
    setState(() {
      _isLoadingStudents = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final courseService = Provider.of<CourseService>(context, listen: false);

      if (authService.token != null) {
        final students = await courseService.getEnrolledStudents(
          authService.token!,
          widget.course.id,
        );

        setState(() {
          _students = students;
        });
      }
    } catch (e) {
      // Handle error - we don't need to show error UI for the students tab
      if (kDebugMode) {
        print('Error loading students: $e');
      }
    } finally {
      setState(() {
        _isLoadingStudents = false;
      });
    }
  }

  Future<void> _createAttendanceSession() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final courseService = Provider.of<CourseService>(context, listen: false);

    if (authService.token == null) return;

    try {
      final session = await courseService.createAttendanceSession(
        authService.token!,
        widget.course.id,
      );
      if (!mounted) return;

      if (session != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Attendance session opened successfully')),
        );
        _loadSessions();
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open attendance session: $e')),
      );
    }
  }

  Future<void> _toggleSessionStatus(AttendanceSession session) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final courseService = Provider.of<CourseService>(context, listen: false);

    if (authService.token == null) return;

    try {
      final updatedSession = await courseService.updateAttendanceSession(
        authService.token!,
        session.id,
        !session.isOpen,
      );
      if (!mounted) return;

      if (updatedSession != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              session.isOpen
                  ? 'Attendance session closed'
                  : 'Attendance session reopened',
            ),
          ),
        );
        _loadSessions();
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update session: $e')),
      );
    }
  }

  Future<void> _exportAttendance() async {
    setState(() {
      _isExporting = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final courseService = Provider.of<CourseService>(context, listen: false);

      if (authService.token == null) return;

      final csvData = await courseService.exportAttendance(
        authService.token!,
        widget.course.id,
      );

      if (csvData == null) {
        throw Exception('Failed to export attendance data');
      }

      // Format the current date for the filename
      final dateFormat = DateFormat('yyyyMMdd_HHmmss');
      final timestamp = dateFormat.format(DateTime.now());

      // Save CSV to a file in the app's documents directory
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'attendance_${widget.course.code}_$timestamp.csv';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsString(csvData);

      if (!mounted) return;

      // Show success message with file path
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attendance data saved to $fileName'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'View',
            onPressed: () {
              _showExportedDataPreview(csvData, fileName);
            },
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting attendance: $e')),
        );
      }
      if (kDebugMode) {
        print('Error exporting attendance: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  void _showExportedDataPreview(String csvData, String fileName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(fileName),
        content: Container(
          width: double.maxFinite,
          height: 300,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: SelectableText(
                csvData,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Auto-closes attendance sessions that are over 2 hours old
  Future<void> _autoCloseOldSessions() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final courseService = Provider.of<CourseService>(context, listen: false);

      if (authService.token == null) return;

      final now = DateTime.now();
      final twoHoursAgo = now.subtract(const Duration(hours: 2));

      for (var session in _sessions) {
        // Skip if session is already closed
        if (!session.isOpen) continue;

        // Check if the session was opened more than 2 hours ago
        if (session.openedAt.isBefore(twoHoursAgo)) {
          if (kDebugMode) {
            print(
                'Auto-closing session #${session.id} opened at ${session.openedAt}');
          }

          // Close the session
          await courseService.updateAttendanceSession(
            authService.token!,
            session.id,
            false,
          );
        }
      }

      // Reload sessions to get updated data
      await _loadSessions();
    } catch (e) {
      if (kDebugMode) {
        print('Error auto-closing sessions: $e');
      }
      // Don't show errors to user for background auto-close
    }
  }

  void _showStudentAttendanceHistory(Map<String, dynamic> student) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${student['name']}\'s Attendance'),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _getStudentAttendanceRecords(student['id']),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text('Error: ${snapshot.error}'),
                    ],
                  ),
                );
              }

              final records = snapshot.data ?? [];

              if (records.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_busy, color: Colors.grey, size: 48),
                      SizedBox(height: 16),
                      Text('No attendance records found'),
                    ],
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                itemCount: records.length,
                itemBuilder: (context, index) {
                  final record = records[index];
                  final date = DateFormat('MMM d, yyyy').format(
                    DateTime.parse(record['date']),
                  );
                  final status = record['attended'] ? 'Present' : 'Absent';
                  final statusColor =
                      record['attended'] ? Colors.green : Colors.red;

                  return ListTile(
                    leading: Icon(
                      record['attended'] ? Icons.check_circle : Icons.cancel,
                      color: statusColor,
                    ),
                    title: Text('Session #${record['session_id']}'),
                    subtitle: Text('Date: $date'),
                    trailing: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // This is a placeholder for the API call to get attendance records
  Future<List<Map<String, dynamic>>> _getStudentAttendanceRecords(
      int studentId) async {
    // In a real application, this would make an API call to get the student's attendance records
    // For now, we'll return mock data
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay

    // Mock data - in a real app, replace with API call
    return [
      {
        'session_id': 1,
        'date': '2025-06-15T10:30:00Z',
        'attended': true,
      },
      {
        'session_id': 2,
        'date': '2025-06-17T10:30:00Z',
        'attended': true,
      },
      {
        'session_id': 3,
        'date': '2025-06-19T10:30:00Z',
        'attended': false,
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course.name),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Attendance'),
            Tab(text: 'Students'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadSessions();
              _loadStudents();
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Attendance Tab
          _buildAttendanceTab(),

          // Students Tab
          _buildStudentsTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: _createAttendanceSession,
              tooltip: 'Open New Attendance Session',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildAttendanceTab() {
    return RefreshIndicator(
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
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _isExporting ? null : _exportAttendance,
                            icon: const Icon(Icons.download),
                            label: _isExporting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Text('Export Attendance'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _createAttendanceSession,
                            icon: const Icon(Icons.add),
                            label: const Text('New Session'),
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

              if (_isLoadingSessions)
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
                      'No attendance sessions available. Create a new session to get started.',
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
                    final openedDate =
                        DateFormat('MMM d, yyyy').format(session.openedAt);
                    final openedTime =
                        DateFormat('h:mm a').format(session.openedAt);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              session.isOpen ? Colors.green : Colors.grey,
                          child: Icon(
                            session.isOpen ? Icons.check_circle : Icons.cancel,
                            color: Colors.white,
                          ),
                        ),
                        title: Text('Session #${session.id}'),
                        subtitle: Text('$openedDate at $openedTime'),
                        trailing: Switch(
                          value: session.isOpen,
                          onChanged: (value) => _toggleSessionStatus(session),
                          activeColor: Colors.green,
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Status:'),
                                    Text(
                                      session.isOpen ? 'Open' : 'Closed',
                                      style: TextStyle(
                                        color: session.isOpen
                                            ? Colors.green
                                            : Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Opened:'),
                                    Text('$openedDate at $openedTime'),
                                  ],
                                ),
                                if (session.closedAt != null) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Closed:'),
                                      Text(
                                        '${DateFormat('MMM d, yyyy').format(session.closedAt!)} at ${DateFormat('h:mm a').format(session.closedAt!)}',
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    // Navigate to session details
                                  },
                                  icon: const Icon(Icons.people),
                                  label: const Text('View Attendance Records'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentsTab() {
    return RefreshIndicator(
      onRefresh: _loadStudents,
      child: _isLoadingStudents
          ? const Center(child: CircularProgressIndicator())
          : _students.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.people_outline,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No students enrolled yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Students will appear here once they enroll in your course',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: _loadStudents,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Enrolled Students (${_students.length})',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _loadStudents,
                            tooltip: 'Refresh student list',
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        itemCount: _students.length,
                        itemBuilder: (context, index) {
                          final student = _students[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).primaryColor,
                                child: Text(
                                  student['name'][0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              title: Text(student['name']),
                              subtitle: Text(student['email']),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.analytics_outlined),
                                    tooltip: 'View attendance history',
                                    onPressed: () {
                                      // Show attendance history for this student
                                      _showStudentAttendanceHistory(student);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
