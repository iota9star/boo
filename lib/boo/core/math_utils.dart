import 'dart:math' as math;
import 'package:flutter/animation.dart';

class BooMath {
  static const double twoPi = math.pi * 2;
  static const double pi = math.pi;
  static const double halfPi = math.pi / 2;
  static const double quarterPi = math.pi / 4;

  static final math.Random _random = math.Random();

  static double clamp(double value, double min, double max) {
    if (value < min) {
      return min;
    }
    if (value > max) {
      return max;
    }
    return value;
  }

  static double map(
    double value,
    double inMin,
    double inMax,
    double outMin,
    double outMax, [
    Curve? curve,
  ]) {
    final double span = inMax - inMin;
    if (span == 0) {
      return outMin;
    }
    double t = (value - inMin) / span;
    if (curve != null) {
      t = curve.transform(t);
    }
    return outMin + (outMax - outMin) * t;
  }

  static double clampedMap(
    double value,
    double inMin,
    double inMax,
    double outMin,
    double outMax, [
    Curve? curve,
  ]) {
    if (value <= inMin) {
      return outMin;
    }
    if (value >= inMax) {
      return outMax;
    }
    return map(value, inMin, inMax, outMin, outMax, curve);
  }

  static int clampedMapInt(
    double value,
    double inMin,
    double inMax,
    int outMin,
    int outMax, [
    Curve? curve,
  ]) {
    return clampedMap(
      value,
      inMin,
      inMax,
      outMin.toDouble(),
      outMax.toDouble(),
      curve,
    ).round();
  }

  static double cycle(int millis, double periodMillis) {
    final double v = millis % periodMillis;
    return map(v, 0, periodMillis, 0, 1);
  }

  static double oscillate(
    int millis,
    double periodMillis, [
    double phaseShift = 0,
  ]) {
    return math.sin(((millis / periodMillis) + phaseShift) * twoPi);
  }

  static double fractionalPart(double value) {
    return value - value.floorToDouble();
  }

  static double random(double min, double max) {
    return map(_random.nextDouble(), 0, 1, min, max);
  }

  static int randomInt(int min, int maxInclusive) {
    return min + _random.nextInt(maxInclusive - min + 1);
  }

  static bool flip(double chance) {
    return _random.nextDouble() < chance;
  }

  static T chooseAtRandom<T>(List<T> list) {
    return list[_random.nextInt(list.length)];
  }
}
