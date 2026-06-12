import 'package:flutter/material.dart';

class UserBadge extends StatelessWidget {
  final String username;

  const UserBadge({required this.username});

  @override
  Widget build(BuildContext context) => Chip(label: Text(username));
}
