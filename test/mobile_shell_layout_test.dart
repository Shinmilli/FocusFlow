import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_flow/app/layout/desktop_nav_rail.dart';
import 'package:focus_flow/app/router/main_shell_screen.dart';
import 'package:focus_flow/features/home/presentation/home_screen.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('뷰포트 390px면 하단 네비 + 홈 본문 표시', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return MainShellScreen(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) => const HomeScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('오늘의 프로젝트'), findsOneWidget);
    expect(find.text('홈'), findsOneWidget);
    expect(find.byType(DesktopNavRail), findsNothing);

    final scroll = tester.renderObject<RenderBox>(find.byType(CustomScrollView));
    expect(scroll.size.height, greaterThan(400));
    expect(scroll.size.width, greaterThan(300));
  });

  testWidgets('HomeScreen 단독 — 좁은 뷰포트에서 모바일 단일 열', (tester) async {
    await tester.binding.setSurfaceSize(const Size(300, 640));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('오늘의 프로젝트'), findsOneWidget);
    expect(find.text('AI 도우미'), findsNothing);
  });

  testWidgets('HomeScreen — 넓은 부모 제약 + 좁은 뷰포트', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: LayoutBuilder(
            builder: (context, constraints) {
              return SizedBox(
                width: 980,
                child: const HomeScreen(),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('오늘의 프로젝트'), findsOneWidget);
    expect(find.text('AI 도우미'), findsNothing);
  });
}
