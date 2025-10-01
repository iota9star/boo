part of 'creature.dart';

class CreatureInteraction {
  CreatureInteraction(this._creatures);

  static const int _newArrivalDuration = 1500;
  static const double _newArrivalLookChance = 0.9;

  final List<Creature> _creatures;

  Creature? _newCreature;
  int _arrivalTime = 0;

  void creatureArrived(Creature creature, int timeMillis) {
    _newCreature = creature;
    _arrivalTime = timeMillis;
    notice(creature, timeMillis);
  }

  void notice(Creature creature, int timeMillis) {
    for (final Creature other in _creatures) {
      if (other == creature) {
        break;
      }
      other.lookIfAble(timeMillis, creature);
    }
  }

  bool isNewArrival(int timeMillis) {
    if (_newCreature != null &&
        timeMillis - _arrivalTime > _newArrivalDuration) {
      _newCreature = null;
    }
    return _newCreature != null;
  }

  Creature getLookTarget(Creature creature) {
    if (_newCreature != null &&
        _newCreature != creature &&
        BooMath.flip(_newArrivalLookChance)) {
      return _newCreature!;
    }
    Creature target;
    do {
      target = BooMath.chooseAtRandom(_creatures);
    } while (target == creature);
    return target;
  }
}
