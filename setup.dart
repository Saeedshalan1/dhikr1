// يجهّز ملفات Android وiOS بعد أمر flutter create.
// التشغيل:  dart run tool/setup.dart
import 'dart:io';

const _required = [
  'assets/icon/icon.png',
  'assets/icon/foreground.png',
  'assets/icon/splash.png',
  'assets/icon/notification.png',
  'assets/sounds/tap.wav',
  'assets/sounds/goal.wav',
  'assets/fonts/Amiri-Regular.ttf',
  'assets/fonts/Amiri-Bold.ttf',
  'assets/fonts/Tajawal-Regular.ttf',
  'assets/fonts/Tajawal-Medium.ttf',
  'assets/fonts/Tajawal-Bold.ttf',
  'assets/fonts/Tajawal-ExtraBold.ttf',
];

void main() {
  final missing = _required.where((f) => !File(f).existsSync()).toList();
  if (missing.isNotEmpty) {
    stderr.writeln('❌ MISSING FILES — ارفع هذه الملفات إلى GitHub في نفس المسار:');
    for (final f in missing) {
      stderr.writeln('   - $f');
    }
    stderr.writeln('\nموجود في المجلد الحالي:');
    for (final e in Directory('.').listSync(recursive: true)) {
      final p = e.path;
      if (!p.contains('.dart_tool') && !p.contains('/android/') && !p.contains('/ios/') && !p.contains('.git/') && !p.contains('/build/')) {
        stderr.writeln('   $p');
      }
    }
    exit(1);
  }
  try {
    var ok = true;
    ok &= _android();
    ok &= _ios();
    stdout.writeln(ok ? '\n✅ تم تجهيز المشروع.' : '\n⚠️ انتهى مع ملاحظات، راجع الرسائل أعلاه.');
  } catch (e, st) {
    stderr.writeln('❌ ERROR: $e\n$st');
    exit(1);
  }
}

bool _android() {
  final manifest = File('android/app/src/main/AndroidManifest.xml');
  if (!manifest.existsSync()) {
    stderr.writeln('❌ لم أجد مجلد android. شغّل أولاً: flutter create . --org com.swalaf --project-name dhikr --platforms android,ios');
    return false;
  }
  var m = manifest.readAsStringSync();

  const perms = [
    'android.permission.POST_NOTIFICATIONS',
    'android.permission.RECEIVE_BOOT_COMPLETED',
    'android.permission.VIBRATE',
  ];
  for (final p in perms) {
    if (!m.contains(p)) {
      m = m.replaceFirst('<application', '<uses-permission android:name="$p"/>\n    <application');
    }
  }

  if (!m.contains('ScheduledNotificationReceiver')) {
    const receivers = '''
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
    </application>''';
    m = m.replaceFirst('</application>', receivers);
  }
  m = m.replaceFirst(RegExp(r'android:label="[^"]*"'), 'android:label="ذِكْر"');
  manifest.writeAsStringSync(m);
  stdout.writeln('✓ AndroidManifest.xml');

  // أيقونة الإشعار
  final drawable = Directory('android/app/src/main/res/drawable')..createSync(recursive: true);
  final icon = File('assets/icon/notification.png');
  if (icon.existsSync()) {
    icon.copySync('${drawable.path}/ic_notification.png');
    stdout.writeln('✓ أيقونة الإشعار');
  } else {
    stderr.writeln('⚠️ لم أجد assets/icon/notification.png');
  }

  // تفعيل desugaring المطلوب لحزمة الإشعارات
  final kts = File('android/app/build.gradle.kts');
  final groovy = File('android/app/build.gradle');
  if (kts.existsSync()) {
    var g = kts.readAsStringSync();
    if (!g.contains('isCoreLibraryDesugaringEnabled')) {
      g = g.replaceFirst('compileOptions {', 'compileOptions {\n        isCoreLibraryDesugaringEnabled = true');
    }
    if (!g.contains('desugar_jdk_libs')) {
      g = g.contains(RegExp(r'^dependencies \{', multiLine: true))
          ? g.replaceFirst(RegExp(r'^dependencies \{', multiLine: true),
              'dependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")')
          : '$g\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n';
    }
    kts.writeAsStringSync(g);
    stdout.writeln('✓ build.gradle.kts');
  } else if (groovy.existsSync()) {
    var g = groovy.readAsStringSync();
    if (!g.contains('coreLibraryDesugaringEnabled')) {
      g = g.replaceFirst('compileOptions {', 'compileOptions {\n        coreLibraryDesugaringEnabled true');
    }
    if (!g.contains('desugar_jdk_libs')) {
      g = g.contains(RegExp(r'^dependencies \{', multiLine: true))
          ? g.replaceFirst(RegExp(r'^dependencies \{', multiLine: true),
              "dependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'")
          : "$g\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n";
    }
    groovy.writeAsStringSync(g);
    stdout.writeln('✓ build.gradle');
  } else {
    stderr.writeln('⚠️ لم أجد android/app/build.gradle(.kts) — فعّل coreLibraryDesugaring يدوياً.');
    return false;
  }
  return true;
}

bool _ios() {
  final plist = File('ios/Runner/Info.plist');
  if (!plist.existsSync()) {
    stdout.writeln('… لا يوجد مجلد ios (تخطّي)');
    return true;
  }
  var p = plist.readAsStringSync();
  String setKey(String src, String key, String valueXml) {
    final re = RegExp('<key>$key</key>\\s*<[^>]+>[^<]*</[^>]+>');
    final entry = '<key>$key</key>\n\t$valueXml';
    return re.hasMatch(src) ? src.replaceFirst(re, entry) : src.replaceFirst('<dict>', '<dict>\n\t$entry');
  }

  p = setKey(p, 'CFBundleDisplayName', '<string>ذِكْر</string>');
  p = setKey(p, 'CFBundleDevelopmentRegion', '<string>ar</string>');
  if (!p.contains('CFBundleLocalizations')) {
    p = p.replaceFirst('<dict>', '<dict>\n\t<key>CFBundleLocalizations</key>\n\t<array>\n\t\t<string>ar</string>\n\t</array>');
  }
  if (!p.contains('ITSAppUsesNonExemptEncryption')) {
    p = p.replaceFirst('<dict>', '<dict>\n\t<key>ITSAppUsesNonExemptEncryption</key>\n\t<false/>');
  }
  plist.writeAsStringSync(p);
  stdout.writeln('✓ Info.plist');

  // عرض الإشعارات أثناء فتح التطبيق
  final delegate = File('ios/Runner/AppDelegate.swift');
  if (delegate.existsSync()) {
    var d = delegate.readAsStringSync();
    if (!d.contains('UNUserNotificationCenter')) {
      if (!d.contains('import UserNotifications')) d = d.replaceFirst('import UIKit', 'import UIKit\nimport UserNotifications');
      final marker = RegExp(r'^(\s*)GeneratedPluginRegistrant\.register\(with:', multiLine: true);
      final match = marker.firstMatch(d);
      if (match != null) {
        final indent = match.group(1)!;
        d = d.replaceFirst(marker, '${indent}UNUserNotificationCenter.current().delegate = self\n${match.group(0)}');
        delegate.writeAsStringSync(d);
        stdout.writeln('✓ AppDelegate.swift');
      } else {
        stdout.writeln('⚠️ أضف يدوياً في AppDelegate.swift داخل didFinishLaunching:  UNUserNotificationCenter.current().delegate = self');
      }
    }
  }
  return true;
}
