import 'package:flutter/material.dart';

import 'pages/home_page.dart';
import 'pages/support_page.dart';
import 'theme.dart';

void main() => runApp(const AsbStudioApp());

class AsbStudioApp extends StatelessWidget {
  const AsbStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ASB studio',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      initialRoute: '/',
      routes: {
        '/': (_) => const HomePage(),
        '/support': (_) => const SupportPage(),
      },
    );
  }
}
