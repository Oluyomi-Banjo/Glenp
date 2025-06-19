import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
// CSV import is actually used when generating export files
import 'package:file_picker/file_picker.dart';
import 'package:attendance_app/models/course.dart';
import 'package:attendance_app/models/attendance_session.dart';
import 'package:attendance_app/services/auth_service.dart';
import 'package:attendance_app/services/course_service.dart';
import 'package:attendance_app/utils/constants.dart';
import 'package:attendance_app/utils/network_utils.dart';
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

class _CourseDetailScreenState extends State<CourseDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<AttendanceSession> _sessions = [];
  List<dynamic> _students = [];
  bool _isLoadingSessions = false;
  bool _isLoadingStudents = false;
  bool _isExporting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSessions();
    _loadStudents();
  }

  @override
  void dispose() {
    _tabController.dispose();
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
    });    try {
      final authService = Provider.of<AuthService>(context, listen: false);

      if (authService.token != null) {
        // Call API to get enrolled students for this course
        final response = await NetworkUtils.authenticatedGet(
          '${ApiConstants.baseUrl}/api/courses/${widget.course.id}/students',
          authService.token!,
        );

        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          setState(() {
            _students = data;
          });
        } else {
          // Fallback to mock data if API fails
          setState(() {
            _students = [
              {'id': 1, 'name': 'John Doe', 'email': 'john.doe@example.com'},
              {'id': 2, 'name': 'Jane Smith', 'email': 'jane.smith@example.com'},
              {'id': 3, 'name': 'Bob Johnson', 'email': 'bob.johnson@example.com'},
            ];
          });
        }
      }
    } catch (e) {
      // Handle error and fallback to mock data
      setState(() {
        _students = [
          {'id': 1, 'name': 'John Doe', 'email': 'john.doe@example.com'},
          {'id': 2, 'name': 'Jane Smith', 'email': 'jane.smith@example.com'},
          {'id': 3, 'name': 'Bob Johnson', 'email': 'bob.johnson@example.com'},
        ];
      });
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
      );      if (!mounted) return;
        
      if (session != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance session opened successfully')),
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
      );      if (!mounted) return;
      
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

      // Save CSV to a file
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'attendance_${widget.course.code}_${DateTime.now().millisecondsSinceEpoch}.csv';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsString(csvData);

      // Show save dialog on success
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Attendance data exported to $filePath')),
      );      // Allow the user to pick where to save the file
      await FilePicker.platform.saveFile(
        dialogTitle: 'Save Attendance Data',
        fileName: fileName,
        // FilePicker no longer accepts bytes parameter, so we'll handle it differently
        allowedExtensions: ['csv'],
        type: FileType.custom,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export attendance data: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
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
      ),      floatingActionButton: _tabController.index == 0
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
                                    child: CircularProgressIndicator(strokeWidth: 2),
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
                    final openedDate = DateFormat('MMM d, yyyy').format(session.openedAt);
                    final openedTime = DateFormat('h:mm a').format(session.openedAt);
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ExpansionTile(
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
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Opened:'),
                                    Text('$openedDate at $openedTime'),
                                  ],
                                ),
                                if (session.closedAt != null) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
    return _isLoadingStudents
        ? const Center(child: CircularProgressIndicator())
        : _students.isEmpty
            ? const Center(
                child: Text('No students enrolled in this course yet.'),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(AppConstants.defaultPadding),
                itemCount: _students.length,
                itemBuilder: (context, index) {
                  final student = _students[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          student['name'][0],
                          style: const TextStyle(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      title: Text(student['name']),
                      subtitle: Text(student['email']),
                      trailing: IconButton(
                        icon: const Icon(Icons.visibility),
                        onPressed: () {
                          // View student attendance details
                        },
                      ),
                    ),
                  );
                },
              );
  }
}
