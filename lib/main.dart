import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/focus_flow_app.dart';
import 'core/timezone/app_timezones.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initializeAppTimeZones();
  runApp(
    const ProviderScope(
      child: FocusFlowApp(),
    ),
  );
}
