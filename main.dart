// ذِكْر — تطبيق التسبيح والاستغفار التفاعلي (ملف واحد)
import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

// ======================== theme.dart ========================
class AppColors {
  static const bg = Color(0xFF03140F);
  static const bgSoft = Color(0xFF062019);
  static const card = Color(0xFF0A2A21);
  static const cardBorder = Color(0xFF13402F);
  static const emerald = Color(0xFF10B981);
  static const emeraldLight = Color(0xFF34D399);
  static const emeraldDeep = Color(0xFF0B7A57);
  static const emeraldDark = Color(0xFF076046);
  static const gold = Color(0xFFE8C46E);
  static const text = Color(0xFFECF5F0);
  static const textDim = Color(0xFF8FB3A5);
  static const textFaint = Color(0xFF5C8173);
  static const danger = Color(0xFFE26D5C);
}

/// خط الواجهة
TextStyle ui({double size = 15, FontWeight weight = FontWeight.w500, Color color = AppColors.text, double? height}) =>
    TextStyle(fontFamily: 'Tajawal', fontSize: size, fontWeight: weight, color: color, height: height);

/// خط الأذكار والآيات
TextStyle quran({double size = 22, FontWeight weight = FontWeight.w700, Color color = AppColors.text, double? height}) =>
    TextStyle(fontFamily: 'Amiri', fontSize: size, fontWeight: weight, color: color, height: height);

ThemeData buildTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    fontFamily: 'Tajawal',
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.emerald,
      secondary: AppColors.gold,
      surface: AppColors.card,
    ),
  );
  return base.copyWith(
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.emerald : const Color(0xFF9DB8AD)),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.emeraldDeep : const Color(0xFF23463A)),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
  );
}

// ======================== data/adhkar.dart ========================
class Dhikr {
  final String id;
  final String name;
  final String icon;
  final List<String> phrases;
  const Dhikr(this.id, this.name, this.icon, this.phrases);
}

const adhkar = <Dhikr>[
  Dhikr('istighfar', 'الاستغفار', '🌿', ['أستغفر الله']),
  Dhikr('tasbih', 'التسبيح', '📿', ['سبحان الله']),
  Dhikr('tahlil', 'التهليل', '☪️', ['لا إله إلا الله']),
  Dhikr('takbir', 'التكبير', '✨', ['الله أكبر']),
  Dhikr('tahmid', 'التحميد', '🤍', ['الحمد لله']),
  Dhikr('mixed', 'أذكار متنوعة', '🌙', [
    'سبحان الله وبحمده',
    'سبحان الله العظيم',
    'لا حول ولا قوة إلا بالله',
    'اللهم صلِّ على محمد',
    'لا إله إلا الله وحده لا شريك له',
    'أستغفر الله وأتوب إليه',
    'سبحان الله والحمد لله ولا إله إلا الله والله أكبر',
  ]),
];

Dhikr dhikrById(String id) => adhkar.firstWhere((d) => d.id == id, orElse: () => adhkar.first);

// ======================== data/model.dart ========================
class TimeOfDayHM {
  final int h;
  final int m;
  const TimeOfDayHM(this.h, this.m);
  Map<String, dynamic> toJson() => {'h': h, 'm': m};
  factory TimeOfDayHM.fromJson(Map<String, dynamic> j) => TimeOfDayHM(j['h'] as int, j['m'] as int);
  int get totalMinutes => h * 60 + m;
  factory TimeOfDayHM.fromMinutes(int v) => TimeOfDayHM(v ~/ 60, v % 60);
}

class Reminder {
  final bool on;
  final TimeOfDayHM time;
  const Reminder(this.on, this.time);
  Reminder copyWith({bool? on, TimeOfDayHM? time}) => Reminder(on ?? this.on, time ?? this.time);
  Map<String, dynamic> toJson() => {'on': on, 'time': time.toJson()};
  factory Reminder.fromJson(Map<String, dynamic> j) =>
      Reminder(j['on'] as bool, TimeOfDayHM.fromJson(Map<String, dynamic>.from(j['time'] as Map)));
}

enum Speed { calm, medium, fast }

class Settings {
  final int dailyGoal;
  final bool sound;
  final bool haptics;
  final Speed speed;
  final String dhikrId;
  final Reminder morning;
  final Reminder evening;
  final Reminder wird;
  final bool istighfarOn;
  final List<int> istighfarHours;

  const Settings({
    this.dailyGoal = 500,
    this.sound = true,
    this.haptics = true,
    this.speed = Speed.calm,
    this.dhikrId = 'istighfar',
    this.morning = const Reminder(true, TimeOfDayHM(6, 30)),
    this.evening = const Reminder(true, TimeOfDayHM(17, 0)),
    this.wird = const Reminder(true, TimeOfDayHM(21, 0)),
    this.istighfarOn = false,
    this.istighfarHours = const [11, 15, 20],
  });

  Settings copyWith({
    int? dailyGoal,
    bool? sound,
    bool? haptics,
    Speed? speed,
    String? dhikrId,
    Reminder? morning,
    Reminder? evening,
    Reminder? wird,
    bool? istighfarOn,
    List<int>? istighfarHours,
  }) =>
      Settings(
        dailyGoal: dailyGoal ?? this.dailyGoal,
        sound: sound ?? this.sound,
        haptics: haptics ?? this.haptics,
        speed: speed ?? this.speed,
        dhikrId: dhikrId ?? this.dhikrId,
        morning: morning ?? this.morning,
        evening: evening ?? this.evening,
        wird: wird ?? this.wird,
        istighfarOn: istighfarOn ?? this.istighfarOn,
        istighfarHours: istighfarHours ?? this.istighfarHours,
      );

  Map<String, dynamic> toJson() => {
        'dailyGoal': dailyGoal,
        'sound': sound,
        'haptics': haptics,
        'speed': speed.name,
        'dhikrId': dhikrId,
        'morning': morning.toJson(),
        'evening': evening.toJson(),
        'wird': wird.toJson(),
        'istighfarOn': istighfarOn,
        'istighfarHours': istighfarHours,
      };

  factory Settings.fromJson(Map<String, dynamic> j) {
    const d = Settings();
    Reminder r(String k, Reminder def) =>
        j[k] is Map ? Reminder.fromJson(Map<String, dynamic>.from(j[k] as Map)) : def;
    return Settings(
      dailyGoal: (j['dailyGoal'] as int?) ?? d.dailyGoal,
      sound: (j['sound'] as bool?) ?? d.sound,
      haptics: (j['haptics'] as bool?) ?? d.haptics,
      speed: Speed.values.firstWhere((s) => s.name == j['speed'], orElse: () => d.speed),
      dhikrId: (j['dhikrId'] as String?) ?? d.dhikrId,
      morning: r('morning', d.morning),
      evening: r('evening', d.evening),
      wird: r('wird', d.wird),
      istighfarOn: (j['istighfarOn'] as bool?) ?? d.istighfarOn,
      istighfarHours: (j['istighfarHours'] as List?)?.map((e) => e as int).toList() ?? d.istighfarHours,
    );
  }
}

class DayRecord {
  int total;
  Map<String, int> byDhikr;
  DayRecord({this.total = 0, Map<String, int>? byDhikr}) : byDhikr = byDhikr ?? {};
  Map<String, dynamic> toJson() => {'total': total, 'byDhikr': byDhikr};
  factory DayRecord.fromJson(Map<String, dynamic> j) => DayRecord(
        total: j['total'] as int,
        byDhikr: Map<String, dynamic>.from(j['byDhikr'] as Map).map((k, v) => MapEntry(k, v as int)),
      );
}

