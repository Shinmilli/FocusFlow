import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 로컬 스케줄 알림용. 기기 타임존 대신 MVP는 Asia/Seoul 고정(한국 사용자 기준).
void initializeAppTimeZones() {
  tzdata.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
}
