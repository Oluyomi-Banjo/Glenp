import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'google_auth_service.dart';

class Email {
  final String id;
  final String sender;
  final String subject;
  final String body;
  final DateTime date;

  Email({
    required this.id,
    required this.sender,
    required this.subject,
    required this.body,
    required this.date,
  });
}

class EmailService {
  gmail.GmailApi? _gmailApi;
  AuthClient? _authClient;
  final GoogleAuthService _googleAuthService = GoogleAuthService();
  final _scopes = [
    gmail.GmailApi.gmailSendScope,
    gmail.GmailApi.gmailReadonlyScope
  ];
  bool _isAuthenticated = false;

  bool get isAuthenticated => _isAuthenticated && _googleAuthService.isSignedIn;

  Future<void> authenticate() async {
    try {
      // Check if user is signed in with Google
      if (!_googleAuthService.isSignedIn) {
        throw Exception(
            'Gmail API authentication failed: User not signed in with Google');
      }

      // Get auth headers from Google Sign-In
      final authHeaders = await _googleAuthService.getAuthHeaders();
      final accessToken =
          authHeaders['Authorization']?.replaceFirst('Bearer ', '');

      if (accessToken == null) {
        throw Exception(
            'Gmail API authentication failed: No access token available');
      }

      // Create auth client with the access token
      _authClient = authenticatedClient(
        http.Client(),
        AccessCredentials(
          AccessToken('Bearer', accessToken,
              DateTime.now().add(const Duration(hours: 1))),
          null,
          _scopes,
        ),
      );

      _gmailApi = gmail.GmailApi(_authClient!);
      _isAuthenticated = true;
    } catch (e) {
      _isAuthenticated = false;
      throw Exception('Gmail API authentication failed: $e');
    }
  }

  Future<void> _ensureAuthenticated() async {
    if (!_isAuthenticated ||
        _gmailApi == null ||
        !_googleAuthService.isSignedIn) {
      await authenticate();
    }
  }

  Future<void> sendEmail(String recipient, String subject, String body) async {
    try {
      await _ensureAuthenticated();

      final message = '''
From: me
To: $recipient
Subject: $subject

$body
''';

      final encodedMessage = base64Url.encode(utf8.encode(message));

      await _gmailApi!.users.messages.send(
        gmail.Message(
          raw: encodedMessage,
        ),
        'me',
      );
    } catch (e) {
      throw Exception('Gmail API send service failed: $e');
    }
  }

  Future<List<Email>> getUnreadEmails() async {
    try {
      await _ensureAuthenticated();

      final response = await _gmailApi!.users.messages.list(
        'me',
        q: 'is:unread',
        maxResults: 10,
      );

      final messages = response.messages ?? [];
      final emails = <Email>[];

      for (final message in messages) {
        final messageId = message.id!;
        final messageDetails = await _gmailApi!.users.messages.get(
          'me',
          messageId,
        );

        final headers = messageDetails.payload!.headers!;

        String subject = '';
        String sender = '';

        for (final header in headers) {
          if (header.name == 'Subject') {
            subject = header.value ?? '';
          } else if (header.name == 'From') {
            sender = header.value ?? '';
          }
        }

        String body = '';
        if (messageDetails.payload!.parts != null) {
          for (final part in messageDetails.payload!.parts!) {
            if (part.mimeType == 'text/plain' && part.body!.data != null) {
              body = utf8.decode(base64Url.decode(part.body!.data!));
              break;
            }
          }
        } else if (messageDetails.payload!.body!.data != null) {
          body = utf8
              .decode(base64Url.decode(messageDetails.payload!.body!.data!));
        }

        final date = DateTime.fromMillisecondsSinceEpoch(
          int.parse(messageDetails.internalDate!),
        );

        emails.add(Email(
          id: messageId,
          sender: sender,
          subject: subject,
          body: body,
          date: date,
        ));
      }

      return emails;
    } catch (e) {
      throw Exception('Gmail API read service failed: $e');
    }
  }

  void signOut() {
    _authClient?.close();
    _authClient = null;
    _gmailApi = null;
    _isAuthenticated = false;
  }

  Future<void> replyToEmail(String messageId, String body) async {
    try {
      await _ensureAuthenticated();

      final messageDetails = await _gmailApi!.users.messages.get(
        'me',
        messageId,
      );

      final headers = messageDetails.payload!.headers!;

      String subject = '';
      String sender = '';
      String references = '';
      String inReplyTo = '';

      for (final header in headers) {
        if (header.name == 'Subject') {
          subject = header.value ?? '';
          if (!subject.toLowerCase().startsWith('re:')) {
            subject = 'Re: $subject';
          }
        } else if (header.name == 'From') {
          sender = header.value ?? '';
        } else if (header.name == 'Message-ID') {
          inReplyTo = header.value ?? '';
          references = header.value ?? '';
        } else if (header.name == 'References') {
          references = '${header.value} $inReplyTo';
        }
      }

      final message = '''
From: me
To: $sender
Subject: $subject
References: $references
In-Reply-To: $inReplyTo

$body
''';

      final encodedMessage = base64Url.encode(utf8.encode(message));

      await _gmailApi!.users.messages.send(
        gmail.Message(
          raw: encodedMessage,
          threadId: messageDetails.threadId,
        ),
        'me',
      );
    } catch (e) {
      throw Exception('Gmail API reply service failed: $e');
    }
  }

  Future<void> deleteEmail(String messageId) async {
    try {
      await _ensureAuthenticated();

      await _gmailApi!.users.messages.trash(
        'me',
        messageId,
      );
    } catch (e) {
      throw Exception('Gmail API delete service failed: $e');
    }
  }

  Future<void> forwardEmail(
      String messageId, String recipient, String additionalComment) async {
    try {
      await _ensureAuthenticated();

      final messageDetails = await _gmailApi!.users.messages.get(
        'me',
        messageId,
      );

      final headers = messageDetails.payload!.headers!;

      String subject = '';
      String originalSender = '';
      String originalBody = '';

      for (final header in headers) {
        if (header.name == 'Subject') {
          subject = header.value ?? '';
          if (!subject.toLowerCase().startsWith('fwd:')) {
            subject = 'Fwd: $subject';
          }
        } else if (header.name == 'From') {
          originalSender = header.value ?? '';
        }
      }

      if (messageDetails.payload!.parts != null) {
        for (final part in messageDetails.payload!.parts!) {
          if (part.mimeType == 'text/plain' && part.body!.data != null) {
            originalBody = utf8.decode(base64Url.decode(part.body!.data!));
            break;
          }
        }
      } else if (messageDetails.payload!.body!.data != null) {
        originalBody =
            utf8.decode(base64Url.decode(messageDetails.payload!.body!.data!));
      }

      final forwardedMessage = '''
From: me
To: $recipient
Subject: $subject

$additionalComment

---------- Forwarded message ---------
From: $originalSender
Subject: ${subject.startsWith('Fwd:') ? subject.substring(5) : subject}

$originalBody
''';

      final encodedMessage = base64Url.encode(utf8.encode(forwardedMessage));

      await _gmailApi!.users.messages.send(
        gmail.Message(
          raw: encodedMessage,
        ),
        'me',
      );
    } catch (e) {
      throw Exception('Gmail API forward service failed: $e');
    }
  }
}
