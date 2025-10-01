import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/boo_world.dart';

class BooScene extends StatefulWidget {
  const BooScene({super.key, required this.world});

  final BooWorld world;

  @override
  State<BooScene> createState() => _BooSceneState();
}

class _BooSceneState extends State<BooScene>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  int _timeMillis = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    if (!mounted) {
      return;
    }
    setState(() {
      _timeMillis = DateTime.now().millisecondsSinceEpoch;
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CustomPaint(
        painter: _BooPainter(world: widget.world, timeMillis: _timeMillis),
      ),
    );
  }
}

class _BooPainter extends CustomPainter {
  const _BooPainter({required this.world, required this.timeMillis});

  final BooWorld world;
  final int timeMillis;

  @override
  void paint(Canvas canvas, Size size) {
    world.update(timeMillis, size);
    world.paint(canvas, size, timeMillis);
  }

  @override
  bool shouldRepaint(_BooPainter oldDelegate) {
    return oldDelegate.timeMillis != timeMillis || oldDelegate.world != world;
  }
}