class Challenge {
  final String id;
  final String dhikrId;
  final int target;
  final int days;
  final String startDate;
  const Challenge({required this.id, required this.dhikrId, required this.target, required this.days, required this.startDate});
  Map<String, dynamic> toJson() => {'id': id, 'dhikrId': dhikrId, 'target': target, 'days': days, 'startDate': startDate};
  factory Challenge.fromJson(Map<String, dynamic> j) => Challenge(
        id: j['id'] as String,
        dhikrId: j['dhikrId'] as String,
        target: j['target'] as int,
        days: j['days'] as int,
        startDate: j['startDate'] as String,
      );
}

class AppData {
  Settings settings;
  Map<String, DayRecord> days;
  Map<String, int> totals;
  int lifetime;
  int bestStreak;
  Map<String, String> badges;
  List<Challenge> challenges;
  bool onboarded;

  AppData({
    this.settings = const Settings(),
    Map<String, DayRecord>? days,
    Map<String, int>? totals,
    this.lifetime = 0,
    this.bestStreak = 0,
    Map<String, String>? badges,
    List<Challenge>? challenges,
    this.onboarded = false,
  })  : days = days ?? {},
        totals = totals ?? {},
        badges = badges ?? {},
        challenges = challenges ?? [];

  Map<String, dynamic> toJson() => {
        'version': 1,
        'settings': settings.toJson(),
        'days': days.map((k, v) => MapEntry(k, v.toJson())),
        'totals': totals,
        'lifetime': lifetime,
        'bestStreak': bestStreak,
        'badges': badges,
        'challenges': challenges.map((c) => c.toJson()).toList(),
        'onboarded': onboarded,
      };

  factory AppData.fromJson(Map<String, dynamic> j) => AppData(
        settings: j['settings'] is Map ? Settings.fromJson(Map<String, dynamic>.from(j['settings'] as Map)) : const Settings(),
        days: (j['days'] as Map? ?? {}).map((k, v) => MapEntry(k as String, DayRecord.fromJson(Map<String, dynamic>.from(v as Map)))),
        totals: (j['totals'] as Map? ?? {}).map((k, v) => MapEntry(k as String, v as int)),
        lifetime: (j['lifetime'] as int?) ?? 0,
        bestStreak: (j['bestStreak'] as int?) ?? 0,
        badges: (j['badges'] as Map? ?? {}).map((k, v) => MapEntry(k as String, v as String)),
        challenges: (j['challenges'] as List? ?? []).map((e) => Challenge.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        onboarded: (j['onboarded'] as bool?) ?? false,
      );

  int dayTotal(String key) => days[key]?.total ?? 0;
  bool isDayComplete(String key) => dayTotal(key) >= settings.dailyGoal;

  /// أيام متتالية بلغ فيها الهدف، تنتهي اليوم أو أمس
  int currentStreak() {
    var d = DateTime.now();
    if (!isDayComplete(dateKey(d))) d = addDays(d, -1);
    var n = 0;
    while (isDayComplete(dateKey(d))) {
      n++;
      d = addDays(d, -1);
    }
    return n;
  }
}

/* ---------- أدوات التاريخ والتنسيق ---------- */
String _p2(int n) => n.toString().padLeft(2, '0');
String dateKey([DateTime? d]) {
  final x = d ?? DateTime.now();
  return '${x.year}-${_p2(x.month)}-${_p2(x.day)}';
}

DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n, d.hour, d.minute);

