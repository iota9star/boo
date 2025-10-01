import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../core/boo_world.dart';
import 'boo_scene.dart';

class MotionBooExperience extends StatefulWidget {
  const MotionBooExperience({super.key, required this.active});

  final bool active;

  @override
  State<MotionBooExperience> createState() => _MotionBooExperienceState();
}

class _MotionBooExperienceState extends State<MotionBooExperience> {
  final BooWorld _world = BooWorld();
  StreamSubscription<AccelerometerEvent>? _accelerometerSub;
  StreamSubscription<UserAccelerometerEvent>? _userAccelerometerSub;

  bool _creaturesHidden = false;
  int _lastMotionTimestamp = 0;
  bool _receivedUserAccelerometer = false;

  double? _gravityX;
  double? _gravityY;
  double? _gravityZ;

  static const int _calmTimeoutMillis = 1800;
  static const double _userMotionThreshold = 2.8;
  static const double _fallbackMotionThreshold = 1.4;
  static const double _gravityFilterAlpha = 0.12;

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      _attachSensors();
    }
  }

  @override
  void didUpdateWidget(covariant MotionBooExperience oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) {
      _attachSensors();
    } else if (oldWidget.active && !widget.active) {
      _detachSensors();
      _resetWorld();
    }
  }

  void _attachSensors() {
    _accelerometerSub ??=
        accelerometerEventStream().listen(_onAccelerometer);
    _userAccelerometerSub ??=
        userAccelerometerEventStream().listen(_onUserAccelerometer);
  }

  void _detachSensors() {
    _accelerometerSub?.cancel();
    _accelerometerSub = null;
    _userAccelerometerSub?.cancel();
    _userAccelerometerSub = null;
  }

  void _resetWorld() {
    _creaturesHidden = false;
    _lastMotionTimestamp = 0;
    _receivedUserAccelerometer = false;
    _gravityX = null;
    _gravityY = null;
    _gravityZ = null;
    final int now = DateTime.now().millisecondsSinceEpoch;
    _world
      ..setFaceVisible(false, now)
      ..setTilt(Offset.zero);
  }

  void _onAccelerometer(AccelerometerEvent event) {
    const double gravity = 9.81;
    final double normalizedX = (event.x / gravity).clamp(-1.0, 1.0);
    final double normalizedY = (event.y / gravity).clamp(-1.0, 1.0);
    _world.setTilt(Offset(-normalizedX, normalizedY));

    if (_receivedUserAccelerometer && !kIsWeb) {
      return;
    }

    if (_gravityX == null) {
      _gravityX = event.x;
      _gravityY = event.y;
      _gravityZ = event.z;
    } else {
      _gravityX =
          _gravityFilterAlpha * event.x + (1 - _gravityFilterAlpha) * _gravityX!;
      _gravityY =
          _gravityFilterAlpha * event.y + (1 - _gravityFilterAlpha) * _gravityY!;
      _gravityZ =
          _gravityFilterAlpha * event.z + (1 - _gravityFilterAlpha) * _gravityZ!;
    }

    final double linearX = event.x - (_gravityX ?? event.x);
    final double linearY = event.y - (_gravityY ?? event.y);
    final double linearZ = event.z - (_gravityZ ?? event.z);
    final double magnitude = math.sqrt(
      linearX * linearX + linearY * linearY + linearZ * linearZ,
    );
    _handleMotionMagnitude(
      magnitude,
      DateTime.now().millisecondsSinceEpoch,
      _fallbackMotionThreshold,
    );
  }

  void _onUserAccelerometer(UserAccelerometerEvent event) {
    _receivedUserAccelerometer = true;
    final double magnitude = math.sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    _handleMotionMagnitude(
      magnitude,
      DateTime.now().millisecondsSinceEpoch,
      _userMotionThreshold,
    );
  }

  void _handleMotionMagnitude(double magnitude, int now, double threshold) {
    if (magnitude > threshold) {
      _lastMotionTimestamp = now;
      if (!_creaturesHidden) {
        _creaturesHidden = true;
        _world.setFaceVisible(true, now);
      }
    } else if (_creaturesHidden &&
        now - _lastMotionTimestamp > _calmTimeoutMillis) {
      _creaturesHidden = false;
      _world.setFaceVisible(false, now);
    }
  }

  @override
  void dispose() {
    _detachSensors();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Positioned.fill(child: BooScene(world: _world)),
      ],
    );
  }
}
