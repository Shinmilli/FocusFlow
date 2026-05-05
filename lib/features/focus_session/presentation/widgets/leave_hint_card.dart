import 'package:flutter/material.dart';

import '../../../../app/theme/app_chrome.dart';

class LeaveHintCard extends StatelessWidget {
  const LeaveHintCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFEDE9FE); // 연보라
    const border = Color(0xFFD6BCFA);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF4A2C7A),
              height: 1.35,
            ),
      ),
    );
  }
}