DateTime parseKey(String k) {
  final p = k.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

String formatNum(int n) {
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return (n < 0 ? '-' : '') + b.toString();
}

String formatTime(TimeOfDayHM t) {
  final h12 = t.h % 12 == 0 ? 12 : t.h % 12;
  return '$h12:${_p2(t.m)} ${t.h < 12 ? 'ص' : 'م'}';
}

String daysLabel(int n) {
  if (n == 0) return '0 يوم';
  if (n == 1) return 'يوم واحد';
  if (n == 2) return 'يومان';
  if (n >= 3 && n <= 10) return '$n أيام';
  return '${formatNum(n)} يوماً';
}

class ChallengeProgress {
  final int sum;
  final bool done;
  final int daysLeft;
  final bool expired;
  const ChallengeProgress(this.sum, this.done, this.daysLeft, this.expired);
}

ChallengeProgress challengeProgress(AppData data, Challenge c) {
  var sum = 0;
  final start = parseKey(c.startDate);
  for (var i = 0; i < c.days; i++) {
    sum += data.days[dateKey(addDays(start, i))]?.byDhikr[c.dhikrId] ?? 0;
  }
  final end = addDays(start, c.days - 1);
  final today = parseKey(dateKey());
  final left = end.difference(today).inDays + 1;
  return ChallengeProgress(sum, sum >= c.target, left < 0 ? 0 : left, today.isAfter(end));
}

// ======================== data/badges.dart ========================
class AppBadge {
  final String id;
  final String title;
  final String desc;
  final String icon;
  final bool Function(AppData d) check;
  const AppBadge(this.id, this.title, this.desc, this.icon, this.check);
}

int _maxStreak(AppData d) {
  final c = d.currentStreak();
  return d.bestStreak > c ? d.bestStreak : c;
}

final badges = <AppBadge>[
  AppBadge('first', 'البداية المباركة', 'أول ذكر في التطبيق', '🌱', (d) => d.lifetime >= 1),
  AppBadge('h100', 'مئة ذكر', 'أتممت 100 ذكر', '💚', (d) => d.lifetime >= 100),
  AppBadge('goal1', 'أول ورد', 'أكملت هدفك اليومي لأول مرة', '🎯', (d) => d.isDayComplete(dateKey()) || _maxStreak(d) >= 1),
  AppBadge('k1', 'ألف ذكر', 'أتممت 1,000 ذكر', '⭐', (d) => d.lifetime >= 1000),
  AppBadge('s3', 'ثلاثة أيام', 'سلسلة 3 أيام متتالية', '🔥', (d) => _maxStreak(d) >= 3),
  AppBadge('k10', 'عشرة آلاف', 'أتممت 10,000 ذكر', '🌟', (d) => d.lifetime >= 10000),
  AppBadge('s7', 'أسبوع كامل', 'سلسلة 7 أيام متتالية', '📅', (d) => _maxStreak(d) >= 7),
  AppBadge('all', 'جامع الأذكار', '100 من كل نوع من الأذكار', '📿',
      (d) => ['istighfar', 'tasbih', 'tahlil', 'takbir', 'tahmid'].every((k) => (d.totals[k] ?? 0) >= 100)),
  AppBadge('ist1k', 'المستغفرون بالأسحار', '1,000 استغفار', '🌿', (d) => (d.totals['istighfar'] ?? 0) >= 1000),
  AppBadge('s30', 'شهر من الذكر', 'سلسلة 30 يوماً متتالية', '🌙', (d) => _maxStreak(d) >= 30),
  AppBadge('k100', 'مئة ألف', 'أتممت 100,000 ذكر', '👑', (d) => d.lifetime >= 100000),
];

class Level {
  final int min;
  final String name;
  const Level(this.min, this.name);
}

const levels = <Level>[
  Level(0, 'مبتدئ'),
  Level(500, 'ذاكر'),
  Level(2500, 'مداوم'),
  Level(10000, 'مستغفر'),
  Level(30000, 'ذاكر كثيراً'),
  Level(75000, 'لسانه رطب بذكر الله'),
  Level(150000, 'من الذاكرين الله كثيراً'),
];

class LevelInfo {
  final int index;
  final String name;
  final Level? next;
  final double progress;
  const LevelInfo(this.index, this.name, this.next, this.progress);
}

LevelInfo levelInfo(int lifetime) {
  var i = 0;
  while (i + 1 < levels.length && lifetime >= levels[i + 1].min) {
    i++;
  }
  final cur = levels[i];
  final next = i + 1 < levels.length ? levels[i + 1] : null;
  final p = next == null ? 1.0 : (lifetime - cur.min) / (next.min - cur.min);
  return LevelInfo(i + 1, cur.name, next, p);
}

// ======================== services/notifications.dart ========================
/// التنبيهات المحلية: الصباح، المساء، الاستغفار، وتذكير الورد غير المكتمل.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channelId = 'reminders';
  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      'تذكير الأذكار',
      channelDescription: 'تذكير بأذكار الصباح والمساء والورد اليومي',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_notification',
      color: Color(0xFF10B981),
    ),
    iOS: DarwinNotificationDetails(presentAlert: true, presentBanner: true, presentList: true, presentSound: true),
  );

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(_guessLocalLocation());
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings);
    _ready = true;
  }

  /// يختار منطقة زمنية تطابق إزاحة الجهاز الحالية (بدون حزم إضافية).
  tz.Location _guessLocalLocation() {
    final offset = DateTime.now().timeZoneOffset;
    const preferred = [
      'Asia/Riyadh', 'Asia/Dubai', 'Asia/Kuwait', 'Asia/Qatar', 'Asia/Baghdad', 'Africa/Cairo',
      'Asia/Amman', 'Africa/Casablanca', 'Africa/Algiers', 'Africa/Tunis', 'Europe/London',
      'Europe/Paris', 'Europe/Istanbul', 'Asia/Karachi', 'Asia/Jakarta', 'Asia/Kuala_Lumpur',
      'America/New_York', 'America/Chicago', 'America/Los_Angeles', 'Australia/Sydney',
    ];
    for (final name in preferred) {
      try {
        final loc = tz.getLocation(name);
        if (tz.TZDateTime.now(loc).timeZoneOffset == offset) return loc;
      } catch (_) {}
    }
    for (final loc in tz.timeZoneDatabase.locations.values) {
      if (tz.TZDateTime.now(loc).timeZoneOffset == offset) return loc;
    }
    return tz.UTC;
  }

  Future<bool> ensurePermission({required bool ask}) async {
    await init();
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final enabled = await android?.areNotificationsEnabled() ?? false;
      if (enabled || !ask) return enabled;
      return await android?.requestNotificationsPermission() ?? false;
    }
    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (!ask) {
        final cur = await ios?.checkPermissions();
        return cur?.isEnabled ?? false;
      }
      return await ios?.requestPermissions(alert: true, badge: false, sound: true) ?? false;
    }
    return false;
  }

  static const _istighfarMsgs = [
    'أستغفر الله وأتوب إليه 🌿 لحظة استغفار تجلو القلب',
    'قال ﷺ: «إنه ليُغان على قلبي، وإني لأستغفر الله في اليوم مئة مرة»',
    '﴿فَقُلْتُ اسْتَغْفِرُوا رَبَّكُمْ إِنَّهُ كَانَ غَفَّارًا﴾',
  ];

  tz.TZDateTime _nextAt(int h, int m) {
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, h, m);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    return at;
  }

  Future<void> _daily(int id, String title, String body, int h, int m) => _plugin.zonedSchedule(
        id,
        title,
        body,
        _nextAt(h, m),
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );

  /// يعيد جدولة جميع التنبيهات حسب الإعدادات والتقدّم الحالي.
  Future<void> rescheduleAll(AppData data) async {
    try {
      await init();
      await _plugin.cancelAll();
      if (!await ensurePermission(ask: false)) return;
      final s = data.settings;

      if (s.morning.on) {
        await _daily(1, '☀️ أذكار الصباح', 'ابدأ يومك بذكر الله، فبذكره تطمئن القلوب', s.morning.time.h, s.morning.time.m);
      }
      if (s.evening.on) {
        await _daily(2, '🌙 أذكار المساء', 'حان وقت أذكار المساء، حصّن نفسك بذكر الله', s.evening.time.h, s.evening.time.m);
      }
      if (s.istighfarOn) {
        for (var i = 0; i < s.istighfarHours.length; i++) {
          await _daily(10 + i, '🌿 لحظة استغفار', _istighfarMsgs[i % _istighfarMsgs.length], s.istighfarHours[i], 0);
        }
      }

      // تذكير الورد: لكل يوم من الأيام السبعة القادمة، ويُستثنى اليوم إن اكتمل
      if (s.wird.on) {
        final now = tz.TZDateTime.now(tz.local);
        for (var i = 0; i < 7; i++) {
          final day = now.add(Duration(days: i));
          final at = tz.TZDateTime(tz.local, day.year, day.month, day.day, s.wird.time.h, s.wird.time.m);
          if (!at.isAfter(now)) continue;
          final key = dateKey(DateTime(day.year, day.month, day.day));
          if (i == 0 && data.isDayComplete(key)) continue;
          final left = s.dailyGoal - data.dayTotal(key);
          await _plugin.zonedSchedule(
            100 + i,
            '📿 وِردك اليومي',
            i == 0 ? 'بقي لك ${formatNum(left < 0 ? 0 : left)} ذكراً لإكمال هدف اليوم' : 'لم تكمل وِردك بعد، دقائق قليلة تكفي 🤍',
            at,
            _details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
        }
      }
    } catch (_) {
      // التنبيهات ميزة مساعدة؛ لا نوقف التطبيق إن فشلت الجدولة
    }
  }
}

// ======================== services/feedback.dart ========================
/// الصوت الهادئ والاهتزاز عند الضغط.
class TapFeedback {
  TapFeedback._();
  static final instance = TapFeedback._();

  final List<AudioPlayer> _pool = [];
  AudioPlayer? _goal;
  int _idx = 0;

  Future<void> init() async {
    if (_pool.isNotEmpty) return;
    try {
      // يحترم وضع الصامت في iPhone ولا يوقف موسيقى المستخدم
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(respectSilence: true, focus: AudioContextConfigFocus.mixWithOthers).build(),
      );
    } catch (_) {}
    for (var i = 0; i < 4; i++) {
      final p = AudioPlayer();
      try {
        await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setSource(AssetSource('sounds/tap.wav'));
      } catch (_) {}
      _pool.add(p);
    }
    _goal = AudioPlayer();
  }

  void tap({required bool sound, required bool haptics}) {
    if (sound && _pool.isNotEmpty) {
      final p = _pool[_idx];
      _idx = (_idx + 1) % _pool.length;
      p.play(AssetSource('sounds/tap.wav'), volume: 0.55, mode: PlayerMode.lowLatency).catchError((_) {});
    }
    if (haptics) HapticFeedback.lightImpact();
  }

  void goal({required bool sound, required bool haptics}) {
    if (sound) _goal?.play(AssetSource('sounds/goal.wav'), volume: 0.8).catchError((_) {});
    if (haptics) HapticFeedback.mediumImpact();
  }

  void select({required bool haptics}) {
    if (haptics) HapticFeedback.selectionClick();
  }
}

