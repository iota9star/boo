import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/animation.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'bubble.dart';
import 'ease_out_elastic_curve.dart';
import 'math_utils.dart';
import 'physics_system.dart';

part 'creature_interaction.dart';

enum CreatureMode {
  out,
  returning,
  settled,
  noticing,
  scared,
  anticipating,
  leaving;

  bool get hiding =>
      this == CreatureMode.out ||
      this == CreatureMode.returning ||
      this == CreatureMode.noticing ||
      this == CreatureMode.scared ||
      this == CreatureMode.anticipating ||
      this == CreatureMode.leaving;
}

class _GrowthBehavior {
  _GrowthBehavior(this.startTime, this.targetScale);

  final int startTime;
  final double targetScale;

  double scaleAt(int timeMillis) {
    final int elapsed = timeMillis - startTime;
    if (elapsed < 0) {
      return 1;
    }
    if (elapsed < Creature._growTime) {
      return BooMath.map(
        elapsed.toDouble(),
        0.0,
        Creature._growTime.toDouble(),
        1.0,
        targetScale,
        const Cubic(0.4, 0.0, 0.2, 1),
      );
    }
    if (elapsed < Creature._growTime + Creature._popTime) {
      return BooMath.map(
        elapsed.toDouble(),
        Creature._growTime.toDouble(),
        (Creature._growTime + Creature._popTime).toDouble(),
        targetScale,
        1.0,
        const EaseOutElasticCurve(),
      );
    }
    return 1;
  }
}

class Creature {
  Creature({
    required this.bodyColor,
    required this.eyeColor,
    required this.system,
    required this.index,
    required this.creatureInteraction,
    required double initialBodySize,
  }) : originalBodySize = initialBodySize,
       bodySize = initialBodySize,
       eyeSize = initialBodySize * _eyeScale,
       bubble = Bubble(),
       paint = Paint()
         ..isAntiAlias = true
         ..filterQuality = FilterQuality.high,
       eyes = Eyes(),
       _startTime = DateTime.now().millisecondsSinceEpoch;

  static const double _eyeScale = 0.13;
  static const double _growChance = 0.0002;
  static const int _growTime = 4000;
  static const int _popTime = 400;

  final Color bodyColor;
  final Color eyeColor;
  final double originalBodySize;
  double bodySize;
  double eyeSize;

  final PhysicsSystem system;
  final int index;
  final CreatureInteraction creatureInteraction;

  final Bubble bubble;
  final Paint paint;
  final Eyes eyes;

  CreatureMode _mode = CreatureMode.out;
  _GrowthBehavior? _growth;

  final vm.Vector2 _position = vm.Vector2.zero();
  double _escapeAngle = 0;
  int _comeBackTime = 0;
  int? _scareTime;
  final int _startTime;

  double getBodySize() => bodySize;

  int _lastLocalTime = 0;
  int _lastGlobalTime = 0;

  void update(int timeMillis, {required bool withEffects}) {
    _lastGlobalTime = timeMillis;
    final int localTime = timeMillis - _startTime;
    _lastLocalTime = localTime;
    if (_mode == CreatureMode.returning) {
      if (localTime > _comeBackTime) {
        system.setSpringStrength(1);
        system.moveTo(index, 0, 0);
        system.setRepulsionStrength(1);
        _mode = CreatureMode.settled;
        creatureInteraction.creatureArrived(this, timeMillis);
      }
    } else if (_mode == CreatureMode.noticing) {
      final int scareTime = _scareTime ?? localTime;
      if (localTime - scareTime > _noticingTime) {
        _scareTime = localTime;
        _mode = CreatureMode.scared;
      }
    } else if (_mode == CreatureMode.scared) {
      system.setRepulsionStrength(0.3);
      _mode = CreatureMode.anticipating;
    } else if (_mode == CreatureMode.anticipating) {
      final int scareTime = _scareTime ?? localTime;
      if (localTime - scareTime > _scaredTime) {
        _mode = CreatureMode.leaving;
      }
    } else if (_mode == CreatureMode.leaving) {
      final double escapeX =
          PhysicsSystem.referenceWidth * 2 * math.cos(_escapeAngle);
      final double escapeY =
          PhysicsSystem.referenceWidth * 2 * math.sin(_escapeAngle);
      system.setRepulsionStrength(1);
      system.setSpringStrength(2);
      system.moveTo(index, escapeX, escapeY);
      _mode = CreatureMode.out;
    } else if (_mode == CreatureMode.settled &&
        _growth == null &&
        withEffects &&
        BooMath.flip(_growChance)) {
      _growth = _GrowthBehavior(localTime, BooMath.random(2.0, 3.0));
      creatureInteraction.notice(this, timeMillis);
    }

    if (_growth != null) {
      final double scale = _growth!.scaleAt(localTime);
      _resize(scale);
      if (scale == 1) {
        _growth = null;
      }
    }

    system.getOffset(index, _position);
  }

