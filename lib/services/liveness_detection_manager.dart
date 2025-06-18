import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

enum LivenessAction { blink, turnLeft, turnRight, nod, smile }

class LivenessDetectionManager {
  final FaceDetector _faceDetector;
  final CameraController cameraController;

  // Stream controller for processing frames
  StreamController<CameraImage>? _streamController;
  StreamSubscription<CameraImage>? _streamSubscription;
  
  // History of face detections for analysis
  final List<Face?> _faceHistory = [];
  final int _maxHistorySize = 20; // Store 20 frames for analysis

  // Action detection flags
  bool _isProcessingFrames = false;
  bool _actionDetected = false;
  LivenessAction? _currentAction;
  Completer<bool>? _detectionCompleter;

  // Confidence thresholds for action detection
  static const double _blinkThreshold = 0.2; // Eye open probability threshold
  static const double _turnThreshold = 20.0; // Head rotation threshold in degrees
  static const double _smileThreshold = 0.7; // Smile probability threshold
  static const double _nodThreshold = 10.0; // Head vertical movement threshold
  
  // Frame processing configuration
  static const int _processingInterval = 3; // Process every 3rd frame
  int _frameCount = 0;

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
    _frameCount = 0;

    // Create a new completer
    _detectionCompleter = Completer<bool>();

    // Start processing frames
    await _startFrameProcessing();
    
    // Set timeout
    Timer(Duration(seconds: durationSeconds), () {
      if (_detectionCompleter != null && !_detectionCompleter!.isCompleted) {
        _stopFrameProcessing();
        _detectionCompleter!.complete(_actionDetected);
      }
    });