// ======================== state/app_state.dart ========================
class AddResult {
  final bool goalReached;
  final List<AppBadge> newBadges;
  const AddResult(this.goalReached, this.newBadges);
}

/// الحالة العامة للتطبيق مع الحفظ المحلي.
class AppState extends ChangeNotifier with WidgetsBindingObserver {
  static const _key = 'dhikr:data:v1';

  AppData data = AppData();
  bool ready = false;
  String today = dateKey();
  Timer? _saveTimer;
  SharedPreferences? _prefs;

  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs!.getString(_key);
      if (raw != null) data = AppData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {}
    ready = true;
    WidgetsBinding.instance.addObserver(this);
    notifyListeners();
    NotificationService.instance.rescheduleAll(data);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      today = dateKey();
      notifyListeners();
      NotificationService.instance.rescheduleAll(data);
    } else if (s == AppLifecycleState.paused) {
      _saveNow();
    }
  }

  void _changed({bool reschedule = false}) {
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _saveNow);
    if (reschedule) NotificationService.instance.rescheduleAll(data);
  }

  void _saveNow() {
    _prefs?.setString(_key, jsonEncode(data.toJson()));
  }

  int get todayTotal => data.dayTotal(today);
  int get streak => data.currentStreak();
  int todayFor(String dhikrId) => data.days[dateKey()]?.byDhikr[dhikrId] ?? 0;

  AddResult addDhikr(String id) {
    final k = dateKey();
    today = k;
    final day = data.days.putIfAbsent(k, () => DayRecord());
    final before = day.total;
    day.total += 1;
    day.byDhikr[id] = (day.byDhikr[id] ?? 0) + 1;
    data.totals[id] = (data.totals[id] ?? 0) + 1;
    data.lifetime += 1;

    final goal = data.settings.dailyGoal;
    final goalReached = before < goal && day.total >= goal;
    if (goalReached) {
      final s = data.currentStreak();
      if (s > data.bestStreak) data.bestStreak = s;
    }
    final fresh = badges.where((b) => !data.badges.containsKey(b.id) && b.check(data)).toList();
    for (final b in fresh) {
      data.badges[b.id] = DateTime.now().toIso8601String();
    }
    _changed(reschedule: goalReached);
    return AddResult(goalReached, fresh);
  }

  void updateSettings(Settings s, {bool reschedule = false}) {
    data.settings = s;
    _changed(reschedule: reschedule);
  }

  void addChallenge(String dhikrId, int target, int days) {
    data.challenges.add(Challenge(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      dhikrId: dhikrId,
      target: target,
      days: days,
      startDate: dateKey(),
    ));
    _changed();
  }

  void removeChallenge(String id) {
    data.challenges.removeWhere((c) => c.id == id);
    _changed();
  }

  void finishOnboarding() {
    data.onboarded = true;
    _changed(reschedule: true);
  }

  void resetAll() {
    data = AppData(settings: data.settings, onboarded: true);
    _changed(reschedule: true);
  }
}

/// يوفّر AppState لشجرة الواجهات.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
  static AppState read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

// ======================== widgets/ui.dart ========================
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? borderColor;
  final Color? color;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.borderColor, this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? AppColors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor ?? AppColors.cardBorder),
        ),
        child: child,
      );
}

class ProgressLine extends StatelessWidget {
  final double value;
  final double height;
  final Color color;
  const ProgressLine({super.key, required this.value, this.height = 10, this.color = AppColors.emerald});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: SizedBox(
          height: height,
          child: Stack(children: [
            Container(color: Colors.white.withValues(alpha: 0.07)),
            FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: value.clamp(0.0, 1.0),
              child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height))),
            ),
          ]),
        ),
      );
}

class AppChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool expand;
  const AppChip({super.key, required this.label, required this.onTap, this.active = false, this.expand = false});

  @override
  Widget build(BuildContext context) => Material(
        color: active ? AppColors.emerald : AppColors.card,
        shape: StadiumBorder(side: BorderSide(color: active ? AppColors.emerald : AppColors.cardBorder)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: ui(size: 14, weight: active ? FontWeight.w700 : FontWeight.w500, color: active ? AppColors.bg : AppColors.text),
            ),
          ),
        ),
      );
}

enum BtnKind { primary, ghost, danger }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final BtnKind kind;
  const AppButton({super.key, required this.label, required this.onTap, this.kind = BtnKind.primary});

  @override
  Widget build(BuildContext context) {
    final bg = kind == BtnKind.primary ? AppColors.emerald : Colors.transparent;
    final border = switch (kind) { BtnKind.primary => AppColors.emerald, BtnKind.ghost => AppColors.cardBorder, BtnKind.danger => AppColors.danger };
    final fg = switch (kind) { BtnKind.primary => AppColors.bg, BtnKind.ghost => AppColors.text, BtnKind.danger => AppColors.danger };
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: border)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            child: Text(label, textAlign: TextAlign.center, style: ui(size: 16, weight: FontWeight.w700, color: fg)),
          ),
        ),
      ),
    );
  }
}

class Stepper2 extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;
  final String Function(int)? format;
  const Stepper2({super.key, required this.value, required this.onChanged, required this.min, required this.max, this.step = 1, this.format});

  Widget _btn(String t, String label, VoidCallback f) => Semantics(
        button: true,
        label: label,
        child: InkWell(
          onTap: f,
          customBorder: const CircleBorder(),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.bgSoft, border: Border.all(color: AppColors.cardBorder)),
            child: Text(t, style: ui(size: 20, weight: FontWeight.w700, color: AppColors.emerald)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        _btn('+', 'زيادة', () => onChanged((value + step).clamp(min, max).toInt())),
        SizedBox(
          width: 82,
          child: Text(format?.call(value) ?? '$value', textAlign: TextAlign.center, style: ui(size: 16, weight: FontWeight.w700)),
        ),
        _btn('−', 'إنقاص', () => onChanged((value - step).clamp(min, max).toInt())),
      ]);
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4),
        child: Text(text, style: ui(size: 15, weight: FontWeight.w700, color: AppColors.gold)),
      );
}

class PageTitle extends StatelessWidget {
  final String text;
  const PageTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(text, style: ui(size: 26, weight: FontWeight.w800));
}

