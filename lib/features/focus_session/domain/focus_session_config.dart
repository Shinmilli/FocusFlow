/// 집중 세션 설정(카운트다운, 짧은 시작 등).
class FocusSessionConfig {
  const FocusSessionConfig({
    this.durationMinutes = 25,
    this.countdownSeconds = 3,
    this.quickStartMinutes = 5,
  });

  final int durationMinutes;
  final int countdownSeconds;
  final int quickStartMinutes;
}
