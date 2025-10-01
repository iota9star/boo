import 'package:flutter/material.dart';

import 'boo/ui/experience_hub_page.dart';

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
      home: const BooExperienceHubPage(),
    );
  }
}
