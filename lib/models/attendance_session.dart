class AttendanceSession {
  final int id;
  final int courseId;
  final bool isOpen;
  final DateTime openedAt;
  final DateTime? closedAt;

  AttendanceSession({
    required this.id,
    required this.courseId,
    required this.isOpen,
    required this.openedAt,
    this.closedAt,
  });

  factory AttendanceSession.fromJson(Map<String, dynamic> json) {
    return AttendanceSession(
      id: json['id'],
      courseId: json['course_id'],
      isOpen: json['is_open'],
      openedAt: DateTime.parse(json['opened_at']),
      closedAt: json['closed_at'] != null ? DateTime.parse(json['closed_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'course_id': courseId,
      'is_open': isOpen,
      'opened_at': openedAt.toIso8601String(),
      'closed_at': closedAt?.toIso8601String(),
    };
  }
}
