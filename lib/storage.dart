import 'package:shared_preferences/shared_preferences.dart';

const notificationOnAppKillTitle = 'notificationOnAppKillTitle';
const notificationOnAppKillBody = 'notificationOnAppKillBody';

class Storage {
  static late SharedPreferences prefs;

  static Future<void> init() async {
    // refer this issue: https://stackoverflow.com/questions/74093954/how-to-fix-no-implementation-found-for-method-getall-on-channel-plugins-flutter
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  }

  static Future<void> setNotificationContentOnAppKill(
    String title,
    String body,
  ) async {
    await prefs.setString(notificationOnAppKillTitle, title);
    await prefs.setString(notificationOnAppKillBody, body);
  }

  static String getNotificationOnAppKillTitle() =>
      prefs.getString(notificationOnAppKillTitle) ?? 'Your alarm may not ring';

  static String getNotificationOnAppKillBody() =>
      prefs.getString(notificationOnAppKillBody) ??
      'You killed the app. Please reopen and re-set alarm.';
}
