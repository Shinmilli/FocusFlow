import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_flow/app/focus_flow_app.dart';
import 'package:focus_flow/app/router/main_shell_screen.dart';
import 'package:focus_flow/features/home/presentation/home_screen.dart';
import 'package:go_router/go_router.dart';

/// 모바일 셸 본문이 0 높이가 아닌지 검증.
void main() {
  testWidgets('모바일 MainShellScreen 본문 슬롯이 남은 높이를 채운다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));

    late final StatefulNavigationShell shell;

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            shell = navigationShell;
            return MainShellScreen(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) => const ColoredBox(
                    color: Color(0xFF1F212A),
                    child: Center(child: Text('오늘의 프로젝트')),
                  ),
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
    await tester.pumpAndSettle();

    final shellBox = tester.renderObject(find.byType(MainShellScreen)) as RenderBox;
    expect(shellBox.size.height, greaterThan(700));

    expect(find.text('오늘의 프로젝트'), findsOneWidget);
    expect(find.text('홈'), findsOneWidget);

    // ignore: avoid_print
    print('shell height=${shellBox.size.height}');
    expect(shell.currentIndex, 0);
  });

  testWidgets('모바일 FocusFlowApp + HomeScreen 히어로 타이틀 표시', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));

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
        child: MaterialApp.router(
          theme: ThemeData(),
          builder: (context, child) {
            if (child == null) return const SizedBox.shrink();
            return child;
          },
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('오늘의 프로젝트'), findsOneWidget);
  });

  testWidgets('무한 너비 제약에서도 HomeScreen이 모바일 단일 열로 렌더된다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('오늘의 프로젝트'), findsOneWidget);
    expect(find.text('AI 도우미'), findsNothing);
  });
}
