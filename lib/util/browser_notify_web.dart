// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

Future<void> requestAndShowBrowserNotification(
  String title,
  String body,
) async {
  if (!html.Notification.supported) {
    return;
  }
  final perm = await html.Notification.requestPermission();
  if (perm != 'granted') {
    return;
  }
  html.Notification(title, body: body);
}
