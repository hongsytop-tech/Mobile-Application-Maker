#!/usr/bin/env bash
# flutter_local_notifications가 동작하도록 AndroidManifest.xml에 권한·리시버를 추가합니다.
# 사용법: `flutter create .` 이후 한 번 실행하면 됩니다.

set -euo pipefail

MANIFEST="android/app/src/main/AndroidManifest.xml"
if [ ! -f "$MANIFEST" ]; then
  echo "❌ $MANIFEST 가 없어요. 먼저 'flutter create .'를 실행하세요." >&2
  exit 1
fi

if grep -q "RECEIVE_BOOT_COMPLETED" "$MANIFEST"; then
  echo "✅ 이미 패치되어 있어요. 건너뜁니다."
  exit 0
fi

# manifest 태그 바로 안쪽에 권한 추가
python3 - "$MANIFEST" <<'PY'
import re, sys
path = sys.argv[1]
with open(path) as f:
    s = f.read()

permissions = '''
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.VIBRATE"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>
'''

receivers = '''
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
'''

# 권한: <manifest ...> 바로 다음 줄에 삽입
s = re.sub(r'(<manifest[^>]*>)', r'\1' + permissions, s, count=1)

# 리시버: </application> 바로 앞에 삽입
s = s.replace('</application>', receivers + '    </application>')

with open(path, 'w') as f:
    f.write(s)

print("✅ AndroidManifest.xml 패치 완료")
PY
