/// Render에 배포한 API 베이스 URL (끝 슬래시 없이).
/// 예: flutter run --dart-define=API_BASE_URL=https://focusflow-api.onrender.com
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: '',
);

bool get kApiBaseUrlConfigured => kApiBaseUrl.trim().isNotEmpty;

String apiUrl(String path) {
  final base = kApiBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
  final p = path.startsWith('/') ? path : '/$path';
  return '$base$p';
}
