import 'package:flutter/material.dart';

import '../../../../app/theme/app_chrome.dart';

class LeaveHintCard extends StatelessWidget {
  const LeaveHintCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: AppChrome.softCardDecoration(),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF4A5060),
              height: 1.35,
            ),
      ),
    );
  }
}

