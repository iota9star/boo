import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../core/boo_world.dart';
import 'boo_scene.dart';

class MotionBooPage extends StatefulWidget {
  const MotionBooPage({super.key});

  @override
  State<MotionBooPage> createState() => _MotionBooPageState();
}

class _MotionBooPageState extends State<MotionBooPage> {
  final BooWorld _world = BooWorld();
  StreamSubscription<AccelerometerEvent>? _accelerometerSub;
  StreamSubscription<UserAccelerometerEvent>? _userAccelerometerSub;

  bool _creaturesHidden = false;
  int _lastMotionTimestamp = 0;

  static const int _calmTimeoutMillis = 1800;

  @override
  void initState() {
    super.initState();
    _accelerometerSub = accelerometerEventStream().listen(_onAccelerometer);
    _userAccelerometerSub = userAccelerometerEventStream().listen(_onUserAccelerometer);
  }

  void _onAccelerometer(AccelerometerEvent event) {
    const double gravity = 9.81;
    final double normalizedX = (event.x / gravity).clamp(-1.0, 1.0);
    final double normalizedY = (event.y / gravity).clamp(-1.0, 1.0);
    _world.setTilt(Offset(-normalizedX, normalizedY));
  }

  void _onUserAccelerometer(UserAccelerometerEvent event) {
    final double magnitude = math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    final int now = DateTime.now().millisecondsSinceEpoch;
    if (magnitude > 2.8) {
      _lastMotionTimestamp = now;
      if (!_creaturesHidden) {
        _creaturesHidden = true;
        _world.setFaceVisible(true, now);
      }
    } else if (_creaturesHidden && now - _lastMotionTimestamp > _calmTimeoutMillis) {
      _creaturesHidden = false;
      _world.setFaceVisible(false, now);
    }
  }

  @override
  void dispose() {
    _accelerometerSub?.cancel();
    _userAccelerometerSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        BooScene(world: _world),
        Positioned(
          left: 16,
          right: 16,
          top: MediaQuery.of(context).padding.top + 16,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                '轻轻晃动手机让 Boo 躲起来，保持平稳它们会回来看你。',
                style: TextStyle(color: Colors.white, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
