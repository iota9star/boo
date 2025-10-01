import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/boo_world.dart';
import 'boo_scene.dart';

class CameraBooPage extends StatefulWidget {
  const CameraBooPage({super.key});

  @override
  State<CameraBooPage> createState() => _CameraBooPageState();
}

class _CameraBooPageState extends State<CameraBooPage> with WidgetsBindingObserver {
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
  bool _simulateNoFace = false;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensurePermissions();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _ensurePermissions();
    }
  }

  bool _isPermissionEffective(PermissionStatus status) {
    return status.isGranted || status.isLimited;
  }

  Future<void> _ensurePermissions() async {
    if (!mounted || _isRequestingPermission) {
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
      if (_isPermissionEffective(status)) {
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
    if (_initialized || _controller != null) {
      return;
    }
    try {
      final List<CameraDescription> cameras = await availableCameras();
      final CameraDescription frontCamera = cameras.firstWhere(
        (CameraDescription description) => description.lensDirection == CameraLensDirection.front,
        orElse: () => throw StateError('未找到前置摄像头'),
      );
      _cameraDescription = frontCamera;
      final controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      await controller.startImageStream(_processCameraImage);
      if (!mounted) {
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
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _teardownCamera() async {
    final CameraController? controller = _controller;
    _controller = null;
    if (controller != null) {
      try {
        await controller.stopImageStream();
      } catch (_) {
        // Ignore stop errors when camera is already stopped.
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
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessingFrame || !mounted) {
      return;
    }
    _isProcessingFrame = true;
    final int now = DateTime.now().millisecondsSinceEpoch;
    try {
      if (_simulateNoFace) {
        _world.setFaceVisible(false, now);
        return;
      }
      final InputImage inputImage = _inputImageFromCameraImage(image);
      final List<Face> faces = await _faceDetector.processImage(inputImage);
      _world.setFaceVisible(faces.isNotEmpty, now);
    } catch (e) {
      debugPrint('Face detection failed: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  InputImage _inputImageFromCameraImage(CameraImage image) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final Uint8List bytes = allBytes.done().buffer.asUint8List();
    final InputImageRotation rotation = InputImageRotationValue.fromRawValue(_cameraDescription?.sensorOrientation ?? 0) ?? InputImageRotation.rotation0deg;
    final InputImageFormat format = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21;
    final InputImageMetadata metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes.first.bytesPerRow,
    );
    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final Future<void> teardown = _teardownCamera();
    unawaited(teardown);
    unawaited(_faceDetector.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasPermission = _isPermissionEffective(_cameraPermission);
    Widget cameraLayer;
    if (!hasPermission) {
      cameraLayer = const SizedBox.shrink();
    } else if (_errorMessage != null) {
      cameraLayer = Center(
        child: Text(
          _errorMessage!,
          style: const TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
      );
    } else if (!_initialized || _controller == null || !_controller!.value.isInitialized) {
      cameraLayer = const Center(child: CircularProgressIndicator());
    } else {
      cameraLayer = Transform.scale(
        scaleX: -1,
        child: CameraPreview(_controller!),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Container(color: Colors.black),
        cameraLayer,
        IgnorePointer(child: BooScene(world: _world)),
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          right: 16,
          child: _SimulationToggle(
            enabled: hasPermission,
            active: _simulateNoFace,
            onChanged: (bool value) {
              setState(() {
                _simulateNoFace = value;
              });
              if (value) {
                _world.setFaceVisible(false, DateTime.now().millisecondsSinceEpoch);
              }
            },
          ),
        ),
        if (!hasPermission) _buildPermissionPrompt(context),
        Positioned(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).padding.bottom + 24,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                '让面部进入取景框，Boo 会害羞地躲起来；移开之后，它们会陆续回来。右上角可模拟无面部场景。',
                style: TextStyle(color: Colors.white, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionPrompt(BuildContext context) {
    if (!_permissionResolved && _isRequestingPermission) {
      return const Center(child: CircularProgressIndicator());
    }
    final bool permanentlyDenied =
        _cameraPermission.isPermanentlyDenied || _cameraPermission.isRestricted;
    final String message = permanentlyDenied
        ? '需要到系统设置中启用相机权限，才能让 Boo 识别你的脸。'
        : '需要相机权限才能使用 Camera Boo，点击下方按钮授权。';
    final String buttonLabel = permanentlyDenied ? '前往设置' : '允许相机权限';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Card(
          color: Colors.black.withOpacity(0.65),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.videocam_off, color: Colors.white, size: 36),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
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

class _SimulationToggle extends StatelessWidget {
  const _SimulationToggle({
    required this.enabled,
    required this.active,
    required this.onChanged,
  });

  final bool enabled;
  final bool active;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: enabled ? 1 : 0.35,
      duration: const Duration(milliseconds: 150),
      child: FilledButton.tonalIcon(
        onPressed: enabled
            ? () {
                onChanged(!active);
              }
            : null,
        icon: Icon(active ? Icons.face_retouching_off : Icons.face,
            color: Colors.white),
        label: Text(
          active ? '无面部模拟中' : '模拟无面部',
          style: const TextStyle(color: Colors.white),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0x66000000),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          minimumSize: const Size(0, 0),
        ),
      ),
    );
  }
}
