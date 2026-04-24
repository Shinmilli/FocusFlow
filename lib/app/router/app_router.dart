import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/api_config.dart';
import '../../features/auth/domain/auth_state.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/focus_session/presentation/focus_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/insights/presentation/insights_screen.dart';
import '../../features/mcp/presentation/mcp_connections_screen.dart';
import '../../features/planning/presentation/add_block_screen.dart';
import '../../features/planning/presentation/planning_screen.dart';
import '../../features/planning/presentation/today_select_screen.dart';
import '../../features/user_state/presentation/user_context_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(routerRefreshListenableProvider);

  String? redirectLogic(BuildContext context, GoRouterState state) {
    if (!kApiBaseUrlConfigured) {
      if (state.matchedLocation == '/splash' ||
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register') {
        return '/';
      }
      return null;
    }

    final auth = ref.read(authControllerProvider);
    switch (auth.phase) {
      case AuthPhase.bootstrapping:
        if (state.matchedLocation != '/splash') return '/splash';
        return null;
      case AuthPhase.unauthenticated:
        if (state.matchedLocation == '/login' || state.matchedLocation == '/register') {
          return null;
        }
        return '/login';
      case AuthPhase.authenticated:
        if (state.matchedLocation == '/login' ||
            state.matchedLocation == '/register' ||
            state.matchedLocation == '/splash') {
          return '/';
        }
        return null;
    }
  }

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: kApiBaseUrlConfigured ? '/splash' : '/',
    refreshListenable: refresh,
    redirect: redirectLogic,
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/plan',
        builder: (context, state) => const PlanningScreen(),
      ),
      GoRoute(
        path: '/plan/select',
        builder: (context, state) => const TodaySelectScreen(),
      ),
      GoRoute(
        path: '/plan/add',
        builder: (context, state) => const AddBlockScreen(),
      ),
      GoRoute(
        path: '/focus',
        builder: (context, state) => const FocusScreen(),
      ),
      GoRoute(
        path: '/context',
        builder: (context, state) => const UserContextScreen(),
      ),
      GoRoute(
        path: '/insights',
        builder: (context, state) => const InsightsScreen(),
      ),
      GoRoute(
        path: '/mcp',
        builder: (context, state) => const McpConnectionsScreen(),
      ),
    ],
  );
});
