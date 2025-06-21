class Email {
  final String id;
  final String sender;
  final String subject;
  final String body;
  final DateTime date;
  final bool isRead;

  Email({
    required this.id,
    required this.sender,
    required this.subject,
    required this.body,
    required this.date,
    this.isRead = false,
  });
}
