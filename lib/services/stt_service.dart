import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'package:logging/logging.dart';
import '../utils/app_logger.dart';

class STTService {
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _isInitialized = false;
  bool _permissionRequested = false;
  final Logger _logger = AppLogger.getLogger('STTService');

  // Property to check if permissions need to be opened in settings
  bool get needsToOpenSettings => _permissionRequested && !_isInitialized;

  bool get isSimulator {
    if (Platform.isIOS) {
      return !Platform.environment.containsKey('FLUTTER_TEST') &&
          (Platform.isIOS && !Platform.isAndroid);
    }
    return false;
  }

  Future<void> _initialize() async {
    if (!_isInitialized) {
      try {
        _logger.info("Initializing Speech-to-Text service...");
        _logger.info("Running on simulator: $isSimulator");

        // Request microphone permission with better handling
        if (!_permissionRequested) {
          _permissionRequested = true;

          // Check current permission status
          PermissionStatus status = await Permission.microphone.status;
          _logger.info("Current microphone permission status: $status");

          if (status.isDenied) {
            _logger.info("Requesting microphone permission...");
            status = await Permission.microphone.request();
            _logger.info("Permission request result: $status");
          }

          if (status.isPermanentlyDenied) {
            if (isSimulator) {
              _logger.warning(
                  "Running on simulator - permission handling may be different");
              // On simulator, we'll try to proceed anyway
            } else {
              // We'll check needsToOpenSettings property to show dialog
              throw Exception(
                  'Speech-to-Text service failed: Microphone permission permanently denied. Please enable microphone access in device settings.');
            }
          }

          if (status.isDenied) {
            if (isSimulator) {
              _logger.warning(
                  "Running on simulator - permission handling may be different");
              // On simulator, we'll try to proceed anyway
            } else {
              throw Exception(
                  'Speech-to-Text service failed: Microphone permission denied. Please grant microphone access to use voice commands.');
            }
          }
        }

        // Initialize speech recognition
        _isInitialized = await _speechToText.initialize(
          debugLogging: kDebugMode,
          onStatus: (status) => _logger.info('Speech-to-Text status: $status'),
        );

        // Add error listener after initialization
        _speechToText.errorListener = (error) {
          _logger.warning('Speech-to-Text error: $error');
          if (error.errorMsg.contains('permission')) {
            _logger.warning('Permission error detected in STT');
          }
        };

        if (!_isInitialized) {
          if (isSimulator) {
            _logger.warning(
                "Warning - Speech recognition may not work properly on simulator");
            // On simulator, we'll set initialized to true anyway to allow testing
            _isInitialized = true;
          } else {
            throw Exception(
                'Speech-to-Text service failed: Speech recognition initialization failed. This device may not support speech recognition.');
          }
        }

        _logger.info("Speech-to-Text service initialized successfully");
      } catch (e) {
        _logger.severe("Speech-to-Text initialization error: $e");
        if (e.toString().contains('Speech-to-Text service failed:')) {
          rethrow;
        } else {
          throw Exception('Speech-to-Text service failed: $e');
        }
      }
    }
  }

  Future<String> listen() async {
    try {
      await _initialize();

      if (!_isInitialized) {
        throw Exception(
            'Speech-to-Text service failed: Service not initialized');
      }

      // Double-check permission before listening
      _logger.info('Double-checking microphone permission before listening...');
      final permissionStatus = await Permission.microphone.status;
      _logger.info(
          'Microphone permission status before listening: $permissionStatus');

      if (!permissionStatus.isGranted && !isSimulator) {
        throw Exception(
            'Speech-to-Text service failed: Microphone permission not granted');
      }

      String transcript = '';
      bool isComplete = false;

      if (isSimulator) {
        _logger.info('Running on simulator - using simulated speech input');
        // Simulate a delay and return a test transcript
        await Future.delayed(const Duration(seconds: 2));
        transcript = "This is a simulated transcript from the simulator";
        isComplete = true;
      } else {
        await _speechToText.listen(
          onResult: (result) {
            transcript = result.recognizedWords;
            isComplete = result.finalResult;
            _logger.info(
                'Speech-to-Text result: $transcript (final: $isComplete)');
          },
          listenFor: const Duration(seconds: 8),
          pauseFor: const Duration(seconds: 3),
          listenOptions: stt.SpeechListenOptions(
            partialResults: true,
            listenMode: stt.ListenMode.confirmation,
          ),
          localeId: 'en_US',
        );

        // Wait for listening to complete
        int attempts = 0;
        while (_speechToText.isListening && attempts < 100) {
          await Future.delayed(const Duration(milliseconds: 100));
          attempts++;
        }

        // Wait a bit more for final result
        await Future.delayed(const Duration(milliseconds: 500));
      }

      _logger.info('Final transcript: "$transcript"');

      if (transcript.isEmpty && !isSimulator) {
        throw Exception(
            'Speech-to-Text service failed: No speech detected. Please speak clearly and try again.');
      }

      return transcript.trim();
    } catch (e) {
      _logger.severe("Speech-to-Text listen error: $e");
      if (e.toString().contains('Speech-to-Text service failed:')) {
        rethrow;
      } else {
        throw Exception('Speech-to-Text service failed: $e');
      }
    }
  }

  bool get isListening => _speechToText.isListening;

  // Method for tap-to-start functionality
  Future<bool> startListening({
    required Function(String) onResult,
    required Function(dynamic) onError,
  }) async {
    try {
      await _initialize();

      // Check if speech recognition is available
      if (!_speechToText.isAvailable) {
        _logger.warning("Speech recognition not available on this device");
        onError("Speech recognition not available");
        return false;
      }

      // On iOS, we need a special handling for simulator and real devices
      if (Platform.isIOS) {
        try {
          final result = await _speechToText.listen(
            onResult: (result) {
              final recognizedWords = result.recognizedWords;
              onResult(recognizedWords);
            },
            listenFor: const Duration(seconds: 30),
            pauseFor: const Duration(seconds: 5),
            listenOptions: stt.SpeechListenOptions(
              partialResults: true,
              cancelOnError: true,
            ),
            localeId: 'en_US',
          );
          return result ?? false;
        } catch (e) {
          _logger.severe("iOS-specific speech recognition error: $e");

          // Special handling for simulator
          if (isSimulator) {
            _logger.info(
                "Running on iOS simulator - using mock speech recognition");
            // Simulate successful start and return mock results after delay
            Future.delayed(const Duration(milliseconds: 500), () {
              onResult("This is a simulated response on iOS simulator");
            });
            return true;
          }

          onError(e);
          return false;
        }
      } else {
        // Android or other platforms
        final result = await _speechToText.listen(
          onResult: (result) {
            final recognizedWords = result.recognizedWords;
            onResult(recognizedWords);
          },
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 5),
          listenOptions: stt.SpeechListenOptions(
            partialResults: true,
            cancelOnError: true,
          ),
          localeId: 'en_US',
        );

        return result ?? false;
      }
    } catch (e) {
      _logger.severe("Error starting speech recognition: $e");
      onError(e);
      return false;
    }
  }

  // Method to stop listening
  Future<void> stopListening() async {
    await _speechToText.stop();
  }

  void dispose() {
    _speechToText.stop();
  }
}
