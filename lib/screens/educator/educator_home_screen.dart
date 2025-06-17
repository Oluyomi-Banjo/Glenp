import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:attendance_app/models/course.dart';
import 'package:attendance_app/services/auth_service.dart';
import 'package:attendance_app/services/course_service.dart';
import 'package:attendance_app/utils/constants.dart';
import 'package:attendance_app/screens/educator/course_detail_screen.dart';
import 'package:attendance_app/screens/educator/create_course_screen.dart';

class EducatorHomeScreen extends StatefulWidget {
  const EducatorHomeScreen({super.key});

  @override
  State<EducatorHomeScreen> createState() => _EducatorHomeScreenState();
}

class _EducatorHomeScreenState extends State<EducatorHomeScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;
    @override
  void initState() {
    super.initState();
    // Use post-frame callback to load courses after the initial build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCourses();
    });
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
    Future<void> _loadCourses({String? search}) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final courseService = Provider.of<CourseService>(context, listen: false);
    
    try {
      if (authService.token != null) {
        await courseService.fetchCourses(authService.token!, search: search);
      }
    } catch (e) {
      // Show error using a snackbar if there's an exception
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading courses: $e')),
        );
      }
    }
  }
  
  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _loadCourses();
      }
    });
  }
  
  void _performSearch() {
    _loadCourses(search: _searchController.text);
  }
  
  void _navigateToCourseDetail(Course course) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CourseDetailScreen(course: course),
      ),
    ).then((_) => _loadCourses());
  }
  
  void _navigateToCreateCourse() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateCourseScreen(),
      ),
    ).then((_) => _loadCourses());
  }
  
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final courseService = Provider.of<CourseService>(context);
    final user = authService.currentUser;
    
    return Scaffold(      appBar: AppBar(
        title: _isSearching
            ? Material(
                type: MaterialType.transparency,
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search courses...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.white70),
                  ),
                  style: const TextStyle(color: Colors.white),
                  onSubmitted: (_) => _performSearch(),
                ),
              )
            : const Text('My Courses'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadCourses(),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(user?.name ?? 'Educator'),
              accountEmail: Text(user?.email ?? ''),
              currentAccountPicture: CircleAvatar(
                child: Text(
                  user?.name.isNotEmpty == true
                      ? user!.name[0].toUpperCase()
                      : 'E',
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.school),
              title: const Text('My Courses'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Create New Course'),
              onTap: () {
                Navigator.pop(context);
                _navigateToCreateCourse();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),              onTap: () async {
                final navigator = Navigator.of(context);
                await authService.logout();
                if (!mounted) return;
                navigator.pushReplacementNamed('/login');
              },
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadCourses(),
        child: courseService.isLoading
            ? const Center(child: CircularProgressIndicator())
            : courseService.error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Error: ${courseService.error}',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => _loadCourses(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : courseService.courses.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.school_outlined,
                              size: 80,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No courses yet',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Create a course to get started',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _navigateToCreateCourse,
                              child: const Text('Create Course'),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(AppConstants.defaultPadding),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: courseService.courses.length,
                        itemBuilder: (context, index) {
                          final course = courseService.courses[index];
                          return _CourseCard(
                            course: course,
                            onTap: () => _navigateToCourseDetail(course),
                          );
                        },
                      ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateCourse,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final Course course;
  final VoidCallback onTap;

  const _CourseCard({
    required this.course,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 100,
              color: Theme.of(context).primaryColor,
              child: Center(
                child: Text(
                  course.code,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Icon(Icons.people, size: 16),
                      SizedBox(width: 4),
                      Text('View Students'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16),
                      SizedBox(width: 4),
                      Text('Manage Attendance'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
