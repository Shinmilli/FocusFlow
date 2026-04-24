import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focus_flow/app/focus_flow_app.dart';
import 'package:focus_flow/app/router/app_router.dart';
import 'package:focus_flow/features/home/presentation/home_screen.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('앱이 FocusFlow 타이틀을 표시', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          goRouterProvider.overrideWith((ref) {
            return GoRouter(
              initialLocation: '/',
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) => const HomeScreen(),
                ),
              ],
            );
          }),
        ],
        child: const FocusFlowApp(),
      ),
    );
    await tester.pump();
    expect(find.text('FocusFlow'), findsOneWidget);
  });
}
