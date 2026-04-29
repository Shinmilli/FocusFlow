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
      debugShowCheckedModeBanner: false,
      title: 'FocusFlow',
      theme: buildAppTheme(),
      builder: (context, child) {
        final width = MediaQuery.of(context).size.width;
        final isMobile = width < 760;
        final maxWidth = isMobile ? width : (width < 1200 ? 980.0 : 1180.0);
        final horizontalPadding = isMobile ? 0.0 : (width < 1200 ? 12.0 : 20.0);

        if (child == null) return const SizedBox.shrink();
        if (isMobile) return child;

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
