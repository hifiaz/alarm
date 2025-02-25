// ignore_for_file: avoid_print

import 'dart:isolate';
import 'dart:ui';

import 'package:alarm/notification.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:just_audio/just_audio.dart';

/// For Android support, AndroidAlarmManager is used to set an alarm
/// and trigger a callback when the given time is reached.
class AndroidAlarm {
  static const int alarmId = 888;
  static String ringPort = 'alarm-ring';
  static String stopPort = 'alarm-stop';

  /// Initializes AndroidAlarmManager dependency
  static Future<void> init() => AndroidAlarmManager.initialize();

  /// Create isolate receive port and set alarm at given time
  static Future<bool> set(
    DateTime alarmDateTime,
    void Function()? onRing,
    String assetAudioPath,
    bool loopAudio,
    String? notifTitle,
    String? notifBody,
  ) async {
    try {
      final ReceivePort port = ReceivePort();
      final success =
          IsolateNameServer.registerPortWithName(port.sendPort, ringPort);

      if (!success) {
        IsolateNameServer.removePortNameMapping(ringPort);
        IsolateNameServer.registerPortWithName(port.sendPort, ringPort);
      }
      port.listen((message) {
        print("[Alarm] (main) received: $message");
        if (message == 'ring') onRing?.call();
      });
    } catch (e) {
      print("[Alarm] (main) ReceivePort error: $e");
      return false;
    }

    final res = await AndroidAlarmManager.oneShotAt(
      alarmDateTime,
      alarmId,
      AndroidAlarm.playAlarm,
      alarmClock: true,
      allowWhileIdle: true,
      exact: true,
      rescheduleOnReboot: true,
      params: {
        "assetAudioPath": assetAudioPath,
        "loopAudio": loopAudio,
        "notifTitle": notifTitle,
        "notifBody": notifBody,
      },
    );
    return res;
  }

  /// Callback triggered when alarmDateTime is reached.
  /// The message 'ring' is sent to the main thread in order to
  /// tell the device that the alarm is starting to ring.
  /// Alarm is played with AudioPlayer and stopped when the message 'stop'
  /// is received from the main thread.
  @pragma('vm:entry-point')
  static Future<void> playAlarm(int id, Map<String, dynamic> data) async {
    final audioPlayer = AudioPlayer();
    SendPort send = IsolateNameServer.lookupPortByName(ringPort)!;

    send.send('ring');

    try {
      final assetAudioPath = data["assetAudioPath"] as String;

      if (assetAudioPath.startsWith('http')) {
        send.send('[Alarm] Setting audio source url: $assetAudioPath');
        await audioPlayer.setUrl(assetAudioPath);
      } else {
        send.send('[Alarm] Setting audio source local asset: $assetAudioPath');
        await audioPlayer.setAsset(assetAudioPath);
      }

      final loopAudio = data["loopAudio"];
      if (loopAudio) audioPlayer.setLoopMode(LoopMode.all);

      audioPlayer.play();
      send.send('[Alarm] Alarm playing');
    } catch (e) {
      send.send('[Alarm] AudioPlayer error: ${e.toString()}');
      await AudioPlayer.clearAssetCache();
      send.send('[Alarm] Asset cache reset. Please try again.');
    }

    final notifTitle = data["notifTitle"];
    final notifBody = data["notifBody"];
    if (notifTitle != null && notifBody != null) {
      await Notification.instance
          .androidAlarmNotif(title: notifTitle, body: notifBody);
    }

    try {
      final ReceivePort port = ReceivePort();
      final success =
          IsolateNameServer.registerPortWithName(port.sendPort, stopPort);

      if (!success) {
        IsolateNameServer.removePortNameMapping(stopPort);
        IsolateNameServer.registerPortWithName(port.sendPort, stopPort);
      }

      port.listen(
        (message) async {
          send.send("[Alarm] (isolate) received: $message");
          if (message == 'stop') {
            await audioPlayer.stop();
            await audioPlayer.dispose();
            port.close();
          }
        },
      );
    } catch (e) {
      send.send("[Alarm] (isolate) ReceivePort error: $e");
    }
  }

  /// This function will send the message 'stop' to the isolate so
  /// the audio player can stop playing and dispose.
  static Future<bool> stop() async {
    try {
      final SendPort send = IsolateNameServer.lookupPortByName(stopPort)!;
      print("[Alarm] (main) send stop to isolate");
      send.send('stop');
    } catch (e) {
      print("[Alarm] (main) SendPort error: $e");
    }

    final res = await AndroidAlarmManager.cancel(alarmId);

    return res;
  }
}
