import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/boo_world.dart';
import 'boo_scene.dart';

class CameraBooExperience extends StatefulWidget {
  const CameraBooExperience({super.key, required this.active});

  final bool active;

  @override
  State<CameraBooExperience> createState() => _CameraBooExperienceState();
}

class _CameraBooExperienceState extends State<CameraBooExperience>
    with WidgetsBindingObserver {
  final BooWorld _world = BooWorld();
  CameraController? _controller;
  CameraDescription? _cameraDescription;
  late final FaceDetector _faceDetector;
  bool _isProcessingFrame = false;
  bool _initialized = false;
  String? _errorMessage;
  PermissionStatus _cameraPermission = PermissionStatus.denied;
  bool _isRequestingPermission = false;
  bool _permissionResolved = false;
  bool _faceDetected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableContours: false,
        enableLandmarks: false,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
    if (widget.active) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _ensurePermissions());
    }
  }

  @override
  void didUpdateWidget(covariant CameraBooExperience oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) {
      _ensurePermissions();
    } else if (oldWidget.active && !widget.active) {
      unawaited(_teardownCamera());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!widget.active) {
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _ensurePermissions();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_teardownCamera());
    }
  }

  bool _isPermissionEffective(PermissionStatus status) {
    return status.isGranted || status.isLimited;
  }

  Future<void> _ensurePermissions() async {
    if (!mounted || !widget.active || _isRequestingPermission) {
      return;
    }
    setState(() {
      _isRequestingPermission = true;
    });
    try {
      PermissionStatus status = await Permission.camera.status;
      if (!_isPermissionEffective(status)) {
        status = await Permission.camera.request();
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _cameraPermission = status;
        _permissionResolved = true;
        if (!_isPermissionEffective(status)) {
          _errorMessage = null;
        }
      });

      if (_isPermissionEffective(status) && widget.active) {
        await _initializeCamera();
      } else {
        await _teardownCamera();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRequestingPermission = false;
        });
      }
    }
  }

  Future<void> _initializeCamera() async {
    if (!widget.active || _initialized || _controller != null) {
      return;
    }
    try {
      final List<CameraDescription> cameras = await availableCameras();
      final CameraDescription frontCamera = cameras.firstWhere(
        (CameraDescription description) =>
            description.lensDirection == CameraLensDirection.front,
        orElse: () => throw StateError('No front-facing camera found'),
      );
      _cameraDescription = frontCamera;
      final CameraController controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (!widget.active) {
        await controller.dispose();
        return;
      }
      await controller.startImageStream(_processCameraImage);
      if (!mounted || !widget.active) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initialized = true;
        _errorMessage = null;
      });
    } catch (e) {
      await _teardownCamera();
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _teardownCamera() async {
    final CameraController? controller = _controller;
    _controller = null;
    if (controller != null) {
      try {
        await controller.stopImageStream();
      } catch (_) {
        // Ignore stop errors when the stream is already stopped.
      }
      await controller.dispose();
    }
    if (mounted && _initialized) {
      setState(() {
        _initialized = false;
      });
    } else {
      _initialized = false;
    }
    _cameraDescription = null;
    _applyFaceDetectionResult(false, DateTime.now().millisecondsSinceEpoch);
  }

  void _applyFaceDetectionResult(bool hasFace, int timestamp) {
    _world.setFaceVisible(hasFace, timestamp);
    if (!mounted) {
      _faceDetected = hasFace;
      return;
    }
    if (_faceDetected != hasFace) {
      setState(() {
        _faceDetected = hasFace;
      });
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessingFrame || !mounted || !widget.active) {
      return;
    }
    _isProcessingFrame = true;
    final int now = DateTime.now().millisecondsSinceEpoch;
    try {
      final InputImage inputImage = _inputImageFromCameraImage(image);
      final List<Face> faces = await _faceDetector.processImage(inputImage);
      _applyFaceDetectionResult(faces.isNotEmpty, now);
    } catch (e) {
      debugPrint('Face detection failed: $e');
      _applyFaceDetectionResult(false, now);
    } finally {
      _isProcessingFrame = false;
    }
  }

  InputImage _inputImageFromCameraImage(CameraImage image) {
    final InputImageRotation rotation =
        InputImageRotationValue.fromRawValue(
          _cameraDescription?.sensorOrientation ?? 0,
        ) ??
        InputImageRotation.rotation0deg;

    final ImageFormatGroup formatGroup = image.format.group;
    if (formatGroup == ImageFormatGroup.bgra8888 ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      final Plane plane = image.planes.first;
      final InputImageMetadata metadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.bgra8888,
        bytesPerRow: plane.bytesPerRow,
      );
      return InputImage.fromBytes(bytes: plane.bytes, metadata: metadata);
    }

    final Uint8List bytes = _nv21FromCameraImage(image);
    final InputImageMetadata metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: InputImageFormat.nv21,
      bytesPerRow: image.width,
    );
    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  Uint8List _nv21FromCameraImage(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final int ySize = width * height;
    final int uvSize = ySize ~/ 2;

    final Uint8List nv21 = Uint8List(ySize + uvSize);
    final Plane yPlane = image.planes[0];
    final Uint8List yBytes = yPlane.bytes;

    int offset = 0;
    for (int row = 0; row < height; row++) {
      final int rowStart = row * yPlane.bytesPerRow;
      final int remaining = math.max(0, yBytes.length - rowStart);
      final int length = math.min(width, remaining);
      nv21.setRange(offset, offset + length, yBytes, rowStart);
      offset += length;
    }

    if (image.planes.length < 3) {
      return nv21;
    }

    final Plane uPlane = image.planes[1];
    final Plane vPlane = image.planes[2];
    final Uint8List uBytes = uPlane.bytes;
    final Uint8List vBytes = vPlane.bytes;
    final int uRowStride = uPlane.bytesPerRow;
    final int vRowStride = vPlane.bytesPerRow;
    final int uPixelStride = uPlane.bytesPerPixel ?? 1;
    final int vPixelStride = vPlane.bytesPerPixel ?? 1;

    final int halfWidth = width ~/ 2;
    final int halfHeight = height ~/ 2;

    for (int row = 0; row < halfHeight; row++) {
      final int uRowStart = row * uRowStride;
      final int vRowStart = row * vRowStride;
      for (int col = 0; col < halfWidth; col++) {
        final int uIndex = uRowStart + col * uPixelStride;
        final int vIndex = vRowStart + col * vPixelStride;
        if (uIndex >= uBytes.length || vIndex >= vBytes.length) {
          break;
        }
        if (offset + 1 >= nv21.length) {
          return nv21;
        }
        nv21[offset++] = vBytes[vIndex];
        nv21[offset++] = uBytes[uIndex];
      }
    }

    return nv21;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_teardownCamera());
    unawaited(_faceDetector.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final bool hasPermission = _isPermissionEffective(_cameraPermission);
    final bool cameraReady = hasPermission &&
        _controller != null &&
        _controller!.value.isInitialized &&
        _initialized &&
        _errorMessage == null;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Positioned.fill(
          child: IgnorePointer(child: BooScene(world: _world)),
        ),
        if (!cameraReady && _errorMessage == null && hasPermission)
          const Center(child: CircularProgressIndicator()),
        if (_errorMessage != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white70, fontSize: 15),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: mediaQuery.padding.top + 24),
            child: _FaceStatusBadge(
              detected: _faceDetected,
              active: cameraReady,
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              0,
              24,
              mediaQuery.padding.bottom + 32,
            ),
            child: _InstructionCard(
              faceDetected: _faceDetected,
              cameraReady: cameraReady,
            ),
          ),
        ),
        if (!hasPermission)
          Positioned.fill(
            child: Container(
              alignment: Alignment.center,
              color: Colors.black.withOpacity(0.55),
              child: _buildPermissionPrompt(context),
            ),
          ),
      ],
    );
  }

  Widget _buildPermissionPrompt(BuildContext context) {
    if (!_permissionResolved && _isRequestingPermission) {
      return const CircularProgressIndicator();
    }
    final bool permanentlyDenied =
        _cameraPermission.isPermanentlyDenied || _cameraPermission.isRestricted;
    final String message = permanentlyDenied
        ? 'Enable camera access in Settings so Boo can notice you.'
        : 'Camera access is required to let Boo react to you. Tap Continue to grant permission.';
    final String buttonLabel =
        permanentlyDenied ? 'Open Settings' : 'Allow Camera Access';

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.22)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.videocam, color: Colors.white, size: 38),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.35,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.28),
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                    onPressed: _isRequestingPermission
                        ? null
                        : permanentlyDenied
                            ? () => openAppSettings()
                            : _ensurePermissions,
                    child: _isRequestingPermission
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(buttonLabel),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InstructionCard extends StatelessWidget {
  const _InstructionCard({
    required this.faceDetected,
    required this.cameraReady,
  });

  final bool faceDetected;
  final bool cameraReady;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool ready = cameraReady;
    final String headline;
    final String message;

    if (!ready) {
      headline = 'Preparing camera...';
      message = 'Hold tight while the lens warms up for Boo.';
    } else if (faceDetected) {
      headline = 'Great! Boo can see you.';
      message = 'Hold still for a moment so Boo can respond.';
    } else {
      headline = 'Bring your face into view';
      message =
          'Step closer, keep your face centered, and look toward the screen.';
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.22), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  headline,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white.withOpacity(0.95),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.78),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FaceStatusBadge extends StatelessWidget {
  const _FaceStatusBadge({
    required this.detected,
    required this.active,
  });

  final bool detected;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final String label;
    if (!active) {
      label = 'Camera warming up';
    } else {
      label = detected ? 'Face detected' : 'No face detected';
    }
    final Color dotColor;
    if (!active) {
      dotColor = Colors.white.withOpacity(0.65);
    } else {
      dotColor = detected
          ? const Color(0xFF4FFFBE)
          : Colors.white.withOpacity(0.65);
    }
    final Color panelColor = detected && active
        ? Colors.white.withOpacity(0.24)
        : Colors.white.withOpacity(0.16);

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: panelColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.28), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: dotColor.withOpacity(0.5),
                        blurRadius: 10,
                        spreadRadius: 0.5,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.92),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