class LabeledRow extends StatelessWidget {
  final String label;
  final Widget trailing;
  const LabeledRow({super.key, required this.label, required this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(children: [
          Expanded(child: Text(label, style: ui())),
          trailing,
        ]),
      );
}

// ======================== screens/home_screen.dart ========================
const double kOrb = 116;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _Floater {
  final int id;
  final Offset pos;
  final String text;
  const _Floater(this.id, this.pos, this.text);
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _rnd = Random();
  late final AnimationController _move = AnimationController(vsync: this);
  late final AnimationController _breathe =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420), value: 1);
  late final AnimationController _ring =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 650), value: 1);

  Size _area = Size.zero;
  Offset _from = Offset.zero;
  Offset _to = Offset.zero;
  bool _paused = false;
  int _phraseIdx = 0;
  int _fid = 0;
  final List<_Floater> _floaters = [];
  AppBadge? _toast;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _move.value = 1;
    _move.addStatusListener((s) {
      if (s == AnimationStatus.completed && !_paused) _nextTarget();
    });
  }

  @override
  void dispose() {
    _move.dispose();
    _breathe.dispose();
    _pulse.dispose();
    _ring.dispose();
    _toastTimer?.cancel();
    super.dispose();
  }

  Offset get _pos => Offset.lerp(_from, _to, Curves.easeInOutSine.transform(_move.value))!;
  Offset get _center => Offset((_area.width - kOrb) / 2, (_area.height - kOrb) / 2);

  (int, int) _durationRange(Speed s) => switch (s) {
        Speed.calm => (3200, 4200),
        Speed.medium => (1900, 2600),
        Speed.fast => (1100, 1500),
      };

  void _nextTarget() {
    if (!mounted || _area == Size.zero) return;
    const pad = 12.0;
    final speed = AppScope.read(context).data.settings.speed;
    final (a, b) = _durationRange(speed);
    _from = _pos;
    _to = Offset(
      pad + _rnd.nextDouble() * max(1.0, _area.width - kOrb - pad * 2),
      pad + _rnd.nextDouble() * max(1.0, _area.height - kOrb - pad * 2),
    );
    _move.duration = Duration(milliseconds: a + _rnd.nextInt(b - a));
    _move.forward(from: 0);
  }

  void _onArea(Size size) {
    if (size == _area) return;
    final first = _area == Size.zero;
    _area = size;
    if (first) {
      _from = _to = _center;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_paused) _nextTarget();
      });
    }
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    if (_paused) {
      _from = _pos;
      _to = _center;
      _move.duration = const Duration(milliseconds: 600);
      _move.forward(from: 0);
    } else {
      _nextTarget();
    }
  }

  void _onTap(Dhikr dhikr) {
    final state = AppScope.read(context);
    final s = state.data.settings;
    final phrase = dhikr.phrases[_phraseIdx % dhikr.phrases.length];
    final res = state.addDhikr(dhikr.id);

    if (res.goalReached) {
      TapFeedback.instance.goal(sound: s.sound, haptics: s.haptics);
    } else {
      TapFeedback.instance.tap(sound: s.sound, haptics: s.haptics);
    }
    _pulse.forward(from: 0);
    _ring.forward(from: 0);

    setState(() {
      if (dhikr.phrases.length > 1) _phraseIdx++;
      if (_floaters.length > 6) _floaters.removeAt(0);
      _floaters.add(_Floater(_fid++, _pos, phrase));
    });

    if (res.newBadges.isNotEmpty) _showToast(res.newBadges.last);
    if (res.goalReached) Future.delayed(const Duration(milliseconds: 350), _celebrate);
  }

  void _showToast(AppBadge b) {
    _toastTimer?.cancel();
    setState(() => _toast = b);
    _toastTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  void _celebrate() {
    if (!mounted) return;
    final st = AppScope.read(context);
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: const BorderSide(color: AppColors.gold)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🌟', style: TextStyle(fontSize: 54)),
            const SizedBox(height: 4),
            Text('بارك الله فيك', style: quran(size: 26, color: AppColors.gold)),
            const SizedBox(height: 6),
            Text(
              'أتممت هدفك اليومي (${formatNum(st.data.settings.dailyGoal)} ذكر).\nأيامك المتتالية: ${daysLabel(st.streak)}.',
              textAlign: TextAlign.center,
              style: ui(size: 15, height: 1.6),
            ),
            const SizedBox(height: 12),
            Text(
              '﴿وَالذَّاكِرِينَ اللَّهَ كَثِيرًا وَالذَّاكِرَاتِ أَعَدَّ اللَّهُ لَهُم مَّغْفِرَةً وَأَجْرًا عَظِيمًا﴾',
              textAlign: TextAlign.center,
              style: quran(size: 15, weight: FontWeight.w400, color: AppColors.textDim, height: 1.7),
            ),
            const SizedBox(height: 18),
            AppButton(label: 'متابعة الذكر', onTap: () => Navigator.of(ctx).pop()),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = state.data.settings;
    final dhikr = dhikrById(s.dhikrId);
    final goal = s.dailyGoal;
    final progress = state.todayTotal / goal;
    final phrase = dhikr.phrases[_phraseIdx % dhikr.phrases.length];

    return Stack(children: [
      Column(children: [
        // الترويسة
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('ذِكْر', style: quran(size: 30, color: AppColors.gold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(99)),
                child: Text('🔥 ${daysLabel(state.streak)}', style: ui(size: 14, weight: FontWeight.w700, color: AppColors.gold)),
              ),
            ]),
            Text('﴿أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ﴾', style: quran(size: 15, weight: FontWeight.w400, color: AppColors.textDim)),
          ]),
        ),

        // اختيار الذكر
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: adhkar.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final d = adhkar[i];
              return AppChip(
                label: '${d.icon} ${d.name}',
                active: d.id == dhikr.id,
                onTap: () {
                  TapFeedback.instance.select(haptics: s.haptics);
                  setState(() => _phraseIdx = 0);
                  state.updateSettings(s.copyWith(dhikrId: d.id));
                },
              );
            },
          ),
        ),

        // العدّاد
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(phrase,
              textAlign: TextAlign.center, maxLines: 2, style: quran(size: dhikr.id == 'mixed' ? 22 : 28)),
        ),
        Text(formatNum(state.todayFor(dhikr.id)), style: ui(size: 56, weight: FontWeight.w800, color: AppColors.emerald, height: 1.15)),
        Text('${dhikr.name} اليوم', style: ui(size: 13, color: AppColors.textDim)),

        // مساحة اللعب
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.cardBorder),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF082820), AppColors.bgSoft],
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: LayoutBuilder(builder: (context, c) {
                _onArea(Size(c.maxWidth, c.maxHeight));
                return Stack(clipBehavior: Clip.none, children: [
                  for (final f in _floaters)
                    _FloatingText(
                      key: ValueKey(f.id),
                      floater: f,
                      onDone: () => setState(() => _floaters.removeWhere((x) => x.id == f.id)),
                    ),
                  AnimatedBuilder(
                    animation: Listenable.merge([_move, _breathe, _pulse, _ring]),
                    builder: (context, _) {
                      final p = _pos;
                      final b = Curves.easeInOutSine.transform(_breathe.value);
                      final scale = 0.86 + 0.14 * Curves.elasticOut.transform(_pulse.value);
                      return Positioned(
                        left: p.dx,
                        top: p.dy,
                        width: kOrb,
                        height: kOrb,
                        child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                          // توهّج يتنفّس
                          OverflowBox(
                            maxWidth: kOrb + 80,
                            maxHeight: kOrb + 80,
                            child: Transform.scale(
                              scale: 1.0 + 0.18 * b,
                              child: Container(
                                width: kOrb + 44,
                                height: kOrb + 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.emerald.withValues(alpha: 0.12 + 0.13 * b),
                                ),
                              ),
                            ),
                          ),
                          // حلقة ذهبية عند الضغط
                          Opacity(
                            opacity: (0.8 * (1 - _ring.value)).clamp(0.0, 1.0),
                            child: Transform.scale(
                              scale: 1 + 0.9 * _ring.value,
                              child: Container(
                                width: kOrb,
                                height: kOrb,
                                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.gold, width: 2)),
                              ),
                            ),
                          ),
                          Semantics(
                            button: true,
                            label: 'اضغط للذكر: $phrase',
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapDown: (_) => _onTap(dhikr),
                              child: Transform.scale(scale: scale, child: const _Orb()),
                            ),
                          ),
                        ]),
                      );
                    },
                  ),
                  PositionedDirectional(
                    bottom: 10,
                    end: 12,
                    child: GestureDetector(
                      onTap: _togglePause,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(99)),
                        child: Text(_paused ? '▶ حركة' : '❚❚ ثبات', style: ui(size: 12, weight: FontWeight.w700, color: AppColors.textDim)),
                      ),
                    ),
                  ),
                ]);
              }),
            ),
          ),
        ),

        // الهدف اليومي
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('هدفك اليومي ${formatNum(goal)}', style: ui(size: 14, weight: FontWeight.w700)),
                const Spacer(),
                Text('${min(100, (progress * 100).round())}%', style: ui(size: 14, weight: FontWeight.w700, color: AppColors.emerald)),
              ]),
              const SizedBox(height: 8),
              ProgressLine(value: progress),
              const SizedBox(height: 6),
              Text(
                '${formatNum(state.todayTotal)} من ${formatNum(goal)}${progress >= 1 ? ' — ما شاء الله، أتممت وِردك 🤍' : ''}',
                style: ui(size: 12, color: AppColors.textDim),
              ),
            ]),
          ),
        ),
      ]),

      // إشعار الشارة الجديدة
      PositionedDirectional(
        top: 70,
        start: 16,
        end: 16,
        child: IgnorePointer(
          child: AnimatedSlide(
            offset: _toast == null ? const Offset(0, -0.4) : Offset.zero,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            child: AnimatedOpacity(
              opacity: _toast == null ? 0 : 1,
              duration: const Duration(milliseconds: 250),
              child: _toast == null
                  ? const SizedBox.shrink()
                  : AppCard(
                      color: const Color(0xFF0F3A2C),
                      borderColor: AppColors.gold,
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        Text(_toast!.icon, style: const TextStyle(fontSize: 26)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('شارة جديدة: ${_toast!.title}', style: ui(weight: FontWeight.w700, color: AppColors.gold)),
                            Text(_toast!.desc, style: ui(size: 12, color: AppColors.textDim)),
                          ]),
                        ),
                      ]),
                    ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _Orb extends StatelessWidget {
  const _Orb();
  @override
  Widget build(BuildContext context) => Container(
        width: kOrb,
        height: kOrb,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment(-0.4, -1),
            end: Alignment(0.4, 1),
            colors: [AppColors.emeraldLight, Color(0xFF0E9F6E), AppColors.emeraldDark],
          ),
          boxShadow: [BoxShadow(color: Color(0x6610B981), blurRadius: 24, spreadRadius: 2)],
        ),
        child: Container(
          width: kOrb - 18,
          height: kOrb - 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5)),
          child: Text('اضغط\nللذكر', textAlign: TextAlign.center, style: ui(size: 14, weight: FontWeight.w700, color: const Color(0xFFEFFFF8), height: 1.3)),
        ),
      );
}

