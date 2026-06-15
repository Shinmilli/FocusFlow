/// Render에 배포한 API 베이스 URL (끝 슬래시 없이).
/// 로컬 전용: `flutter run --dart-define=API_BASE_URL=`
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://focusflow-4ctc.onrender.com',
);

bool get kApiBaseUrlConfigured => kApiBaseUrl.trim().isNotEmpty;

String apiUrl(String path) {
  final base = kApiBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
  final p = path.startsWith('/') ? path : '/$path';
  return '$base$p';
}
