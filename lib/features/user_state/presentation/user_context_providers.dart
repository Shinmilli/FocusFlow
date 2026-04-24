import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/user_life_context.dart';

final userLifeContextProvider =
    StateNotifierProvider<UserLifeContextNotifier, UserLifeContext>((ref) {
  return UserLifeContextNotifier();
});

class UserLifeContextNotifier extends StateNotifier<UserLifeContext> {
  UserLifeContextNotifier() : super(const UserLifeContext());

  void update(UserLifeContext ctx) => state = ctx;
}
