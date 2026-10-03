import 'package:flutter/material.dart';

import 'core/antagonistic_theme.dart';
import 'presentation/antagonistic_home_screen.dart';

class AntagonisticTraderApp extends StatelessWidget {
  const AntagonisticTraderApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = AntagonisticTheme.dark();
    return MaterialApp(
      title: 'Antagonistic Trader',
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.dark,
      home: const AntagonisticHomeScreen(),
    );
  }
}
