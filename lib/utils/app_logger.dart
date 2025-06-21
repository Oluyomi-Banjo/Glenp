import 'package:logging/logging.dart';
import 'dart:io' show File, Directory, FileMode;
import 'package:path_provider/path_provider.dart';
import 'dart:developer' as developer;

/// A utility class for logging throughout the application
class AppLogger {
  static final Map<String, Logger> _loggers = {};
  static bool _initialized = false;
  static File? _logFile;

  /// Initialize the logging system for the entire app
  static Future<void> init() async {
    if (_initialized) return;
    
    Logger.root.level = Level.INFO; // Set the default log level
    
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final logDir = Directory('${appDir.path}/logs');
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      
      final logFilePath = '${logDir.path}/app_log.txt';
      _logFile = File(logFilePath);
      
      // Initialize log file with a header
      if (!await _logFile!.exists()) {
        await _logFile!.writeAsString('=== Voice Email Assistant Log ===\n');
      }
    } catch (e) {
      // If file logging fails, we'll fallback to console only
      developer.log('Failed to initialize log file: $e', name: 'AppLogger');
    }
    
    Logger.root.onRecord.listen((record) {
      final message = '${record.time}: ${record.level.name}: ${record.loggerName}: ${record.message}';
      
      // Use developer.log for debugging (doesn't trigger print lint warnings)
      developer.log(message, name: record.loggerName);
      
      // Also log to file if available
      if (_logFile != null) {
        try {
          _logFile!.writeAsStringSync('$message\n', mode: FileMode.append);
          
          // Log errors and stack traces to file
          if (record.error != null) {
            _logFile!.writeAsStringSync('Error: ${record.error}\n', mode: FileMode.append);
          }
          if (record.stackTrace != null) {
            _logFile!.writeAsStringSync('Stack trace: ${record.stackTrace}\n', mode: FileMode.append);
          }
        } catch (e) {
          // Just use console if file write fails
          developer.log('Failed to write to log file: $e', name: 'AppLogger');
        }
      }
    });
    
    _initialized = true;
  }

  /// Get a logger for a specific class or component
  static Logger getLogger(String name) {
    if (!_loggers.containsKey(name)) {
      _loggers[name] = Logger(name);
    }
    return _loggers[name]!;
  }
}
