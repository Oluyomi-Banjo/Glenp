import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

enum LivenessAction { blink, turnLeft, turnRight, nod, smile }

class LivenessDetectionManager {
  final FaceDetector _faceDetector;
  final CameraController cameraController;

  // History of face detections for analysis
  final List<Face?> _faceHistory = [];
  final int _maxHistorySize = 15; // Store 15 frames for analysis

  // Action detection flags
  bool _isProcessingFrames = false;
  bool _actionDetected = false;
  LivenessAction? _currentAction;
  Completer<bool> _detectionCompleter = Completer<bool>();

  // Confidence thresholds for action detection
  static const double _blinkThreshold = 0.1; // Eye open probability threshold
  static const double _turnThreshold =
      20.0; // Head rotation threshold in degrees
  static const double _smileThreshold = 0.7; // Smile probability threshold

  LivenessDetectionManager({
    required this.cameraController,
    required FaceDetector faceDetector,
  }) : _faceDetector = faceDetector;

  /// Start detecting the given liveness action
  /// Returns true if action was detected, false otherwise
  Future<bool> detectAction(LivenessAction action, int durationSeconds) async {
    if (_isProcessingFrames) {
      return false;
    }

    _isProcessingFrames = true;
    _actionDetected = false;
    _currentAction = action;
    _faceHistory.clear();

    // Reset completer
    if (_detectionCompleter.isCompleted) {
      _detectionCompleter = Completer<bool>();
    }

    // Set timeout for action detection
    Timer(Duration(seconds: durationSeconds), () {
      if (!_detectionCompleter.isCompleted) {
        _detectionCompleter.complete(_actionDetected);
      }
    });

    // Start processing camera frames
    _startFrameProcessing();

    // Wait for result
    return _detectionCompleter.future;
  }

  /// Stop the liveness detection
  void stopDetection() {
    _isProcessingFrames = false;
    if (!_detectionCompleter.isCompleted) {
      _detectionCompleter.complete(_actionDetected);
    }
  }