  void render(Canvas canvas, Size canvasSize) {
    canvas.save();
    canvas.translate(
      canvasSize.width / 2 + _position.x,
      canvasSize.height / 2 + _position.y,
    );
    _drawSelf(canvas);
    canvas.restore();
  }

  void _drawSelf(Canvas canvas) {
    paint.color = bodyColor;
    bubble.draw(canvas, paint, bodySize, _lastLocalTime);
    paint.color = eyeColor;
    eyes.draw(canvas, paint, bodySize, eyeSize, _lastGlobalTime, this);
  }

  void _resize(double scale) {
    bodySize = originalBodySize * scale;
    eyeSize = bodySize * _eyeScale;
    system.scaleSize(index, scale);
  }

  void reorient([double? angle]) {
    _escapeAngle = angle ?? BooMath.random(0, BooMath.twoPi);
    final double escapeX =
        PhysicsSystem.referenceWidth * 2 * math.cos(_escapeAngle);
    final double escapeY =
        PhysicsSystem.referenceWidth * 2 * math.sin(_escapeAngle);
    system.forceTo(index, escapeX, escapeY);
  }

  void comeBack(int delayMillis, int currentTime) {
    if (_mode.hiding) {
      final int localCurrent = currentTime - _startTime;
      _comeBackTime = localCurrent + delayMillis;
      _mode = CreatureMode.returning;
      eyes.comingBack(currentTime);
    }
  }

  void hide(int currentTime) {
    if (!_mode.hiding) {
      final vm.Vector2 lastForce = system.getLastForce(index);
      if (lastForce.x == 0 && lastForce.y == 0) {
        _escapeAngle = BooMath.random(0, BooMath.twoPi);
      } else {
        _escapeAngle = math.atan2(lastForce.y, lastForce.x);
      }
      _mode = CreatureMode.noticing;
      _scareTime = currentTime - _startTime;
      eyes.getScared(currentTime);
    }
  }

  double angleTo(Creature other) {
    return math.atan2(
      other._position.y - _position.y,
      other._position.x - _position.x,
    );
  }

  void lookIfAble(int timeMillis, Creature other) {
    eyes.lookIfAble(timeMillis, other, this);
  }

  bool get isVisible => !_mode.hiding;

  static const int _noticingTime = 100;
  static const int _scaredTime = 400;
}

class Eyes {
  Eyes();

  static const double _scaredScale = 1.65;

  _BehaviorState? _look;
  _BehaviorState? _blink;
  _BehaviorState? _squint;
  _BehaviorState? _notice;
  _BehaviorState? _freakOut;
  _BehaviorState? _stare;

  Creature? _lookTarget;

  void draw(
    Canvas canvas,
    Paint paint,
    double bodySize,
    double eyeSize,
    int timeMillis,
    Creature creature,
  ) {
    double cx = 0;
    double cy = 0;
    double eyeScale = 1;
    double blinkAmount = 0;
    double squintLevel = 0;

    if (_look != null) {
      if (_look!.isDone(timeMillis)) {
        _look = null;
      } else {
        final double progress = _look!.progress(timeMillis);
        final double theta = _lookTarget == null
            ? _look!.param
            : creature.angleTo(_lookTarget!);
        cx = (bodySize / 3) * math.cos(theta) * progress;
        cy = (bodySize / 2) * math.sin(theta) * progress;
      }
    } else if (_notice == null &&
        _freakOut == null &&
        _stare == null &&
        _BehaviorTypeEx.look.shouldStart()) {
      _startLooking(timeMillis, null, creature);
    }

    if (_notice != null) {
      if (_notice!.isDone(timeMillis)) {
        _notice = null;
        _freakOut = _BehaviorState(timeMillis, _BehaviorTypeEx.scared, 0);
      }
    } else if (_freakOut != null) {
      if (_freakOut!.isDone(timeMillis)) {
        _freakOut = null;
      } else {
        final double progress = _freakOut!.progress(timeMillis);
        eyeScale = BooMath.map(progress, 0.0, 1.0, 1.0, _scaredScale);
      }
    }

    if (_stare != null && _stare!.isDone(timeMillis)) {
      _stare = null;
    }

    if (_blink != null) {
      if (_blink!.isDone(timeMillis)) {
        _blink = null;
      } else {
        blinkAmount = _blink!.progress(timeMillis);
      }
    } else if (_notice == null &&
        _freakOut == null &&
        _BehaviorTypeEx.blink.shouldStart()) {
      _blink = _BehaviorState(timeMillis, _BehaviorTypeEx.blink, 0);
    }

    if (_squint != null) {
      if (_squint!.isDone(timeMillis)) {
        _squint = null;
      } else {
        squintLevel = _squint!.progress(timeMillis);
      }
    } else if (_notice == null &&
        _freakOut == null &&
        _blink == null &&
        _BehaviorTypeEx.squint.shouldStart()) {
      _squint = _BehaviorState(timeMillis, _BehaviorTypeEx.squint, 0);
    }

    if (squintLevel > 0) {
      blinkAmount = BooMath.map(
        squintLevel,
        0.0,
        1.0,
        blinkAmount,
        0.5 + blinkAmount / 2,
      );
    }

    final double verticalScale = (1 - BooMath.clamp(blinkAmount, 0.0, 1.0))
        .clamp(0.0, 1.0);
    for (int i = 0; i < 2; i++) {
      final double x = i == 0 ? cx - bodySize / 3 : cx + bodySize / 3;
      final double y = cy;
      canvas.save();
      canvas.translate(x, y);
      canvas.scale(eyeScale, eyeScale * verticalScale);
      canvas.drawCircle(Offset.zero, eyeSize, paint);
      canvas.restore();
    }
  }

