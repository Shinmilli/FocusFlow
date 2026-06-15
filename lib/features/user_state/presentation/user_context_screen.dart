import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_chrome.dart';
import 'user_context_panel.dart';

class UserContextScreen extends ConsumerWidget {
  const UserContextScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppChrome.pageBackground,
      appBar: AppBar(
        backgroundColor: AppChrome.topBarBackground,
        foregroundColor: AppChrome.topBarForeground,
        surfaceTintColor: Colors.transparent,
        title: const Text('오늘 상태'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Container(
            width: double.infinity,
            decoration: AppChrome.softCardDecoration(),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: UserContextPanel(
              onSaved: () {
                if (!context.mounted) return;
                context.go('/');
              },
            ),
          ),
        ],
      ),
    );
  }
}
