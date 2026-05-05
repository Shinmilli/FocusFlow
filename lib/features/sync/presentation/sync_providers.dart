import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../application/user_sync_scheduler.dart';
import '../application/user_sync_service.dart';
import '../data/user_sync_api_client.dart';

final userSyncApiClientProvider = Provider<UserSyncApiClient>((ref) {
  return UserSyncApiClient(auth: ref.watch(authApiClientProvider));
});

final userSyncServiceProvider = Provider<UserSyncService>((ref) {
  return UserSyncService(ref, ref.watch(userSyncApiClientProvider));
});

final userSyncSchedulerProvider = Provider<UserSyncScheduler>((ref) {
  final svc = ref.watch(userSyncServiceProvider);
  final sched = UserSyncScheduler(ref, () => svc.pushFromLocal());
  ref.onDispose(sched.dispose);
  return sched;
});
