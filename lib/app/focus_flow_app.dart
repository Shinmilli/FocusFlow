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

  static const double _compactBreakpoint = 760;

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
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();

        final width = MediaQuery.sizeOf(context).width;
        final isMobile = width < _compactBreakpoint;

        if (isMobile) return child;

        final maxWidth = width < 1200 ? 980.0 : 1180.0;
        final horizontalPadding = width < 1200 ? 12.0 : 20.0;

        return ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: child,
              ),
            ),
          ),
        );
      },
      routerConfig: router,
    );
  }
}
