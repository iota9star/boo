import 'dart:async';
import 'dart:math' as math;

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

  static const int _calmTimeoutMillis = 1800;

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
  }

  void _onUserAccelerometer(UserAccelerometerEvent event) {
    final double magnitude = math.sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (magnitude > 2.8) {
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
