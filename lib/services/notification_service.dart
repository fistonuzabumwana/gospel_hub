import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'app_state_service.dart';
import 'daily_verse_service.dart';
import 'database_service.dart';
import 'app_localizations.dart';
import '../models/bible_book.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();
    // Assuming local timezone is standard, but you can configure it specifically if needed.
    // tz.setLocalLocation(tz.getLocation('Africa/Kigali')); // Default to local machine time.

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // For iOS if you ever port it
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Handle notification tapped logic here if needed
      },
    );

    _isInitialized = true;
    await scheduleNext30Days();
  }

  /// Cancels all existing scheduled notifications and schedules the next 30 days
  /// of daily verses if notifications are enabled in settings.
  Future<void> scheduleNext30Days() async {
    await flutterLocalNotificationsPlugin.cancelAll();

    final isEnabled = await AppStateService.isDailyNotificationEnabled();
    if (!isEnabled) return;

    final hour = await AppStateService.getDailyNotificationHour();
    final minute = await AppStateService.getDailyNotificationMinute();
    final dbService = DatabaseService();
    final bibleLanguage = await AppStateService.getBibleLanguage();

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'daily_verse_channel',
      'Daily Verse',
      channelDescription: 'Daily inspirational Bible verses',
      importance: Importance.max,
      priority: Priority.high,
      visibility: NotificationVisibility.public, // Shows on lock screen
      styleInformation: BigTextStyleInformation(''), // Expandable text
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    final now = DateTime.now();

    for (int i = 0; i < 30; i++) {
      final targetDate = now.add(Duration(days: i));
      
      // Calculate the specific time for this day's notification
      var scheduledDate = tz.TZDateTime.local(
        targetDate.year,
        targetDate.month,
        targetDate.day,
        hour,
        minute,
      );

      // If the scheduled time for today has already passed, skip today.
      if (i == 0 && scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
        continue;
      }

      // Fetch the verse for this specific date
      final verseRef = DailyVerseService.todayVerseRef(targetDate);
      
      // Load verse text from database
      final isEnglish = bibleLanguage.contains('EN') || bibleLanguage == 'KJV' || bibleLanguage == 'GNB' || bibleLanguage == 'CE' || bibleLanguage == 'GNC';
      final text = await dbService.getSingleVerseText(
        verseRef.bookNumber,
        verseRef.chapter,
        verseRef.verse,
        isEnglish,
      );

      if (text != null && text.isNotEmpty) {
        final book = BibleBook.allBooks.firstWhere(
          (b) => b.bookNumber == verseRef.bookNumber,
          orElse: () => BibleBook.allBooks.first,
        );
        final bookName = book.getDisplayName(isEnglish ? 'english' : 'kinyarwanda');

        // Wait for locale to be ready or just use the current translation
        final title = AppLocalizations.translate('dash_verse_of_day');
        final body = '"$text"\n— $bookName ${verseRef.chapter}:${verseRef.verse}';

        await flutterLocalNotificationsPlugin.zonedSchedule(
          id: i,
          title: title,
          body: body,
          scheduledDate: scheduledDate,
          notificationDetails: platformChannelSpecifics,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      }
    }
  }

  Future<void> requestPermissions() async {
    final androidImplementation = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.requestNotificationsPermission();
    await androidImplementation?.requestExactAlarmsPermission();
  }
}