class _FloatingText extends StatefulWidget {
  final _Floater floater;
  final VoidCallback onDone;
  const _FloatingText({super.key, required this.floater, required this.onDone});
  @override
  State<_FloatingText> createState() => _FloatingTextState();
}

class _FloatingTextState extends State<_FloatingText> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward().whenComplete(() {
          if (mounted) widget.onDone();
        });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.floater;
    return Positioned(
      left: f.pos.dx - 60,
      top: f.pos.dy,
      width: kOrb + 120,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, child) {
            final t = Curves.easeOutCubic.transform(_c.value);
            final o = _c.value < 0.15 ? _c.value / 0.15 : 1 - (_c.value - 0.15) / 0.85;
            return Opacity(opacity: o.clamp(0.0, 1.0), child: Transform.translate(offset: Offset(0, -90 * t), child: child));
          },
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(f.text, textAlign: TextAlign.center, style: quran(size: 18, color: AppColors.gold)),
            Text('+1', style: ui(size: 14, weight: FontWeight.w700, color: AppColors.emerald)),
          ]),
        ),
      ),
    );
  }
}

// ======================== screens/stats_screen.dart ========================
const _weekdays = ['إثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت', 'أحد']; // DateTime.weekday: 1 = الإثنين

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int _range = 7;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final data = state.data;
    final goal = data.settings.dailyGoal;
    final days = List.generate(_range, (i) {
      final d = addDays(DateTime.now(), -(_range - 1 - i));
      return (date: d, total: data.dayTotal(dateKey(d)));
    });
    final maxV = max(goal, days.fold<int>(1, (a, d) => max(a, d.total))).toDouble();
    final rangeTotal = days.fold<int>(0, (a, d) => a + d.total);
    final completed = days.where((d) => d.total >= goal).length;
    final lvl = levelInfo(data.lifetime);
    final topTotal = adhkar.fold<int>(1, (a, d) => max(a, data.totals[d.id] ?? 0));

    return ListView(padding: const EdgeInsets.all(16), children: [
      const PageTitle('إحصائياتك'),
      const SizedBox(height: 14),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.9,
        children: [
          _Stat('اليوم', formatNum(state.todayTotal)),
          _Stat('السلسلة', '${formatNum(state.streak)} 🔥'),
          _Stat('أفضل سلسلة', formatNum(max(data.bestStreak, state.streak))),
          _Stat('المجموع الكلي', formatNum(data.lifetime)),
        ],
      ),
      const SizedBox(height: 14),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('المستوى ${lvl.index}: ${lvl.name}', style: ui(weight: FontWeight.w700, color: AppColors.gold)),
          const SizedBox(height: 10),
          ProgressLine(value: lvl.progress, color: AppColors.gold),
          const SizedBox(height: 6),
          Text(
            lvl.next != null
                ? 'بقي ${formatNum(lvl.next!.min - data.lifetime)} ذكراً للوصول إلى «${lvl.next!.name}»'
                : 'بلغت أعلى مستوى، تقبّل الله منك',
            style: ui(size: 12, color: AppColors.textDim),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(_range == 7 ? 'آخر 7 أيام' : 'آخر 30 يوماً', style: ui(weight: FontWeight.w700))),
            AppChip(label: 'أسبوع', active: _range == 7, onTap: () => setState(() => _range = 7)),
            const SizedBox(width: 6),
            AppChip(label: 'شهر', active: _range == 30, onTap: () => setState(() => _range = 30)),
          ]),
          const SizedBox(height: 14),
          SizedBox(
            height: 160,
            child: LayoutBuilder(builder: (context, c) {
              final goalY = c.maxHeight * (goal / maxV);
              return Stack(children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: goalY,
                  child: Container(height: 1, color: AppColors.gold.withValues(alpha: 0.5)),
                ),
                Positioned.fill(
                  child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final d in days)
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: _range == 7 ? 22 : 6,
                            height: d.total == 0 ? 0.0 : max(4.0, c.maxHeight * d.total / maxV),
                            decoration: BoxDecoration(
                              color: d.total >= goal ? AppColors.emerald : AppColors.emeraldDeep,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                  ],
                  ),
                ),
              ]);
            }),
          ),
          if (_range == 7) ...[
            const SizedBox(height: 6),
            Row(children: [
              for (final d in days)
                Expanded(
                  child: Text(_weekdays[d.date.weekday - 1],
                      textAlign: TextAlign.center, style: ui(size: 10, color: AppColors.textDim)),
                ),
            ]),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Text('المجموع: ${formatNum(rangeTotal)}', style: ui(size: 13, color: AppColors.textDim))),
            Text('أيام مكتملة: $completed / $_range', style: ui(size: 13, color: AppColors.textDim)),
          ]),
        ]),
      ),
      const SizedBox(height: 14),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle('حسب نوع الذكر'),
          for (final d in adhkar) ...[
            Row(children: [
              Expanded(child: Text('${d.icon} ${d.name}', style: ui())),
              Text(formatNum(data.totals[d.id] ?? 0), style: ui(weight: FontWeight.w700, color: AppColors.emerald)),
            ]),
            const SizedBox(height: 6),
            ProgressLine(value: (data.totals[d.id] ?? 0) / topTotal, height: 6),
            const SizedBox(height: 12),
          ],
        ]),
      ),
      const SizedBox(height: 16),
    ]);
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat(this.label, this.value);
  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label, style: ui(size: 12, color: AppColors.textDim)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(value, style: ui(size: 24, weight: FontWeight.w800)),
          ),
        ]),
      );
}

