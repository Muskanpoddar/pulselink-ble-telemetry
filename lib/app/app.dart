import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../features/bluetooth/presentation/screens/home_screen.dart';
import 'theme/app_theme.dart';

class PulseLinkApp extends StatelessWidget {
  const PulseLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const HomeScreen(),
    );
  }
}
