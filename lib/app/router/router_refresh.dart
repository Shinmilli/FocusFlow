import 'package:flutter/foundation.dart';

/// go_router가 auth 상태 변경 시 redirect를 다시 평가하도록 합니다.
class GoRouterRefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