// ======================== screens/achievements_screen.dart ========================
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});
  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  bool _creating = false;
  String _dhikrId = 'istighfar';
  int _target = 1000;
  int _days = 7;

  Future<void> _confirmDelete(AppState state, Challenge c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('حذف التحدي', style: ui(weight: FontWeight.w700)),
        content: Text('هل تريد حذف هذا التحدي؟', style: ui()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('إلغاء', style: ui())),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('حذف', style: ui(color: AppColors.danger))),
        ],
      ),
    );
    if (ok == true) state.removeChallenge(c.id);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final data = state.data;
    final unlocked = badges.where((b) => data.badges.containsKey(b.id)).length;

    return ListView(padding: const EdgeInsets.all(16), children: [
      const PageTitle('الإنجازات'),
      const SizedBox(height: 14),

      // التحديات الشخصية
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: SectionTitle('تحدياتي')),
            if (!_creating) AppChip(label: '+ تحدٍّ جديد', onTap: () => setState(() => _creating = true)),
          ]),
          if (_creating)
            Container(
              margin: const EdgeInsets.only(bottom: 10, top: 6),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.bgSoft, borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('نوع الذكر', style: ui(weight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final d in adhkar)
                    AppChip(label: '${d.icon} ${d.name}', active: _dhikrId == d.id, onTap: () => setState(() => _dhikrId = d.id)),
                ]),
                LabeledRow(
                  label: 'العدد المستهدف',
                  trailing: Stepper2(
                    value: _target,
                    min: 100,
                    max: 100000,
                    step: _target >= 10000 ? 1000 : 100,
                    format: formatNum,
                    onChanged: (v) => setState(() => _target = v),
                  ),
                ),
                LabeledRow(
                  label: 'خلال (أيام)',
                  trailing: Stepper2(value: _days, min: 1, max: 90, onChanged: (v) => setState(() => _days = v)),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: AppButton(
                      label: 'ابدأ التحدي',
                      onTap: () {
                        state.addChallenge(_dhikrId, _target, _days);
                        setState(() => _creating = false);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: AppButton(label: 'إلغاء', kind: BtnKind.ghost, onTap: () => setState(() => _creating = false))),
                ]),
              ]),
            ),
          if (data.challenges.isEmpty && !_creating)
            Text('ضع لنفسك تحدياً، مثل: 10,000 استغفار خلال شهر، وتابع تقدّمك يوماً بيوم.',
                style: ui(size: 13, color: AppColors.textDim, height: 1.5)),
          for (final c in data.challenges.reversed) _ChallengeTile(c: c, data: data, onDelete: () => _confirmDelete(state, c)),
        ]),
      ),
      const SizedBox(height: 14),

      // الشارات
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionTitle('الشارات ($unlocked / ${badges.length})'),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.78,
            children: [
              for (final b in badges) _BadgeTile(b: b, got: data.badges.containsKey(b.id)),
            ],
          ),
        ]),
      ),
      const SizedBox(height: 16),
    ]);
  }
}

class _ChallengeTile extends StatelessWidget {
  final Challenge c;
  final AppData data;
  final VoidCallback onDelete;
  const _ChallengeTile({required this.c, required this.data, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final p = challengeProgress(data, c);
    final d = dhikrById(c.dhikrId);
    final status = p.done
        ? '✓ أنجزت التحدي (${formatNum(p.sum)})، تقبّل الله'
        : p.expired
            ? 'انتهت المدة: ${formatNum(p.sum)} من ${formatNum(c.target)}'
            : '${formatNum(p.sum)} من ${formatNum(c.target)} • بقي ${daysLabel(p.daysLeft)}';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.cardBorder))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${d.icon} ${formatNum(c.target)} ${d.name}', style: ui(weight: FontWeight.w700))),
          GestureDetector(onTap: onDelete, child: Text('حذف', style: ui(size: 12, color: AppColors.textFaint))),
        ]),
        const SizedBox(height: 8),
        ProgressLine(value: p.sum / c.target, color: p.done ? AppColors.gold : AppColors.emerald),
        const SizedBox(height: 8),
        Text(status, style: ui(size: 12, color: p.done ? AppColors.gold : AppColors.textDim)),
      ]),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final AppBadge b;
  final bool got;
  const _BadgeTile({required this.b, required this.got});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: got ? AppColors.gold.withValues(alpha: 0.07) : AppColors.bgSoft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: got ? AppColors.gold : AppColors.cardBorder),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Opacity(opacity: got ? 1 : 0.3, child: Text(got ? b.icon : '🔒', style: const TextStyle(fontSize: 28))),
          const SizedBox(height: 6),
          Text(b.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: ui(size: 13, weight: FontWeight.w700, color: got ? AppColors.gold : AppColors.textDim)),
          const SizedBox(height: 2),
          Text(b.desc, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: ui(size: 10.5, color: AppColors.textFaint)),
        ]),
      );
}

