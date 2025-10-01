import 'package:flutter/material.dart';

import 'creature.dart';
import 'math_utils.dart';
import 'physics_system.dart';

class ColorPair {
  const ColorPair(this.start, this.end);

  final Color start;
  final Color end;
}

class _BackgroundController {
  _BackgroundController(ColorPair initial)
    : _currentStart = initial.start,
      _currentEnd = initial.end,
      _fromStart = initial.start,
      _fromEnd = initial.end;

  static const double _transitionSeconds = 1.5;

  Color _currentStart;
  Color _currentEnd;
  Color _fromStart;
  Color _fromEnd;
  Color? _targetStart;
  Color? _targetEnd;
  double _progress = 1;

  void update(double deltaSeconds) {
    if (_targetStart == null) {
      return;
    }
    _progress += deltaSeconds / _transitionSeconds;
    if (_progress >= 1) {
      _progress = 1;
      _currentStart = _targetStart!;
      _currentEnd = _targetEnd!;
      _targetStart = null;
      _targetEnd = null;
      _fromStart = _currentStart;
      _fromEnd = _currentEnd;
    }
  }

  void changeTo(ColorPair pair) {
    _fromStart = currentStart;
    _fromEnd = currentEnd;
    _targetStart = pair.start;
    _targetEnd = pair.end;
    _progress = 0;
  }

  Color get currentStart =>
      Color.lerp(_fromStart, _targetStart ?? _currentStart, _progress)!;
  Color get currentEnd =>
      Color.lerp(_fromEnd, _targetEnd ?? _currentEnd, _progress)!;
}

class BooWorld {
  BooWorld({int creatureCount = 10}) : _creatureCount = creatureCount;

  static const List<ColorPair> _backgroundPalette = <ColorPair>[
    ColorPair(Color(0xFFC566B9), Color(0xFFF5148A)),
    ColorPair(Color(0xFFF0FF44), Color(0xFFFFEB3C)),
    ColorPair(Color(0xFF00C0FF), Color(0xFF007DFF)),
    ColorPair(Color(0xFF19D2C7), Color(0xFF19D29C)),
    ColorPair(Color(0xFFFFC62D), Color(0xFFFF9B2D)),
    ColorPair(Color(0xFFD658FF), Color(0xFF9D58FF)),
    ColorPair(Color(0xFFFF9561), Color(0xFFFF5442)),
    ColorPair(Color(0xFF00D5C3), Color(0xFF00BCD5)),
  ];

  static const int _hideBackoffMillis = 1500;
  static const int _backgroundChangeDelayMillis = 500;

  final int _creatureCount;
  final List<Creature> _creatures = <Creature>[];

  Size? _size;
  PhysicsSystem? _system;
  CreatureInteraction? _interaction;
  late _BackgroundController _background;
  Offset _tilt = Offset.zero;

  bool _initialized = false;
  bool _faceVisible = false;
  int _lastHideTime = 0;
  int? _pendingBackgroundChangeAt;
  int? _previousUpdateTime;
  int _currentBackgroundIndex = 0;

  void ensureInitialized(Size size) {
    if (_initialized && _size == size) {
      return;
    }
    _size = size;
    _creatures.clear();
    final List<double> sizes = List<double>.generate(
      _creatureCount,
      (_) => BooMath.random(size.width / 20, size.width / 8),
    );
    _system = PhysicsSystem(size.width, sizes);
    _interaction = CreatureInteraction(_creatures);
    for (int i = 0; i < _creatureCount; i++) {
      final creature = Creature(
        bodyColor: Colors.black,
        eyeColor: Colors.white,
        initialBodySize: sizes[i],
        system: _system!,
        index: i,
        creatureInteraction: _interaction!,
      )..reorient();
      _creatures.add(creature);
    }
    _background = _BackgroundController(
      _backgroundPalette[_currentBackgroundIndex],
    );
    _faceVisible = false;
    _initialized = true;
    _scheduleReturn(DateTime.now().millisecondsSinceEpoch);
  }

  void update(int timeMillis, Size size) {
    ensureInitialized(size);
    if (_system == null) {
      return;
    }
    _system!.update();
    final int? previous = _previousUpdateTime;
    _previousUpdateTime = timeMillis;
    final double deltaSeconds = previous == null
        ? 0
        : (timeMillis - previous) / 1000.0;
    _background.update(deltaSeconds);

    if (_pendingBackgroundChangeAt != null &&
        timeMillis >= _pendingBackgroundChangeAt!) {
      _advanceBackground();
      _pendingBackgroundChangeAt = null;
    }

    final bool allowBehaviors = !_faceVisible;
    for (final Creature creature in _creatures) {
      creature.update(timeMillis, withEffects: allowBehaviors);
    }
  }

  void paint(Canvas canvas, Size size, int timeMillis) {
    ensureInitialized(size);
    _drawBackground(canvas, size);
    for (final Creature creature in _creatures) {
      creature.render(canvas, size);
    }
  }

  void _drawBackground(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Alignment center = Alignment(_tilt.dx * 0.6, _tilt.dy * 0.6);
    final Paint paint = Paint()
      ..shader = RadialGradient(
        center: center,
        radius: 1.0,
        colors: <Color>[_background.currentStart, _background.currentEnd],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  void setFaceVisible(bool faceVisible, int timeMillis) {
    if (!_initialized || faceVisible == _faceVisible) {
      return;
    }
    _faceVisible = faceVisible;
    if (faceVisible) {
      _lastHideTime = timeMillis;
      for (final Creature creature in _creatures) {
        creature.hide(timeMillis);
      }
      _pendingBackgroundChangeAt = timeMillis + _backgroundChangeDelayMillis;
    } else {
      if (timeMillis - _lastHideTime < _hideBackoffMillis) {
        return;
      }
      _scheduleReturn(timeMillis);
    }
  }

  void _scheduleReturn(int timeMillis) {
    _creatures.shuffle();
    int cumulativeDelay = 0;
    for (int i = 0; i < _creatures.length; i++) {
      if (i == 0) {
        cumulativeDelay = 0;
      } else {
        if (BooMath.flip(0.333)) {
          cumulativeDelay += BooMath.randomInt(250, 1000);
        } else {
          cumulativeDelay += BooMath.randomInt(3000, 8000);
        }
      }
      final Creature creature = _creatures[i]..reorient();
      creature.comeBack(cumulativeDelay, timeMillis);
    }
  }

  void _advanceBackground() {
    _currentBackgroundIndex =
        (_currentBackgroundIndex + 1) % _backgroundPalette.length;
    _background.changeTo(_backgroundPalette[_currentBackgroundIndex]);
  }

  List<Creature> get creatures => _creatures;
  ColorPair get backgroundColors =>
      ColorPair(_background.currentStart, _background.currentEnd);

  void setTilt(Offset tilt) {
    _tilt = Offset(tilt.dx.clamp(-1.0, 1.0), tilt.dy.clamp(-1.0, 1.0));
  }
}
