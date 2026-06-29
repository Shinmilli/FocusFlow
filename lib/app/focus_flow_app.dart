import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/domain/auth_state.dart';
import '../features/auth/presentation/auth_providers.dart';
import '../features/notifications/presentation/notification_providers.dart';
import '../features/sync/presentation/sync_providers.dart';
import '../features/sync/sync_invalidation.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class FocusFlowApp extends ConsumerWidget {
  const FocusFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(notificationInitProvider);
    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (next.phase != AuthPhase.authenticated) return;
      if (prev?.phase == AuthPhase.authenticated) return;
      Future.microtask(() async {
        try {
          await ref.read(userSyncServiceProvider).pullFromServerApplyPrefs();
          invalidateSyncedUserCaches(ref);
        } catch (_) {}
      });
    });
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'FocusFlow',
      theme: buildAppTheme(),
      routerConfig: router,
    );
  }
}
