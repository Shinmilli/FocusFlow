import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/notifications/presentation/notification_providers.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class FocusFlowApp extends ConsumerWidget {
  const FocusFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(notificationInitProvider);
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: 'FocusFlow',
      theme: buildAppTheme(),
      routerConfig: router,
    );
  }
}
