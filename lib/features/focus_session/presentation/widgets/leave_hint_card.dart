import 'package:flutter/material.dart';

class LeaveHintCard extends StatelessWidget {
  const LeaveHintCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(text),
      ),
    );
  }
}