  /// Process camera frames for liveness detection
  void _startFrameProcessing() async {
    if (!_isProcessingFrames ||
        _actionDetected ||
        cameraController.value.isStreamingImages) {
      return;
    }

    try {
      await cameraController.startImageStream((CameraImage image) async {
        if (!_isProcessingFrames || _actionDetected) {
          cameraController.stopImageStream();
          return;
        }

        // Process the image to detect faces
        try {
          final inputImage = _convertCameraImageToInputImage(image);
          if (inputImage != null) {
            final faces = await _faceDetector.processImage(inputImage);

            // If a face is detected, add it to history
            if (faces.isNotEmpty) {
              final face = faces.first;
              _addFaceToHistory(face);

              // Check if the current action is detected
              final actionDetected = await _checkActionDetected();
              if (actionDetected && !_detectionCompleter.isCompleted) {
                _actionDetected = true;
                cameraController.stopImageStream();
                _detectionCompleter.complete(true);
              }
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error processing frame: $e');
          }
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error starting camera stream: $e');
      }
      if (!_detectionCompleter.isCompleted) {
        _detectionCompleter.complete(false);
      }
    }
  }

  /// Add a face to the history list
  void _addFaceToHistory(Face face) {
    _faceHistory.add(face);
    if (_faceHistory.length > _maxHistorySize) {
      _faceHistory.removeAt(0);
    }
  }

  /// Check if the current action has been detected
  Future<bool> _checkActionDetected() async {
    if (_faceHistory.length < 5) {
      return false; // Need at least 5 frames for analysis
    }

    switch (_currentAction) {
      case LivenessAction.blink:
        return _detectBlink();
      case LivenessAction.turnLeft:
        return _detectTurnLeft();
      case LivenessAction.turnRight:
        return _detectTurnRight();
      case LivenessAction.nod:
        return _detectNod();
      case LivenessAction.smile:
        return _detectSmile();
      default:
        return false;
    }
  }

  /// Detect if the user blinked
  /// Looks for a sequence of: eyes open -> eyes closed -> eyes open
  bool _detectBlink() {
    if (_faceHistory.length < 5) return false;

    // First make sure we have valid eye information
    bool hasValidEyeInfo = true;
    for (var face in _faceHistory) {
      if (face == null ||
          face.leftEyeOpenProbability == null ||
          face.rightEyeOpenProbability == null) {
        hasValidEyeInfo = false;
        break;
      }
    }

    if (!hasValidEyeInfo) return false;

    // Look for the blink pattern in the sequence
    bool foundEyesOpen = false;
    bool foundEyesClosed = false;
    bool foundEyesReopened = false;

    for (int i = 0; i < _faceHistory.length; i++) {
      final face = _faceHistory[i]!;
      final leftEyeOpen = face.leftEyeOpenProbability! > _blinkThreshold;
      final rightEyeOpen = face.rightEyeOpenProbability! > _blinkThreshold;

      // Check for eyes open (beginning)
      if (!foundEyesOpen && leftEyeOpen && rightEyeOpen) {
        foundEyesOpen = true;
        continue;
      }

      // Check for eyes closed (middle)
      if (foundEyesOpen && !foundEyesClosed && !leftEyeOpen && !rightEyeOpen) {
        foundEyesClosed = true;
        continue;
      }

      // Check for eyes reopened (end)
      if (foundEyesOpen && foundEyesClosed && leftEyeOpen && rightEyeOpen) {
        foundEyesReopened = true;
        break;
      }
    }

    return foundEyesOpen && foundEyesClosed && foundEyesReopened;
  }

  /// Detect if the user turned their head left
  bool _detectTurnLeft() {
    if (_faceHistory.length < 5) return false;

    // Get average initial head position
    double initialHeadAngle = 0;
    int count = 0;
    for (int i = 0; i < 3 && i < _faceHistory.length; i++) {
      if (_faceHistory[i] != null && _faceHistory[i]!.headEulerAngleY != null) {
        initialHeadAngle += _faceHistory[i]!.headEulerAngleY!;
        count++;
      }
    }

    if (count == 0) return false;
    initialHeadAngle /= count;

    // Look for significant left turn
    bool foundTurn = false;
    for (int i = 3; i < _faceHistory.length; i++) {
      if (_faceHistory[i] != null && _faceHistory[i]!.headEulerAngleY != null) {
        // Negative Y angle means turning left
        if (_faceHistory[i]!.headEulerAngleY! <
            (initialHeadAngle - _turnThreshold)) {
          foundTurn = true;
          break;
        }
      }
    }

    return foundTurn;
  }

  /// Detect if the user turned their head right
  bool _detectTurnRight() {
    if (_faceHistory.length < 5) return false;

    // Get average initial head position
    double initialHeadAngle = 0;
    int count = 0;
    for (int i = 0; i < 3 && i < _faceHistory.length; i++) {
      if (_faceHistory[i] != null && _faceHistory[i]!.headEulerAngleY != null) {
        initialHeadAngle += _faceHistory[i]!.headEulerAngleY!;
        count++;
      }
    }

    if (count == 0) return false;
    initialHeadAngle /= count;

    // Look for significant right turn
    bool foundTurn = false;
    for (int i = 3; i < _faceHistory.length; i++) {
      if (_faceHistory[i] != null && _faceHistory[i]!.headEulerAngleY != null) {
        // Positive Y angle means turning right
        if (_faceHistory[i]!.headEulerAngleY! >
            (initialHeadAngle + _turnThreshold)) {
          foundTurn = true;
          break;
        }
      }
    }

    return foundTurn;
  }

  /// Detect if the user nodded (head up then down)
  bool _detectNod() {
    if (_faceHistory.length < 5) return false;

    // Get average initial head position
    double initialHeadAngle = 0;
    int count = 0;
    for (int i = 0; i < 3 && i < _faceHistory.length; i++) {
      if (_faceHistory[i] != null && _faceHistory[i]!.headEulerAngleX != null) {
        initialHeadAngle += _faceHistory[i]!.headEulerAngleX!;
        count++;
      }
    }

    if (count == 0) return false;
    initialHeadAngle /= count;

    // Look for head going up and then down
    bool headWentUp = false;
    bool headWentDown = false;

    for (int i = 3; i < _faceHistory.length; i++) {
      if (_faceHistory[i] != null && _faceHistory[i]!.headEulerAngleX != null) {
        // Negative X angle means tilting up
        if (!headWentUp &&
            _faceHistory[i]!.headEulerAngleX! <
                (initialHeadAngle - _turnThreshold)) {
          headWentUp = true;
        }
        // Positive X angle means tilting down
        else if (headWentUp &&
            _faceHistory[i]!.headEulerAngleX! >
                (initialHeadAngle + _turnThreshold)) {
          headWentDown = true;
          break;
        }
      }
    }

    return headWentUp && headWentDown;
  }

  /// Detect if the user smiled
  bool _detectSmile() {
    if (_faceHistory.length < 5) return false;

    // First make sure we have valid smile probability information
    int validFrames = 0;
    for (var face in _faceHistory) {
      if (face != null && face.smilingProbability != null) {
        validFrames++;
      }
    }

    if (validFrames < 5) return false;

    // Look for significant smile
    int smilingFrames = 0;
    for (var face in _faceHistory) {
      if (face != null &&
          face.smilingProbability != null &&
          face.smilingProbability! > _smileThreshold) {
        smilingFrames++;
      }
    }

    // Consider it a smile if >50% of valid frames show a smile
    return smilingFrames > (validFrames / 2);
  }

  /// Convert camera image to input image for ML Kit
  InputImage? _convertCameraImageToInputImage(CameraImage image) {
    if (Platform.isIOS) {
      return _createIOSInputImage(image);
    } else {
      return _createAndroidInputImage(image);
    }
  }

  /// Create input image for iOS
  InputImage _createIOSInputImage(CameraImage image) {
    const inputImageFormat = InputImageFormat.bgra8888;

    final inputImageData = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: InputImageRotation.rotation0deg,
      format: inputImageFormat,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(
      bytes: image.planes[0].bytes,
      metadata: inputImageData,
    );
  }

  /// Create input image for Android
  InputImage _createAndroidInputImage(CameraImage image) {
    const inputImageFormat = InputImageFormat.nv21;

    final inputImageData = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: InputImageRotation.rotation0deg,
      format: inputImageFormat,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    // Convert YUV to bytes
    final bytes = _convertYUV420ToNV21(image);

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: inputImageData,
    );
  }

  /// Convert YUV_420 to NV21 format for Android
  Uint8List _convertYUV420ToNV21(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel!;

    final Uint8List nv21 = Uint8List(width * height * 3 ~/ 2);

    // Copy Y plane
    int ySize = width * height;
    for (int i = 0; i < ySize; i++) {
      nv21[i] = image.planes[0].bytes[i];
    }

    // Copy U and V planes
    int pos = ySize;
    for (int row = 0; row < height ~/ 2; row++) {
      for (int col = 0; col < width ~/ 2; col++) {
        final int uvIndex = col * uvPixelStride + row * uvRowStride;
        nv21[pos++] = image.planes[1].bytes[uvIndex]; // V
        nv21[pos++] = image.planes[2].bytes[uvIndex]; // U
      }
    }

    return nv21;
  }

  /// Cleanup resources
  void dispose() {
    stopDetection();
  }
}
