import 'dart:math' as math;
import 'dart:ui';

import 'math_utils.dart';

class Bubble {
  Bubble()
    : _rotationPeriods = List<int>.generate(
        8,
        (_) => BooMath.randomInt(_minPeriod, _maxPeriod),
      );

  static const double _spline8 = 0.2652031;
  static const double _sqrtHalf = 0.7071067811865476; // sqrt(0.5)

  static const List<double> _circle8X = <double>[
    0,
    _sqrtHalf,
    1,
    _sqrtHalf,
    0,
    -_sqrtHalf,
    -1,
    -_sqrtHalf,
  ];

  static const List<double> _circle8Y = <double>[
    1,
    _sqrtHalf,
    0,
    -_sqrtHalf,
    -1,
    -_sqrtHalf,
    0,
    _sqrtHalf,
  ];

  static const List<double> _circle8Theta = <double>[
    0,
    -BooMath.quarterPi,
    -BooMath.halfPi,
    -3 * BooMath.quarterPi,
    BooMath.pi,
    3 * BooMath.quarterPi,
    BooMath.halfPi,
    BooMath.quarterPi,
  ];

  static final List<double> _circle8Ax = _calculateAx();
  static final List<double> _circle8Ay = _calculateAy();
  static final List<double> _circle8Bx = _calculateBx();
  static final List<double> _circle8By = _calculateBy();

  static const int _minPeriod = 1500;
  static const int _maxPeriod = 2500;
  static const double _wobbleAmount = 0.035;

  final List<int> _rotationPeriods;
  final Path _path = Path();

  void draw(Canvas canvas, Paint paint, double size, int millis) {
    _path.reset();
    for (int i = 0; i < 8; i++) {
      final int j = (i + 1) % 8;
      final double iTheta =
          BooMath.cycle(millis, _rotationPeriods[i].toDouble()) * BooMath.twoPi;
      final double jTheta =
          BooMath.cycle(millis, _rotationPeriods[j].toDouble()) * BooMath.twoPi;
      final double iX = math.cos(iTheta) * size * _wobbleAmount;
      final double iY = math.sin(iTheta) * size * _wobbleAmount;
      final double jX = math.cos(jTheta) * size * _wobbleAmount;
      final double jY = math.sin(jTheta) * size * _wobbleAmount;
      final double startX = _circle8X[i] * size + iX;
      final double startY = _circle8Y[i] * size + iY;
      final double endX = _circle8X[j] * size + jX;
      final double endY = _circle8Y[j] * size + jY;
      final double control1X = _circle8Bx[i] * size + iX;
      final double control1Y = _circle8By[i] * size + iY;
      final double control2X = _circle8Ax[j] * size + jX;
      final double control2Y = _circle8Ay[j] * size + jY;
      if (i == 0) {
        _path.moveTo(startX, startY);
      }
      _path.cubicTo(control1X, control1Y, control2X, control2Y, endX, endY);
    }
    _path.close();
    canvas.drawPath(_path, paint);
  }

  static List<double> _calculateAx() {
    return List<double>.generate(8, (int i) {
      return _circle8X[i] - math.cos(_circle8Theta[i]) * _spline8;
    });
  }

  static List<double> _calculateAy() {
    return List<double>.generate(8, (int i) {
      return _circle8Y[i] - math.sin(_circle8Theta[i]) * _spline8;
    });
  }

  static List<double> _calculateBx() {
    return List<double>.generate(8, (int i) {
      return _circle8X[i] + math.cos(_circle8Theta[i]) * _spline8;
    });
  }

  static List<double> _calculateBy() {
    return List<double>.generate(8, (int i) {
      return _circle8Y[i] + math.sin(_circle8Theta[i]) * _spline8;
    });
  }
}
