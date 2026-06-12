import 'package:flutter/material.dart';

class ItemCard extends StatelessWidget {
  final String title;

  const ItemCard({required this.title});

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(title: Text(title)),
      );
}
