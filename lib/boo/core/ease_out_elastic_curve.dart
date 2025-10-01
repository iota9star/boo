import 'dart:math' as math;
import 'package:flutter/animation.dart';

class EaseOutElasticCurve extends Curve {
  const EaseOutElasticCurve();

  @override
  double transform(double t) {
    if (t == 0 || t == 1) {
      return t;
    }
    const double s = 0.3 / 4.0;
    final double exponent = math.pow(2.0, -15.0 * t * t).toDouble();
    return exponent * math.sin((t * t - s) * (math.pi * 2) / 0.3) + 1.0;
  }
}