// ======================== screens/settings_screen.dart ========================
const _goals = [100, 300, 500, 1000];
const _hours = [9, 11, 13, 15, 17, 20, 22];

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _setReminders(BuildContext context, AppState state, Settings next) async {
    final anyOn = next.morning.on || next.evening.on || next.wird.on || next.istighfarOn;
    if (anyOn) {
      final ok = await NotificationService.instance.ensurePermission(ask: true);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.card,
          content: Text('فعّل إذن الإشعارات لتطبيق ذِكْر من إعدادات الجهاز لتصلك التذكيرات.', style: ui()),
        ));
      }
    }
    state.updateSettings(next, reschedule: true);
  }

  Future<void> _confirmReset(BuildContext context, AppState state) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تصفير البيانات', style: ui(weight: FontWeight.w700)),
        content: Text('سيتم حذف جميع العدادات والإحصائيات والشارات والتحديات. لا يمكن التراجع.', style: ui(height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('إلغاء', style: ui())),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('تصفير', style: ui(color: AppColors.danger))),
        ],
      ),
    );
    if (ok == true) state.resetAll();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = state.data.settings;

    return ListView(padding: const EdgeInsets.all(16), children: [
      const PageTitle('الإعدادات'),
      const SizedBox(height: 14),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle('الهدف اليومي'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final g in _goals)
              AppChip(
                label: formatNum(g),
                active: s.dailyGoal == g,
                onTap: () => state.updateSettings(s.copyWith(dailyGoal: g), reschedule: true),
              ),
          ]),
          LabeledRow(
            label: 'هدف مخصص',
            trailing: Stepper2(
              value: s.dailyGoal,
              min: 33,
              max: 100000,
              step: s.dailyGoal >= 1000 ? 100 : 33,
              format: formatNum,
              onChanged: (v) => state.updateSettings(s.copyWith(dailyGoal: v), reschedule: true),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle('تجربة الذكر'),
          LabeledRow(
            label: 'صوت هادئ عند الضغط',
            trailing: Switch(value: s.sound, onChanged: (v) => state.updateSettings(s.copyWith(sound: v))),
          ),
          LabeledRow(
            label: 'الاهتزاز',
            trailing: Switch(value: s.haptics, onChanged: (v) => state.updateSettings(s.copyWith(haptics: v))),
          ),
          const SizedBox(height: 14),
          Text('سرعة حركة الدائرة', style: ui(weight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(children: [
            for (final (sp, label) in [(Speed.calm, 'هادئة'), (Speed.medium, 'متوسطة'), (Speed.fast, 'سريعة')]) ...[
              Expanded(child: AppChip(label: label, active: s.speed == sp, onTap: () => state.updateSettings(s.copyWith(speed: sp)))),
              if (sp != Speed.fast) const SizedBox(width: 8),
            ],
          ]),
        ]),
      ),
      const SizedBox(height: 14),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle('التنبيهات'),
          _ReminderTile(
            label: '☀️ تذكير أذكار الصباح',
            r: s.morning,
            onChanged: (r) => _setReminders(context, state, s.copyWith(morning: r)),
          ),
          _ReminderTile(
            label: '🌙 تذكير أذكار المساء',
            r: s.evening,
            onChanged: (r) => _setReminders(context, state, s.copyWith(evening: r)),
          ),
          _ReminderTile(
            label: '📿 تذكير إن لم يكتمل الورد',
            r: s.wird,
            onChanged: (r) => _setReminders(context, state, s.copyWith(wird: r)),
          ),
          const Divider(color: AppColors.cardBorder, height: 28),
          LabeledRow(
            label: '🌿 تنبيهات الاستغفار خلال اليوم',
            trailing: Switch(value: s.istighfarOn, onChanged: (v) => _setReminders(context, state, s.copyWith(istighfarOn: v))),
          ),
          if (s.istighfarOn) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final h in _hours)
                AppChip(
                  label: formatTime(TimeOfDayHM(h, 0)),
                  active: s.istighfarHours.contains(h),
                  onTap: () {
                    final hours = [...s.istighfarHours];
                    if (hours.contains(h)) {
                      hours.remove(h);
                    } else {
                      hours.add(h);
                    }
                    hours.sort();
                    _setReminders(context, state, s.copyWith(istighfarHours: hours));
                  },
                ),
            ]),
          ],
        ]),
      ),
      const SizedBox(height: 14),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle('البيانات'),
          Text('تُحفظ أذكارك وإحصائياتك على جهازك فقط، ولا تُرسل إلى أي خادم.',
              style: ui(size: 13, color: AppColors.textDim, height: 1.5)),
          const SizedBox(height: 12),
          AppButton(label: 'تصفير العدادات والإحصائيات', kind: BtnKind.danger, onTap: () => _confirmReset(context, state)),
        ]),
      ),
      const SizedBox(height: 14),
      Text('ذِكْر • الإصدار 1.0.0', textAlign: TextAlign.center, style: ui(size: 12, color: AppColors.textFaint)),
      const SizedBox(height: 24),
    ]);
  }
}

class _ReminderTile extends StatelessWidget {
  final String label;
  final Reminder r;
  final ValueChanged<Reminder> onChanged;
  const _ReminderTile({required this.label, required this.r, required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(children: [
        LabeledRow(label: label, trailing: Switch(value: r.on, onChanged: (v) => onChanged(r.copyWith(on: v)))),
        if (r.on)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Row(children: [
              Expanded(child: Text('الوقت', style: ui(size: 13, color: AppColors.textDim))),
              Stepper2(
                value: r.time.totalMinutes,
                min: 0,
                max: 23 * 60 + 45,
                step: 15,
                format: (v) => formatTime(TimeOfDayHM.fromMinutes(v)),
                onChanged: (v) => onChanged(r.copyWith(time: TimeOfDayHM.fromMinutes(v))),
              ),
            ]),
          ),
      ]);
}

// ======================== screens/onboarding_screen.dart ========================
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _goal = 500;

  Future<void> _start() async {
    final state = AppScope.read(context);
    state.updateSettings(state.data.settings.copyWith(dailyGoal: _goal));
    await NotificationService.instance.ensurePermission(ask: true);
    state.finishOnboarding();
  }

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(children: [
            Text('ذِكْر', style: quran(size: 64, color: AppColors.gold)),
            Text('﴿فَاذْكُرُونِي أَذْكُرْكُمْ﴾', style: quran(size: 18, weight: FontWeight.w400, color: AppColors.textDim)),
            const SizedBox(height: 28),
            Text(
              'اضغط على الدائرة المضيئة كلما ظهرت لتسبّح وتستغفر، واجمع أيامك المتتالية وشاراتك بهدوء.',
              textAlign: TextAlign.center,
              style: ui(size: 16, height: 1.7),
            ),
            const SizedBox(height: 32),
            Text('اختر هدفك اليومي', style: ui(size: 16, weight: FontWeight.w700, color: AppColors.gold)),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (final g in [100, 500, 1000]) ...[
                AppChip(label: '  ${formatNum(g)}  ', active: _goal == g, onTap: () => setState(() => _goal = g)),
                if (g != 1000) const SizedBox(width: 10),
              ],
            ]),
            const SizedBox(height: 10),
            Text('يمكنك تغييره لاحقاً من الإعدادات', style: ui(size: 12, color: AppColors.textFaint)),
            const SizedBox(height: 36),
            AppButton(label: 'ابدأ الذكر', onTap: _start),
          ]),
        ),
      );
}

// ======================== main.dart ========================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.bgSoft,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  final state = AppState();
  await Future.wait([
    state.load(),
    TapFeedback.instance.init().catchError((_) {}),
    NotificationService.instance.init().catchError((_) {}),
  ]);
  runApp(DhikrApp(state: state));
}

class DhikrApp extends StatelessWidget {
  final AppState state;
  const DhikrApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) => AppScope(
        state: state,
        child: MaterialApp(
          title: 'ذِكْر',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const RootScreen(),
        ),
      );
}

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});
  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _tab = 0;

  static const _tabs = [
    ('📿', 'الذكر'),
    ('📊', 'الإحصائيات'),
    ('🏅', 'الإنجازات'),
    ('⚙️', 'الإعدادات'),
  ];

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (!state.data.onboarded) {
      return const Scaffold(body: SafeArea(child: OnboardingScreen()));
    }
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _tab, children: const [
          HomeScreen(),
          StatsScreen(),
          AchievementsScreen(),
          SettingsScreen(),
        ]),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.bgSoft,
          border: Border(top: BorderSide(color: AppColors.cardBorder)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 6),
            child: Row(children: [
              for (var i = 0; i < _tabs.length; i++)
                Expanded(
                  child: Semantics(
                    selected: _tab == i,
                    button: true,
                    label: _tabs[i].$2,
                    child: InkWell(
                      onTap: () => setState(() => _tab = i),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Opacity(opacity: _tab == i ? 1 : 0.5, child: Text(_tabs[i].$1, style: const TextStyle(fontSize: 20))),
                        const SizedBox(height: 2),
                        Text(
                          _tabs[i].$2,
                          style: ui(
                            size: 11,
                            weight: _tab == i ? FontWeight.w700 : FontWeight.w500,
                            color: _tab == i ? AppColors.emerald : AppColors.textFaint,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _tab == i ? AppColors.emerald : Colors.transparent,
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