    // Wait for result
    return await _detectionCompleter!.future;
  }

  /// Start processing frames from camera
  Future<void> _startFrameProcessing() async {
    try {
      _streamController = StreamController<CameraImage>();
      
      // Start camera image stream
      await cameraController.startImageStream((image) {
        if (_streamController != null && !_streamController!.isClosed) {
          _streamController!.add(image);
        }
      });
      
      // Process the stream
      _streamSubscription = _streamController!.stream.listen(_processFrame);
      
    } catch (e) {
      debugPrint('Error starting frame processing: $e');
      if (_detectionCompleter != null && !_detectionCompleter!.isCompleted) {
        _detectionCompleter!.complete(false);
      }
    }
  }

  /// Stop processing frames
  void _stopFrameProcessing() {
    try {
      _streamSubscription?.cancel();
      _streamController?.close();
      cameraController.stopImageStream();
    } catch (e) {
      debugPrint('Error stopping frame processing: $e');
    } finally {
      _isProcessingFrames = false;
    }
  }

  /// Process a single camera frame
  Future<void> _processFrame(CameraImage cameraImage) async {
    // Process only every Nth frame to reduce CPU usage
    if (_frameCount++ % _processingInterval != 0) {
      return;
    }
    
    if (_isProcessingFrames && !_actionDetected) {
      try {
        // Convert CameraImage to InputImage
        final inputImage = _convertCameraImageToInputImage(cameraImage);
        if (inputImage == null) return;
        
        // Process the image with the face detector
        final faces = await _faceDetector.processImage(inputImage);
        
        // We only care about the most prominent face
        final face = faces.isNotEmpty ? faces.first : null;
        
        // Add to history
        _faceHistory.add(face);
        if (_faceHistory.length > _maxHistorySize) {
          _faceHistory.removeAt(0); // Remove oldest entry
        }
        
        // Check if we have enough frames to analyze
        if (_faceHistory.length >= 10 && _currentAction != null) {
          // Check for the specific action
          _checkForAction(_currentAction!);
        }
        
      } catch (e) {
        debugPrint('Error processing frame: $e');
      }
    }
  }

  /// Convert CameraImage to InputImage
  InputImage? _convertCameraImageToInputImage(CameraImage cameraImage) {
    try {
      final camera = cameraController.description;
      final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation);
      if (rotation == null) return null;
      
      // Determine image format
      final format = InputImageFormatValue.fromRawValue(cameraImage.format.raw);
      if (format == null) return null;
      
      // For YUV_420_888 format (common on Android)
      if (format == InputImageFormat.yuv420) {
        return InputImage.fromBytes(
          bytes: _convertYUV420ToBytes(cameraImage),
          metadata: InputImageMetadata(
            size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
            rotation: rotation,
            format: format,
            bytesPerRow: cameraImage.planes[0].bytesPerRow,
          ),
        );
      } 
      // For other formats like BGRA8888 (common on iOS)
      else {
        return InputImage.fromBytes(
          bytes: cameraImage.planes[0].bytes,
          metadata: InputImageMetadata(
            size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
            rotation: rotation,
            format: format,
            bytesPerRow: cameraImage.planes[0].bytesPerRow,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error converting camera image: $e');
      return null;
    }
  }

  /// Convert YUV_420_888 format to bytes
  Uint8List _convertYUV420ToBytes(CameraImage image) {
    // This is a simplified conversion that works for face detection
    // For production, a more sophisticated conversion might be needed
    final bytesPerRow = image.planes[0].bytesPerRow;
    final height = image.height;
    final bytes = Uint8List(bytesPerRow * height);
    
    // Copy Y plane data (luminance)
    for (int i = 0; i < height; i++) {
      final byteOffset = i * bytesPerRow;
      final planeOffset = i * image.planes[0].bytesPerRow;
      for (int j = 0; j < bytesPerRow && j < image.planes[0].bytesPerRow; j++) {
        bytes[byteOffset + j] = image.planes[0].bytes[planeOffset + j];
      }
    }
    
    return bytes;
  }

  /// Check for the specific action in the face history
  void _checkForAction(LivenessAction action) {
    switch (action) {
      case LivenessAction.blink:
        _checkForBlinking();
        break;
      case LivenessAction.turnLeft:
        _checkForHeadTurn(true); // true = left
        break;
      case LivenessAction.turnRight:
        _checkForHeadTurn(false); // false = right
        break;
      case LivenessAction.nod:
        _checkForNodding();
        break;
      case LivenessAction.smile:
        _checkForSmiling();
        break;
    }
  }

  /// Check for blinking pattern: eyes open -> closed -> open
  void _checkForBlinking() {
    // Need at least 10 frames
    if (_faceHistory.length < 10) return;
    
    // Check recent frames to detect a blink
    // We look for a sequence where eyes are open, then closed, then open again
    bool foundOpenBeforeClosed = false;
    bool foundClosed = false;
    bool foundOpenAfterClosed = false;
    
    // Check most recent frames first (backward in time)
    for (int i = _faceHistory.length - 1; i >= 0; i--) {
      final face = _faceHistory[i];
      if (face == null) continue;
      
      // Skip faces without eye classification probability
      final leftEyeProb = face.leftEyeOpenProbability;
      final rightEyeProb = face.rightEyeOpenProbability;
      
      if (leftEyeProb == null || rightEyeProb == null || 
          !leftEyeProb.isFinite || !rightEyeProb.isFinite) {
        continue;
      }
      
      final eyesOpen = leftEyeProb > _blinkThreshold && 
                       rightEyeProb > _blinkThreshold;
      final eyesClosed = leftEyeProb < _blinkThreshold || 
                         rightEyeProb < _blinkThreshold;
      
      if (!foundOpenAfterClosed && eyesOpen) {
        foundOpenAfterClosed = true;
      } else if (foundOpenAfterClosed && !foundClosed && eyesClosed) {
        foundClosed = true;
      } else if (foundOpenAfterClosed && foundClosed && !foundOpenBeforeClosed && eyesOpen) {
        foundOpenBeforeClosed = true;
        break;
      }
    }
    
    if (foundOpenBeforeClosed && foundClosed && foundOpenAfterClosed) {
      _actionDetected = true;
      if (_detectionCompleter != null && !_detectionCompleter!.isCompleted) {
        _stopFrameProcessing();
        _detectionCompleter!.complete(true);
      }
    }
  }

  /// Check for head turn (left or right)
  void _checkForHeadTurn(bool isLeft) {
    // Need sufficient frames
    if (_faceHistory.length < 15) return;
    
    // Get the first face in history (oldest) and most recent face
    Face? startFace = null;
    Face? currentFace = null;
    
    // Find first valid face
    for (final face in _faceHistory) {
      if (face != null) {
        startFace = face;
        break;
      }
    }
    
    // Find most recent valid face
    for (int i = _faceHistory.length - 1; i >= 0; i--) {
      if (_faceHistory[i] != null) {
        currentFace = _faceHistory[i];
        break;
      }
    }
    
    if (startFace == null || currentFace == null) return;
    
    // Calculate head rotation (headEulerAngleY)
    // Positive is turn to the right, negative is turn to the left
    final startAngle = startFace.headEulerAngleY;
    final currentAngle = currentFace.headEulerAngleY;
    
    if (startAngle == null || currentAngle == null || 
        !startAngle.isFinite || !currentAngle.isFinite) return;
    
    // Calculate change in angle
    final angleChange = currentAngle - startAngle;
    
    // Check if angle change exceeds threshold in the correct direction
    if (isLeft && angleChange < -_turnThreshold) {
      _actionDetected = true;
      if (_detectionCompleter != null && !_detectionCompleter!.isCompleted) {
        _stopFrameProcessing();
        _detectionCompleter!.complete(true);
      }
    } else if (!isLeft && angleChange > _turnThreshold) {
      _actionDetected = true;
      if (_detectionCompleter != null && !_detectionCompleter!.isCompleted) {
        _stopFrameProcessing();
        _detectionCompleter!.complete(true);
      }
    }
  }

  /// Check for nodding (head moving up and down)
  void _checkForNodding() {
    // Need sufficient frames
    if (_faceHistory.length < 15) return;
    
    // Track head pitch (X angle) changes
    // Positive is looking down, negative is looking up
    final headPitches = <double>[];
    
    // Collect valid head pitch values
    for (final face in _faceHistory) {
      if (face != null) {
        final pitchAngle = face.headEulerAngleX;
        if (pitchAngle != null && pitchAngle.isFinite) {
          headPitches.add(pitchAngle);
        }
      }
    }
    
    if (headPitches.length < 10) return;
    
    // Calculate min and max to find the range of motion
    double minPitch = double.infinity;
    double maxPitch = double.negativeInfinity;
    
    for (final pitch in headPitches) {
      if (pitch < minPitch) minPitch = pitch;
      if (pitch > maxPitch) maxPitch = pitch;
    }
    
    // Calculate the range of motion
    final pitchRange = maxPitch - minPitch;
    
    // Detect nod if range exceeds threshold
    if (pitchRange > _nodThreshold) {
      // Check for at least one direction change (nod requires up-down-up or down-up-down)
      bool foundDirectionChange = false;
      
      for (int i = 2; i < headPitches.length; i++) {
        final prev2 = headPitches[i-2];
        final prev1 = headPitches[i-1];
        final current = headPitches[i];
        
        // Check for direction change: up to down or down to up
        if ((prev2 < prev1 && prev1 > current) || (prev2 > prev1 && prev1 < current)) {
          foundDirectionChange = true;
          break;
        }
      }
      
      if (foundDirectionChange) {
        _actionDetected = true;
        if (_detectionCompleter != null && !_detectionCompleter!.isCompleted) {
          _stopFrameProcessing();
          _detectionCompleter!.complete(true);
        }
      }
    }
  }

  /// Check for smiling
  void _checkForSmiling() {
    // Need sufficient frames
    if (_faceHistory.length < 10) return;
    
    // Count frames with smile
    int framesWithSmile = 0;
    int validFrames = 0;
    
    // Check recent frames
    for (int i = _faceHistory.length - 10; i < _faceHistory.length; i++) {
      if (i < 0) continue;
      
      final face = _faceHistory[i];
      if (face == null) continue;
      
      final smileProb = face.smilingProbability;
      if (smileProb == null || !smileProb.isFinite) continue;
      
      validFrames++;
      if (smileProb > _smileThreshold) {
        framesWithSmile++;
      }
    }
    
    // If we have enough valid frames and most of them have a smile, detect the action
    if (validFrames >= 5 && framesWithSmile >= validFrames * 0.7) {
      _actionDetected = true;
      if (_detectionCompleter != null && !_detectionCompleter!.isCompleted) {
        _stopFrameProcessing();
        _detectionCompleter!.complete(true);
      }
    }
  }

  /// Clean up resources
  void dispose() {
    _stopFrameProcessing();
    
    if (_detectionCompleter != null && !_detectionCompleter!.isCompleted) {
      _detectionCompleter!.complete(false);
      _detectionCompleter = null;
    }
  }
}
