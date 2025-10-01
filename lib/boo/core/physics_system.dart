import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart' as vm;

class PhysicsSystem {
  PhysicsSystem(double width, List<double> sizes)
      : _scale = width / referenceWidth,
        _bodies = List<_Body>.generate(
          sizes.length,
          (index) => _Body(sizes[index]),
        ) {
    for (final _Body body in _bodies) {
      final double angle = _random.nextDouble() * math.pi * 2;
      body.size /= _scale;
      body.originalSize = body.size;
      body.pos
        ..x = math.cos(angle) * 2 * referenceWidth
        ..y = math.sin(angle) * 2 * referenceWidth;
      body.springPos.setZero();
      body.springOffset.setZero();
      body.mass = mass / 100.0;
    }
  }

  static const double referenceWidth = 360;
  static const double mass = 1.0;
  static const double _springStrengthBase = 250.0;
  static const double _damping = 0.75;
  static const double _repulsionStrengthBase = 5000.0;
  static const double _step = 1 / 60.0;

  static final math.Random _random = math.Random();

  final List<_Body> _bodies;
  final double _scale;

  double _springStrength = _springStrengthBase;
  double _repulsionStrength = _repulsionStrengthBase;
  double _repulsionFactor = 1.0;

  int? _lastUpdateMillis;
  double _stepRemainder = 0;

  int get count => _bodies.length;

  void setSpringOffset(int index, double x, double y) {
    final _Body body = _bodies[index];
    body.springOffset
      ..x = x / _scale
      ..y = y / _scale;
  }

  void setSpringStrength(double factor) {
    _springStrength = _springStrengthBase * factor;
  }

  void setRepulsionStrength(double factor) {
    _repulsionStrength = _repulsionStrengthBase * factor;
  }

  void setRepulsionFactor(double factor) {
    _repulsionFactor = factor;
  }

  void forceTo(int index, double x, double y) {
    final _Body body = _bodies[index];
    body.springPos
      ..x = x
      ..y = y;
    body.pos
      ..x = x
      ..y = y;
    body.vel.setZero();
  }

  void moveTo(int index, double x, double y) {
    final _Body body = _bodies[index];
    body.springPos
      ..x = x
      ..y = y;
  }

  void scaleSize(int index, double factor) {
    final _Body body = _bodies[index];
    body.size = body.originalSize * factor;
  }

  void getOffset(int index, vm.Vector2 out) {
    final _Body body = _bodies[index];
    out
      ..x = _scale * body.pos.x
      ..y = _scale * body.pos.y;
  }

  vm.Vector2 getLastForce(int index) {
    return _bodies[index].lastForce;
  }

  void update() {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final int? last = _lastUpdateMillis;
    _lastUpdateMillis = now;
    if (last == null) {
      return;
    }
    double deltaSeconds = (now - last) / 1000.0 + _stepRemainder;
    int steps = (deltaSeconds / _step).floor();
    if (steps <= 0) {
      _stepRemainder = deltaSeconds;
      return;
    }
    if (steps > 5) {
      steps = 5;
    }
    _stepRemainder = deltaSeconds - steps * _step;
    for (int i = 0; i < steps; i++) {
      _integrateStep(_step);
    }
  }

  void _integrateStep(double dt) {
    for (int i = 0; i < _bodies.length; i++) {
      final _Body body = _bodies[i];
      for (int j = 0; j < _bodies.length; j++) {
        if (i == j) {
          continue;
        }
        final _Body other = _bodies[j];
        final double dx = body.pos.x - other.pos.x;
        final double dy = body.pos.y - other.pos.y;
        final double distance = math.max(
          1.0,
          math.sqrt(dx * dx + dy * dy) - body.size - other.size,
        );
        final double repulsion = _repulsionStrength * _repulsionFactor / distance;
        final double distanceSum = math.max(1.0, dx.abs() + dy.abs());
        body.force
          ..x += (dx * repulsion) / distanceSum
          ..y += (dy * repulsion) / distanceSum;
      }
      final double targetX = body.springPos.x + body.springOffset.x;
      final double targetY = body.springPos.y + body.springOffset.y;
      final double springForceX = -_springStrength * body.mass * (body.pos.x - targetX);
      final double springForceY = -_springStrength * body.mass * (body.pos.y - targetY);
      final double dampingForceX = -_damping * body.vel.x;
      final double dampingForceY = -_damping * body.vel.y;
      body.vel
        ..x += dt * (springForceX + dampingForceX + body.force.x) / body.mass
        ..y += dt * (springForceY + dampingForceY + body.force.y) / body.mass;
      body.pos
        ..x += dt * body.vel.x
        ..y += dt * body.vel.y;
      body.lastForce
        ..x = body.force.x
        ..y = body.force.y;
      body.force.setZero();
    }
  }
}

class _Body {
  _Body(double initialSize)
      : pos = vm.Vector2.zero(),
        vel = vm.Vector2.zero(),
        force = vm.Vector2.zero(),
        springPos = vm.Vector2.zero(),
        springOffset = vm.Vector2.zero(),
        lastForce = vm.Vector2.zero(),
        size = initialSize,
        originalSize = initialSize;

  final vm.Vector2 pos;
  final vm.Vector2 vel;
  final vm.Vector2 force;
  final vm.Vector2 springPos;
  final vm.Vector2 springOffset;
  final vm.Vector2 lastForce;
  double mass = PhysicsSystem.mass;
  double size;
  double originalSize;
}
