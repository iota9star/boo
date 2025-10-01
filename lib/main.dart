import 'package:flutter/material.dart';

import 'boo/ui/camera_boo_page.dart';
import 'boo/ui/motion_boo_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BooApp());
}

class BooApp extends StatelessWidget {
  const BooApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Boo Experiences',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C63FF)),
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
      ),
      home: const _BooHomePage(),
    );
  }
}

class _BooHomePage extends StatelessWidget {
  const _BooHomePage();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Boo 实验室'),
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(text: 'Motion Boo'),
              Tab(text: 'Camera Boo'),
            ],
          ),
        ),
        body: const TabBarView(
          physics: NeverScrollableScrollPhysics(),
          children: <Widget>[
            MotionBooPage(),
            CameraBooPage(),
          ],
        ),
      ),
    );
  }
}