  void _startLooking(int timeMillis, Creature? target, Creature creature) {
    double theta;
    if (creature.creatureInteraction.isNewArrival(timeMillis) ||
        BooMath.flip(0.7) ||
        target != null) {
      _lookTarget =
          target ?? creature.creatureInteraction.getLookTarget(creature);
      theta = creature.angleTo(_lookTarget!);
    } else {
      _lookTarget = null;
      theta = BooMath.random(0, BooMath.twoPi);
    }
    _look = _BehaviorState(timeMillis, _BehaviorTypeEx.look, theta);
  }

  void getScared(int timeMillis) {
    _look?.cancel(timeMillis);
    _stare?.cancel(timeMillis);
    _blink?.cancel(timeMillis);
    _squint?.cancel(timeMillis);
    _notice = _BehaviorState(timeMillis, _BehaviorTypeEx.notice, 0);
  }

  void comingBack(int timeMillis) {
    _look?.cancel(timeMillis);
    _notice?.cancel(timeMillis);
    _freakOut?.cancel(timeMillis);
    _stare = _BehaviorState(timeMillis, _BehaviorTypeEx.stare, 0);
  }

  void lookIfAble(int timeMillis, Creature other, Creature creature) {
    if (_notice == null && _freakOut == null && _look == null) {
      _stare?.cancel(timeMillis);
      _startLooking(timeMillis, other, creature);
    }
  }
}

enum _BehaviorTypeEx {
  blink(0.25 / 60, 125, 75, 75),
  look(1 / 3 / 60, 300, 500, 3000),
  squint(1 / 10 / 60, 300, 1000, 4000),
  notice(0, 60, 0, 0),
  scared(0, 100, 500, 600),
  stare(0, 20, 800, 2500);

  const _BehaviorTypeEx(
    this.chance,
    this.changeTime,
    this.minDuration,
    this.maxDuration,
  );

  final double chance;
  final int changeTime;
  final int minDuration;
  final int maxDuration;

  bool shouldStart() => chance > 0 && BooMath.flip(chance);
}

class _BehaviorState {
  _BehaviorState(this.startTime, this.type, this.param) {
    final int holdDuration = type.changeTime;
    final int duration = BooMath.random(
      type.minDuration.toDouble(),
      type.maxDuration.toDouble(),
    ).round();
    holdTime = startTime + holdDuration;
    stopTime = holdTime + duration;
    endTime = stopTime + holdDuration;
  }

  final int startTime;
  final _BehaviorTypeEx type;
  final double param;

  late int holdTime;
  late int stopTime;
  late int endTime;

  bool isDone(int timeMillis) => timeMillis >= endTime;

  double progress(int timeMillis) {
    if (timeMillis < holdTime) {
      return BooMath.map(
        timeMillis.toDouble(),
        startTime.toDouble(),
        holdTime.toDouble(),
        0.0,
        1.0,
        const Cubic(0.4, 0.0, 0.2, 1),
      );
    }
    if (timeMillis < stopTime) {
      return 1;
    }
    if (timeMillis < endTime) {
      return BooMath.map(
        timeMillis.toDouble(),
        stopTime.toDouble(),
        endTime.toDouble(),
        1.0,
        0.0,
        const Cubic(0.4, 0.0, 0.2, 1),
      );
    }
    return 0;
  }

  void cancel(int timeMillis) {
    int newEnd = endTime;
    if (timeMillis < holdTime) {
      newEnd = timeMillis + (timeMillis - startTime);
    } else if (timeMillis < stopTime) {
      newEnd = timeMillis + (endTime - stopTime);
    }
    final int delta = newEnd - endTime;
    holdTime += delta;
    stopTime += delta;
    endTime += delta;
  }
}
