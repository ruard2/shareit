import 'package:flutter/material.dart';
import '../screens/home_screen.dart';

final Map<String, WidgetBuilder> appRoutes = {
  '/': (context) => const HomeScreen(),
};
