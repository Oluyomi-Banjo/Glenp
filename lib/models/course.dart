class Course {
  final int id;
  final String name;
  final String code;
  final int educatorId;
  final DateTime createdAt;

  Course({
    required this.id,
    required this.name,
    required this.code,
    required this.educatorId,
    required this.createdAt,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'],
      name: json['name'],
      code: json['code'],
      educatorId: json['educator_id'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'educator_id': educatorId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
